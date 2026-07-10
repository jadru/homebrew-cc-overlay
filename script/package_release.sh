#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:?VERSION is required, for example 0.10.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$VERSION}"
SIGN_IDENTITY="${SIGN_IDENTITY:?SIGN_IDENTITY must name a Developer ID Application certificate}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
NOTARIZE="${NOTARIZE:-1}"
ARCHS="${ARCHS:-arm64 x86_64}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist/release"
APP_BUNDLE="$DIST_DIR/CC-Overlay.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ARCHIVE="$DIST_DIR/CC-Overlay-v${VERSION}-macos.zip"
CHECKSUM="$ARCHIVE.sha256"
EXECUTABLE_NAME="cc-overlay"
INFO_SOURCE="$ROOT_DIR/Sources/CCOverlay/Info.plist"
ENTITLEMENTS="$ROOT_DIR/Sources/CCOverlay/cc-overlay.entitlements"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must use semantic versioning: $VERSION" >&2
  exit 2
fi

if [[ "$NOTARIZE" == "1" && -z "$NOTARY_PROFILE" ]]; then
  echo "NOTARY_PROFILE is required when NOTARIZE=1" >&2
  exit 2
fi

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/module-cache}"

declare -a binaries=()
resource_bundle=""
for arch in $ARCHS; do
  swift build -c release --arch "$arch" --disable-sandbox
  build_dir="$(swift build -c release --arch "$arch" --disable-sandbox --show-bin-path)"
  binaries+=("$build_dir/$EXECUTABLE_NAME")
  if [[ -z "$resource_bundle" && -d "$build_dir/CC-Overlay_CCOverlay.bundle" ]]; then
    resource_bundle="$build_dir/CC-Overlay_CCOverlay.bundle"
  fi
done

[[ -n "$resource_bundle" ]] || { echo "SwiftPM resource bundle was not built" >&2; exit 1; }

rm -rf "$DIST_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

if [[ "${#binaries[@]}" == "1" ]]; then
  cp "${binaries[0]}" "$MACOS_DIR/$EXECUTABLE_NAME"
else
  lipo -create "${binaries[@]}" -output "$MACOS_DIR/$EXECUTABLE_NAME"
fi
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"
cp -R "$resource_bundle" "$RESOURCES_DIR/"
cp "$INFO_SOURCE" "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$CONTENTS_DIR/Info.plist"

sign_args=(--force --sign "$SIGN_IDENTITY" --options runtime --entitlements "$ENTITLEMENTS")
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  sign_args+=(--timestamp=none)
else
  sign_args+=(--timestamp)
fi
codesign "${sign_args[@]}" "$APP_BUNDLE"

REQUIRE_DISTRIBUTION_SIGNATURE="$([[ "$SIGN_IDENTITY" == "-" ]] && echo 0 || echo 1)" \
  "$ROOT_DIR/script/validate_release_artifact.sh" "$APP_BUNDLE"

ditto --norsrc --noextattr --noqtn --noacl -c -k --keepParent "$APP_BUNDLE" "$ARCHIVE"
"$ROOT_DIR/script/validate_release_archive.sh" "$ARCHIVE"

if [[ "$NOTARIZE" == "1" ]]; then
  xcrun notarytool submit "$ARCHIVE" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_BUNDLE"
  "$ROOT_DIR/script/validate_release_artifact.sh" "$APP_BUNDLE"
  ditto --norsrc --noextattr --noqtn --noacl -c -k --keepParent "$APP_BUNDLE" "$ARCHIVE"
  "$ROOT_DIR/script/validate_release_archive.sh" "$ARCHIVE"
fi

shasum -a 256 "$ARCHIVE" > "$CHECKSUM"
echo "Release archive: $ARCHIVE"
echo "Checksum: $CHECKSUM"
