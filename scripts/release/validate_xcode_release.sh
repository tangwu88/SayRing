#!/bin/sh

set -eu

if [ "${CONFIGURATION:-}" != "Release" ]; then
  exit 0
fi

case "${SAIDIAN_PRODUCTION_RELEASE:-}" in
  ""|false) production_release=false ;;
  true) production_release=true ;;
  *)
    echo "error: SAIDIAN_PRODUCTION_RELEASE must be true, false, or unset." >&2
    exit 1
    ;;
esac

case "${SAIDIAN_ALLOW_QA_RELEASE:-}" in
  ""|false) qa_release=false ;;
  true) qa_release=true ;;
  *)
    echo "error: SAIDIAN_ALLOW_QA_RELEASE must be true, false, or unset." >&2
    exit 1
    ;;
esac

if [ "$production_release" = "$qa_release" ]; then
  echo "error: Release builds require exactly one explicit Production or QA mode." >&2
  exit 1
fi

if [ "$qa_release" = "true" ]; then
  echo "warning: Building an explicitly non-production QA Release."
  exit 0
fi

if [ "${PRODUCT_BUNDLE_IDENTIFIER:-}" != "cc.saidian.app" ]; then
  echo "error: Production iOS Release requires PRODUCT_BUNDLE_IDENTIFIER=cc.saidian.app." >&2
  exit 1
fi

if [ "${APS_ENVIRONMENT:-}" != "production" ]; then
  echo "error: Production iOS Release requires APS_ENVIRONMENT=production." >&2
  exit 1
fi

if [ "${CODE_SIGNING_ALLOWED:-YES}" = "NO" ]; then
  echo "error: Production iOS Release cannot disable code signing." >&2
  exit 1
fi

require_value() {
  if [ -z "$2" ]; then
    echo "error: Production iOS Release requires $1." >&2
    exit 1
  fi
}

require_https() {
  case "$2" in
    https://*) ;;
    *)
      echo "error: Production iOS Release requires HTTPS $1." >&2
      exit 1
      ;;
  esac
}

require_value JPUSH_APP_KEY "${JPUSH_APP_KEY:-}"
require_value SAIDIAN_DEVELOPMENT_TEAM "${SAIDIAN_DEVELOPMENT_TEAM:-}"
require_value SAIDIAN_CODE_SIGN_IDENTITY "${SAIDIAN_CODE_SIGN_IDENTITY:-}"
require_value SAIDIAN_PROVISIONING_PROFILE_SPECIFIER \
  "${SAIDIAN_PROVISIONING_PROFILE_SPECIFIER:-}"
require_value SAYDIAN_UPDATE_ALLOWED_HOSTS "${SAYDIAN_UPDATE_ALLOWED_HOSTS:-}"
require_https SAYDIAN_API_BASE_URL "${SAYDIAN_API_BASE_URL:-}"
require_https SAYDIAN_UPDATE_MANIFEST_URL "${SAYDIAN_UPDATE_MANIFEST_URL:-}"
