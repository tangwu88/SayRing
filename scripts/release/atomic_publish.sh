#!/usr/bin/env bash
set -euo pipefail

# Upload immutable APK/checksum files first, verify them through the public
# origin, then atomically rename the manifest as the final publication step.
# All variables are supplied by the protected GitHub production environment.
# Remote commands intentionally interpolate paths after the strict validation
# below; the remote shell must receive those resolved, quoted values.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

verify_effective_url() {
  python3 "$script_dir/release_gate.py" same-origin \
    --requested "$1" \
    --effective "$2" >/dev/null
}

required=(
  RELEASE_SSH_HOST
  RELEASE_SSH_USER
  RELEASE_SSH_PORT
  RELEASE_SSH_KEY_PATH
  RELEASE_SSH_KNOWN_HOSTS_PATH
  RELEASE_REMOTE_ROOT
  APK_FILE
  CHECKSUM_FILE
  MANIFEST_FILE
  APK_PUBLIC_URL
  MANIFEST_PUBLIC_URL
  EXPECTED_SHA256
  EXPECTED_PREVIOUS_MANIFEST_SHA256
  RELEASE_TOKEN
)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "Missing atomic-publish input: $name" >&2
    exit 2
  fi
done

[[ "$RELEASE_SSH_HOST" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] || {
  echo "Invalid RELEASE_SSH_HOST." >&2
  exit 2
}
[[ "$RELEASE_SSH_USER" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || {
  echo "Invalid RELEASE_SSH_USER." >&2
  exit 2
}
[[ "$RELEASE_SSH_PORT" =~ ^[1-9][0-9]{0,4}$ ]] || {
  echo "Invalid RELEASE_SSH_PORT." >&2
  exit 2
}
(( RELEASE_SSH_PORT <= 65535 )) || {
  echo "Invalid RELEASE_SSH_PORT." >&2
  exit 2
}
[[ "$RELEASE_REMOTE_ROOT" =~ ^/[A-Za-z0-9._/-]+$ ]] &&
  [[ "$RELEASE_REMOTE_ROOT" != *".."* ]] &&
  [[ "$RELEASE_REMOTE_ROOT" != */ ]] || {
  echo "RELEASE_REMOTE_ROOT must be an explicit safe absolute directory." >&2
  exit 2
}
[[ "$EXPECTED_SHA256" =~ ^[0-9a-f]{64}$ ]] || {
  echo "EXPECTED_SHA256 is invalid." >&2
  exit 2
}
[[ "$EXPECTED_PREVIOUS_MANIFEST_SHA256" == "absent" || \
   "$EXPECTED_PREVIOUS_MANIFEST_SHA256" =~ ^[0-9a-f]{64}$ ]] || {
  echo "EXPECTED_PREVIOUS_MANIFEST_SHA256 is invalid." >&2
  exit 2
}
[[ "$RELEASE_TOKEN" =~ ^[A-Za-z0-9._-]+$ ]] || {
  echo "RELEASE_TOKEN is invalid." >&2
  exit 2
}
[[ "$APK_PUBLIC_URL" == https://* && "$MANIFEST_PUBLIC_URL" == https://* ]] || {
  echo "Public release URLs must use HTTPS." >&2
  exit 2
}
verify_effective_url "$APK_PUBLIC_URL" "$APK_PUBLIC_URL"
verify_effective_url "$MANIFEST_PUBLIC_URL" "$MANIFEST_PUBLIC_URL"

for path in "$APK_FILE" "$CHECKSUM_FILE" "$MANIFEST_FILE" \
  "$RELEASE_SSH_KEY_PATH" "$RELEASE_SSH_KNOWN_HOSTS_PATH"; do
  [[ -s "$path" ]] || {
    echo "Required release file is missing or empty: $path" >&2
    exit 2
  }
done

local_hash="$(sha256sum "$APK_FILE" | awk '{print $1}')"
[[ "$local_hash" == "$EXPECTED_SHA256" ]] || {
  echo "Local APK digest changed before publication." >&2
  exit 2
}

apk_name="$(basename "$APK_FILE")"
checksum_name="$(basename "$CHECKSUM_FILE")"
[[ "$apk_name" =~ ^Saydian-[0-9]+\.[0-9]+\.[0-9]+\+[1-9][0-9]*-release\.apk$ ]] || {
  echo "APK file name does not match the production convention." >&2
  exit 2
}
[[ "$checksum_name" =~ ^SHA256SUMS-[0-9]+\.[0-9]+\.[0-9]+\+[1-9][0-9]*\.txt$ ]] || {
  echo "Checksum file name does not match the production convention." >&2
  exit 2
}
[[ "$(cat "$CHECKSUM_FILE")" == "$EXPECTED_SHA256  $apk_name" ]] || {
  echo "Checksum file content does not match the APK artifact." >&2
  exit 2
}

ssh_target="${RELEASE_SSH_USER}@${RELEASE_SSH_HOST}"
ssh_options=(
  -p "$RELEASE_SSH_PORT"
  -i "$RELEASE_SSH_KEY_PATH"
  -o BatchMode=yes
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=yes
  -o "UserKnownHostsFile=$RELEASE_SSH_KNOWN_HOSTS_PATH"
  -o ConnectTimeout=20
)
scp_options=(
  -P "$RELEASE_SSH_PORT"
  -i "$RELEASE_SSH_KEY_PATH"
  -o BatchMode=yes
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=yes
  -o "UserKnownHostsFile=$RELEASE_SSH_KNOWN_HOSTS_PATH"
  -o ConnectTimeout=20
)

staging_dir="$RELEASE_REMOTE_ROOT/.staging"
apk_dir="$RELEASE_REMOTE_ROOT/android"
checksum_dir="$RELEASE_REMOTE_ROOT/checksums"
remote_apk_tmp="$staging_dir/${RELEASE_TOKEN}.apk.tmp"
remote_checksum_tmp="$staging_dir/${RELEASE_TOKEN}.sha256.tmp"
remote_manifest_tmp="$staging_dir/${RELEASE_TOKEN}.manifest.tmp"
remote_manifest_previous="$staging_dir/${RELEASE_TOKEN}.manifest.previous"
remote_manifest_swap_marker="$staging_dir/${RELEASE_TOKEN}.manifest.swap-in-progress"
remote_apk="$apk_dir/$apk_name"
remote_checksum="$checksum_dir/$checksum_name"
remote_manifest="$RELEASE_REMOTE_ROOT/app-update.json"
remote_release_lock="$RELEASE_REMOTE_ROOT/.production-release.lock"
lock_acquired=0
publication_committed=0

remote_cleanup() {
  local expected_manifest_hash="$1"
  if (( lock_acquired != 1 )); then
    return
  fi
  # shellcheck disable=SC2029
  ssh "${ssh_options[@]}" "$ssh_target" \
    "set -eu; \
     if test -f '$remote_manifest_swap_marker'; then \
       if test -f '$remote_manifest_previous'; then \
         mv '$remote_manifest_previous' '$remote_manifest'; \
       else \
         rm -f '$remote_manifest'; \
       fi; \
     fi; \
     current=absent; \
     if test -f '$remote_manifest'; then current=\$(sha256sum '$remote_manifest' | awk '{print \$1}'); fi; \
     test \"\$current\" = '$expected_manifest_hash'; \
     rm -f '$remote_apk_tmp' '$remote_checksum_tmp' '$remote_manifest_tmp' \
       '$remote_manifest_swap_marker' '$remote_manifest_previous'; \
     test \"\$(cat '$remote_release_lock/token')\" = '$RELEASE_TOKEN'; \
     rm -f '$remote_release_lock/token' '$remote_release_lock/created_at'; \
     rmdir '$remote_release_lock'"
}

verify_public_previous_manifest() {
  local previous_public
  previous_public="$(mktemp "${RUNNER_TEMP:-/tmp}/saidian-previous-manifest.XXXXXX")"
  local separator='?'
  [[ "$MANIFEST_PUBLIC_URL" == *\?* ]] && separator='&'
  local verified=0
  local attempt cache_busted_url response http_code effective_url actual_hash
  for attempt in 1 2 3 4 5 6; do
    cache_busted_url="${MANIFEST_PUBLIC_URL}${separator}rollback_verify=${RELEASE_TOKEN}-${attempt}"
    response=""
    if response="$(curl --location --proto '=https' --proto-redir '=https' \
        --silent --show-error \
        --connect-timeout 20 --max-time 60 \
        -H 'Cache-Control: no-cache' \
        --output "$previous_public" --write-out $'%{http_code}\n%{url_effective}' \
        "$cache_busted_url")" && [[ "$response" == *$'\n'* ]]; then
      http_code="${response%%$'\n'*}"
      effective_url="${response#*$'\n'}"
      if ! verify_effective_url "$cache_busted_url" "$effective_url"; then
        sleep $(( attempt * 5 ))
        continue
      fi
    else
      sleep $(( attempt * 5 ))
      continue
    fi
    if [[ "$EXPECTED_PREVIOUS_MANIFEST_SHA256" == "absent" ]]; then
      if [[ "$http_code" == "404" || "$http_code" == "410" ]]; then
        verified=1
        break
      fi
    elif [[ "$http_code" == "200" && -s "$previous_public" ]]; then
      actual_hash="$(sha256sum "$previous_public" | awk '{print $1}')"
      if [[ "$actual_hash" == "$EXPECTED_PREVIOUS_MANIFEST_SHA256" ]]; then
        verified=1
        break
      fi
    fi
    sleep $(( attempt * 5 ))
  done
  rm -f "$previous_public"
  (( verified == 1 ))
}

cleanup_on_exit() {
  local status=$?
  trap - EXIT
  if (( lock_acquired == 1 )); then
    local expected="$EXPECTED_PREVIOUS_MANIFEST_SHA256"
    if (( publication_committed == 1 )); then
      expected="${expected_manifest_hash:-$EXPECTED_PREVIOUS_MANIFEST_SHA256}"
    fi
    if ! remote_cleanup "$expected"; then
      echo "Remote release recovery or lock cleanup failed; manual intervention is required." >&2
      exit 6
    fi
  fi
  exit "$status"
}
trap cleanup_on_exit EXIT

# shellcheck disable=SC2029
ssh "${ssh_options[@]}" "$ssh_target" \
  "umask 022; mkdir -p '$staging_dir' '$apk_dir' '$checksum_dir'"
# A two-hour lease recovers a runner that died without releasing its lock. The
# stale takeover checks the second mkdir result before writing ownership. If
# another publisher wins the rename/mkdir gap, this runner cannot alter the
# winner's token.
# shellcheck disable=SC2029
if ! ssh "${ssh_options[@]}" "$ssh_target" \
  "set -eu; now=\$(date +%s); \
   if mkdir '$remote_release_lock' 2>/dev/null; then :; \
   else \
     created=0; \
     if test -f '$remote_release_lock/created_at'; then created=\$(cat '$remote_release_lock/created_at'); fi; \
     case \"\$created\" in (*[!0-9]*|'') exit 74;; esac; \
     test \$((now - created)) -gt 7200 || exit 74; \
     stale='$remote_release_lock.stale.$RELEASE_TOKEN'; \
     test ! -e \"\$stale\" || exit 74; \
     mv '$remote_release_lock' \"\$stale\" || exit 74; \
     if ! mkdir '$remote_release_lock' 2>/dev/null; then \
       rm -f \"\$stale/token\" \"\$stale/created_at\"; rmdir \"\$stale\"; \
       exit 74; \
     fi; \
     trap \"rm -f '$remote_release_lock/token' '$remote_release_lock/created_at'; rmdir '$remote_release_lock'\" EXIT; \
     rm -f \"\$stale/token\" \"\$stale/created_at\"; rmdir \"\$stale\"; \
   fi; \
   trap \"rm -f '$remote_release_lock/token' '$remote_release_lock/created_at'; rmdir '$remote_release_lock'\" EXIT; \
   printf '%s' '$RELEASE_TOKEN' > '$remote_release_lock/token'; \
   printf '%s' \"\$now\" > '$remote_release_lock/created_at'; \
   trap - EXIT"; then
  echo "Another production release holds the remote publication lock." >&2
  exit 3
fi
lock_acquired=1
current_manifest_hash="$(
  # shellcheck disable=SC2029
  ssh "${ssh_options[@]}" "$ssh_target" \
    "if test -f '$remote_manifest'; then sha256sum '$remote_manifest' | awk '{print \$1}'; else printf absent; fi"
)"
if [[ "$current_manifest_hash" != "$EXPECTED_PREVIOUS_MANIFEST_SHA256" ]]; then
  echo "Production manifest changed after preflight; refusing to publish stale state." >&2
  exit 3
fi
existing_remote_hash="$(
  # shellcheck disable=SC2029
  ssh "${ssh_options[@]}" "$ssh_target" \
    "if test -f '$remote_apk'; then sha256sum '$remote_apk' | awk '{print \$1}'; fi"
)"
if [[ -n "$existing_remote_hash" && "$existing_remote_hash" != "$EXPECTED_SHA256" ]]; then
  echo "The immutable APK target exists with different bytes; refusing to overwrite it." >&2
  exit 3
fi

if [[ -z "$existing_remote_hash" ]]; then
  scp "${scp_options[@]}" "$APK_FILE" "$ssh_target:$remote_apk_tmp"
  remote_hash="$(
    # shellcheck disable=SC2029
    ssh "${ssh_options[@]}" "$ssh_target" \
      "sha256sum '$remote_apk_tmp' | awk '{print \$1}'"
  )"
  [[ "$remote_hash" == "$EXPECTED_SHA256" ]] || {
    echo "Remote staging APK digest mismatch." >&2
    exit 3
  }
  # shellcheck disable=SC2029
  ssh "${ssh_options[@]}" "$ssh_target" \
    "set -eu; chmod 0644 '$remote_apk_tmp'; mv '$remote_apk_tmp' '$remote_apk'"
fi

scp "${scp_options[@]}" "$CHECKSUM_FILE" "$ssh_target:$remote_checksum_tmp"
scp "${scp_options[@]}" "$MANIFEST_FILE" "$ssh_target:$remote_manifest_tmp"
# shellcheck disable=SC2029
ssh "${ssh_options[@]}" "$ssh_target" \
  "set -eu; chmod 0644 '$remote_checksum_tmp' '$remote_manifest_tmp'; \
   mv '$remote_checksum_tmp' '$remote_checksum'"

public_apk="$(mktemp "${RUNNER_TEMP:-/tmp}/saidian-public-apk.XXXXXX")"
public_apk_verified=0
for attempt in 1 2 3 4 5 6; do
  if effective_url="$(curl --fail --location --proto '=https' --proto-redir '=https' \
    --silent --show-error \
    --connect-timeout 20 --max-time 300 \
    "$APK_PUBLIC_URL" -o "$public_apk" \
    --write-out '%{url_effective}')" && \
    verify_effective_url "$APK_PUBLIC_URL" "$effective_url"; then
    public_hash="$(sha256sum "$public_apk" | awk '{print $1}')"
    if [[ "$public_hash" == "$EXPECTED_SHA256" ]]; then
      public_apk_verified=1
      break
    fi
  fi
  sleep $(( attempt * 5 ))
done
rm -f "$public_apk"
(( public_apk_verified == 1 )) || {
  echo "Public APK URL did not return the uploaded SHA-256; manifest remains unchanged." >&2
  exit 4
}

# The compare and swap happen in one remote shell while the cooperative lock
# is held, so another release or a manual manifest change cannot be overwritten.
# shellcheck disable=SC2029
if ! ssh "${ssh_options[@]}" "$ssh_target" \
  "set -eu; current=absent; \
   if test -f '$remote_manifest'; then current=\$(sha256sum '$remote_manifest' | awk '{print \$1}'); fi; \
   test \"\$current\" = '$EXPECTED_PREVIOUS_MANIFEST_SHA256' || exit 73; \
   rm -f '$remote_manifest_previous' '$remote_manifest_swap_marker'; \
   if test -f '$remote_manifest'; then cp -p '$remote_manifest' '$remote_manifest_previous'; fi; \
   : > '$remote_manifest_swap_marker'; \
   mv '$remote_manifest_tmp' '$remote_manifest'"; then
  echo "Production manifest changed before atomic swap; publication aborted." >&2
  exit 5
fi

public_manifest="$(mktemp "${RUNNER_TEMP:-/tmp}/saidian-public-manifest.XXXXXX")"
expected_manifest_hash="$(sha256sum "$MANIFEST_FILE" | awk '{print $1}')"
separator='?'
[[ "$MANIFEST_PUBLIC_URL" == *\?* ]] && separator='&'
public_manifest_verified=0
for attempt in 1 2 3 4 5 6; do
  cache_busted_url="${MANIFEST_PUBLIC_URL}${separator}release_verify=${RELEASE_TOKEN}-${attempt}"
  if effective_url="$(curl --fail --location --proto '=https' --proto-redir '=https' \
    --silent --show-error \
    --connect-timeout 20 --max-time 60 \
    -H 'Cache-Control: no-cache' \
    "$cache_busted_url" -o "$public_manifest" \
    --write-out '%{url_effective}')" && \
    verify_effective_url "$cache_busted_url" "$effective_url"; then
    actual_manifest_hash="$(sha256sum "$public_manifest" | awk '{print $1}')"
    if [[ "$actual_manifest_hash" == "$expected_manifest_hash" ]]; then
      public_manifest_verified=1
      break
    fi
  fi
  sleep $(( attempt * 5 ))
done
rm -f "$public_manifest"

if (( public_manifest_verified != 1 )); then
  if ! remote_cleanup "$EXPECTED_PREVIOUS_MANIFEST_SHA256"; then
    echo "Public manifest verification failed and rollback could not be confirmed." >&2
    exit 6
  fi
  lock_acquired=0
  if ! verify_public_previous_manifest; then
    echo "The previous manifest was restored remotely but could not be verified publicly." >&2
    exit 6
  fi
  echo "Public manifest verification failed; the previous manifest was restored and verified." >&2
  exit 5
fi

# shellcheck disable=SC2029
if ! ssh "${ssh_options[@]}" "$ssh_target" \
  "rm -f '$remote_manifest_swap_marker' '$remote_manifest_previous'"; then
  echo "Could not commit the verified manifest publication." >&2
  exit 6
fi
publication_committed=1
if ! remote_cleanup "$expected_manifest_hash"; then
  echo "Publication succeeded but the remote lock could not be released." >&2
  exit 6
fi
lock_acquired=0
trap - EXIT
echo "Atomic production publication completed after public APK and manifest verification."
