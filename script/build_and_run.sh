#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
EXECUTABLE_NAME="cc-overlay"
BUNDLE_NAME="CC-Overlay"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$BUNDLE_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$EXECUTABLE_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
SWIFT_BUILD_FLAGS=(${SWIFT_BUILD_FLAGS:---disable-sandbox})

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/module-cache}"

pkill -x "$EXECUTABLE_NAME" >/dev/null 2>&1 || true

swift build "${SWIFT_BUILD_FLAGS[@]}"
BUILD_DIR="$(swift build "${SWIFT_BUILD_FLAGS[@]}" --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$EXECUTABLE_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
for RESOURCE_BUNDLE in "$BUILD_DIR/CC-Overlay_CCOverlay.bundle" "$BUILD_DIR/CCOverlay_CCOverlay.resources"; do
  if [[ -d "$RESOURCE_BUNDLE" ]]; then
    mkdir -p "$APP_CONTENTS/Resources"
    cp -R "$RESOURCE_BUNDLE" "$APP_CONTENTS/Resources/"
  fi
done

cp "$ROOT_DIR/Sources/CCOverlay/Info.plist" "$INFO_PLIST"

codesign --force --sign - "$APP_BUNDLE" >/dev/null

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$EXECUTABLE_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"com.jadru.cc-overlay\""
    ;;
  --verify|verify)
    open_app
    for _ in {1..20}; do
      if pgrep -x "$EXECUTABLE_NAME" >/dev/null; then
        exit 0
      fi
      sleep 0.25
    done
    echo "Timed out waiting for $EXECUTABLE_NAME to launch" >&2
    exit 1
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
