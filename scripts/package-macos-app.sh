#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-debug}"
if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
	echo "usage: $0 [debug|release]" >&2
	exit 1
fi

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
EXEC_SRC="${BIN_DIR}/ChronaCLI"
APP_DIR="${BIN_DIR}/Chrona.app"
CONTENTS="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp "$EXEC_SRC" "${MACOS_DIR}/ChronaCLI"
chmod +x "${MACOS_DIR}/ChronaCLI"
cp "${ROOT}/MacOSApp/Info.plist" "${CONTENTS}/Info.plist"

echo "Built: ${APP_DIR}"
