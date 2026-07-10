#!/usr/bin/env bash
set -euo pipefail

ARCHIVE="${1:?usage: validate_release_archive.sh <CC-Overlay.zip>}"

[[ -f "$ARCHIVE" ]] || { echo "Missing release archive: $ARCHIVE" >&2; exit 1; }

archive_paths="$(unzip -Z1 "$ARCHIVE")"
grep -qx 'CC-Overlay.app/Contents/Info.plist' <<<"$archive_paths"
grep -qx 'CC-Overlay.app/Contents/MacOS/cc-overlay' <<<"$archive_paths"
grep -qx 'CC-Overlay.app/Contents/Resources/CC-Overlay_CCOverlay.bundle/ProviderIcons/claude-code.svg' <<<"$archive_paths"
grep -qx 'CC-Overlay.app/Contents/Resources/CC-Overlay_CCOverlay.bundle/ProviderIcons/codex.svg' <<<"$archive_paths"

if grep -Eq '(^|/)\._|(^|/)\.DS_Store$|^__MACOSX/' <<<"$archive_paths"; then
  echo "Release archive contains Finder metadata files" >&2
  exit 1
fi

echo "Validated release archive: $ARCHIVE"
