#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE="${1:?usage: validate_release_artifact.sh <CC-Overlay.app>}"
REQUIRE_DISTRIBUTION_SIGNATURE="${REQUIRE_DISTRIBUTION_SIGNATURE:-0}"

CONTENTS="$APP_BUNDLE/Contents"
INFO_PLIST="$CONTENTS/Info.plist"
EXECUTABLE="$CONTENTS/MacOS/cc-overlay"

[[ -d "$APP_BUNDLE" ]] || { echo "Missing app bundle: $APP_BUNDLE" >&2; exit 1; }
[[ -f "$INFO_PLIST" ]] || { echo "Missing Info.plist" >&2; exit 1; }
[[ -x "$EXECUTABLE" ]] || { echo "Missing executable: $EXECUTABLE" >&2; exit 1; }

[[ "$(plutil -extract CFBundleExecutable raw "$INFO_PLIST")" == "cc-overlay" ]]
[[ "$(plutil -extract CFBundlePackageType raw "$INFO_PLIST")" == "APPL" ]]
RESOURCE_BUNDLE="$CONTENTS/Resources/CC-Overlay_CCOverlay.bundle"
[[ -f "$RESOURCE_BUNDLE/ProviderIcons/claude-code.svg" ]]
[[ -f "$RESOURCE_BUNDLE/ProviderIcons/codex.svg" ]]

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if [[ "$REQUIRE_DISTRIBUTION_SIGNATURE" == "1" ]]; then
  SIGNING_DETAILS="$(codesign -dvvv "$APP_BUNDLE" 2>&1)"
  grep -q "Authority=Developer ID Application" <<<"$SIGNING_DETAILS"
  grep -q "flags=.*runtime" <<<"$SIGNING_DETAILS"
fi

echo "Validated release artifact: $APP_BUNDLE"
