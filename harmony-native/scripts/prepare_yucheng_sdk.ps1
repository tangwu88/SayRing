param(
  [Parameter(Mandatory = $true)][string]$SourceHar,
  [Parameter(Mandatory = $true)][string]$OutputHar
)

$ErrorActionPreference = 'Stop'
$namespacePairs = [ordered]@{
  'jl-rcsp-util' = 'yuc_jl_rcsp_util'
  'jl_rcsp_util' = 'yuc_jl_rcsp_util'
  'jl-rcsp-op' = 'yuc_jl_rcsp_op'
  'jl_rcsp_op' = 'yuc_jl_rcsp_op'
  'jl-rcsp' = 'yuc_jl_rcsp'
  'jl_rcsp' = 'yuc_jl_rcsp'
  'jl-ota' = 'yuc_jl_ota'
  'jl_ota' = 'yuc_jl_ota'
  'jl-auth' = 'yuc_jl_auth'
  'jl_auth' = 'yuc_jl_auth'
  'ecg_analyze' = 'yuc_ecg_analyze'
}

function Update-YuchengPackage {
  param(
    [Parameter(Mandatory = $true)][string]$PackagePath,
    [Parameter(Mandatory = $true)][string]$ScratchRoot
  )

  # Every bundled HAR is a private part of the Yucheng distribution. Process
  # it recursively before rewriting the parent dependency references.
  $nestedHars = @(Get-ChildItem -LiteralPath $PackagePath -Recurse -File -Filter '*.har')
  foreach ($har in $nestedHars) {
    $child = Join-Path $ScratchRoot ([Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $child | Out-Null
    try {
      & tar.exe -xf $har.FullName -C $child
      if ($LASTEXITCODE -ne 0) { throw "Failed to extract nested HAR: $($har.Name)" }
      $childPackage = Join-Path $child 'package'
      if (-not (Test-Path -LiteralPath $childPackage -PathType Container)) {
        throw "Invalid nested HAR package: $($har.Name)"
      }
      Update-YuchengPackage -PackagePath $childPackage -ScratchRoot $ScratchRoot
      $rebuilt = Join-Path $child 'rebuilt.har'
      & tar.exe -czf $rebuilt -C $child package
      if ($LASTEXITCODE -ne 0) { throw "Failed to rebuild nested HAR: $($har.Name)" }
      Move-Item -LiteralPath $rebuilt -Destination $har.FullName -Force
    } finally {
      if (Test-Path -LiteralPath $child) { Remove-Item -LiteralPath $child -Recurse -Force }
    }
  }

  $textFiles = Get-ChildItem -LiteralPath $PackagePath -Recurse -File | Where-Object {
    $_.Extension -in @('.ets', '.ts', '.js', '.json', '.json5')
  }
  foreach ($file in $textFiles) {
    $content = [IO.File]::ReadAllText($file.FullName)
    $updated = $content
    foreach ($entry in $namespacePairs.GetEnumerator()) {
      $old = [string]$entry.Key
      $new = [string]$entry.Value
      $updated = $updated.Replace("'$old'", "'$new'").Replace(
        '"' + $old + '"', '"' + $new + '"').Replace($old + '/', $new + '/')
    }
    if ($updated -ne $content) {
      [IO.File]::WriteAllText($file.FullName, $updated, [Text.UTF8Encoding]::new($false))
    }
  }

  # The vendor manifest requests PERSISTENT_BLUETOOTH_PEERS_MAC. HarmonyOS
  # grants that restricted permission only to privileged applications, so a
  # normal AppGallery/development profile cannot even install the merged HAP.
  # The SDK already catches failures from the optional system-persistence API
  # and keeps its Preferences/scanning fallback, therefore remove only the
  # ineligible manifest declaration while leaving all vendor protocol code.
  $moduleManifest = Join-Path $PackagePath 'src\main\module.json'
  if (Test-Path -LiteralPath $moduleManifest) {
    $moduleProfile = [IO.File]::ReadAllText($moduleManifest) | ConvertFrom-Json
    if ($moduleProfile.module.PSObject.Properties.Name -contains 'requestPermissions') {
      $moduleProfile.module.requestPermissions = @($moduleProfile.module.requestPermissions | Where-Object {
        $_.name -ne 'ohos.permission.PERSISTENT_BLUETOOTH_PEERS_MAC'
      })
      $moduleJson = $moduleProfile | ConvertTo-Json -Depth 100
      [IO.File]::WriteAllText($moduleManifest, $moduleJson, [Text.UTF8Encoding]::new($false))
    }
  }

  # A normal application cannot query or mutate the system persistent BLE-ID
  # list. Merely omitting the permission makes the vendor's guarded calls
  # return safely, but Harmony still emits an error log on every reconnect
  # poll. Replace only this optional persistence facade with a deterministic
  # no-op so the SDK uses its documented Preferences + scan fallback cleanly.
  $persistentFacade = Join-Path $PackagePath 'src\main\ets\transport\PersistentBleDeviceId.ets'
  if (Test-Path -LiteralPath $persistentFacade) {
    $facadeSource = @'
export class PersistentBleDeviceId {
  static add(_deviceId: string): void {}
  static remove(_deviceId: string): void {}
  static getSystemIds(): string[] { return [] }
  static getPrimarySystemId(): string { return '' }
  static isInSystemList(_deviceId: string): boolean { return false }
  static resolveForReconnect(storedDeviceId: string): string { return storedDeviceId }
}
'@
    [IO.File]::WriteAllText($persistentFacade, $facadeSource, [Text.UTF8Encoding]::new($false))
  }
}

$source = [IO.Path]::GetFullPath($SourceHar)
$output = [IO.Path]::GetFullPath($OutputHar)
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
  throw "Yucheng SDK HAR not found: $source"
}
if ($source -eq $output) {
  throw 'SourceHar and OutputHar must be different so the vendor original remains recoverable.'
}

$work = Join-Path ([IO.Path]::GetTempPath()) ("saydian-yuc-sdk-" + [Guid]::NewGuid().ToString('N'))
$scratch = Join-Path $work 'scratch'
New-Item -ItemType Directory -Path $work | Out-Null
New-Item -ItemType Directory -Path $scratch | Out-Null
try {
  & tar.exe -xf $source -C $work
  if ($LASTEXITCODE -ne 0) { throw 'Failed to extract Yucheng SDK HAR.' }
  $package = Join-Path $work 'package'
  $manifest = Join-Path $package 'oh-package.json5'
  if (-not (Test-Path -LiteralPath $manifest)) { throw 'Invalid Yucheng SDK HAR: package manifest is missing.' }

  # Harmony normalizes dashes and underscores in OHM module names. W8's
  # jl-ota/jl-rcsp family therefore collides at runtime with W9's
  # jl_ota/jl_rcsp family even when dependency installation succeeds. Isolate
  # the vendor-private protocol graph and ECG analysis. bmpconvert deliberately
  # remains shared: both versions ship the same native library filename, and
  # OHPM resolves the W8 1.0 API to the existing backward-compatible W9 1.1
  # implementation without packaging duplicate native binaries.
  Update-YuchengPackage -PackagePath $package -ScratchRoot $scratch

  $parent = Split-Path -Parent $output
  if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent | Out-Null }
  & tar.exe -czf $output -C $work package
  if ($LASTEXITCODE -ne 0) { throw 'Failed to rebuild Yucheng SDK HAR.' }
  Write-Output ("Prepared Yucheng SDK: " + $output)
  Write-Output ("SHA256: " + (Get-FileHash -Algorithm SHA256 -LiteralPath $output).Hash)
} finally {
  if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
