#!/bin/bash
set -euo pipefail

export COPYFILE_DISABLE=1

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
TMP_DIR="$ROOT_DIR/.build/source-bundle"
STAGING_ROOT="$TMP_DIR/waker"
ARCHIVE_PATH="$DIST_DIR/Waker-source.zip"

rm -rf "$TMP_DIR"
mkdir -p "$STAGING_ROOT" "$DIST_DIR"

cp "$ROOT_DIR/Package.swift" "$STAGING_ROOT/"
cp "$ROOT_DIR/README.md" "$STAGING_ROOT/"
cp "$ROOT_DIR/.gitignore" "$STAGING_ROOT/"
cp -R "$ROOT_DIR/Sources" "$STAGING_ROOT/Sources"
cp -R "$ROOT_DIR/scripts" "$STAGING_ROOT/scripts"

find "$STAGING_ROOT" -name '.DS_Store' -delete
find "$STAGING_ROOT" -name '._*' -delete

rm -f "$ARCHIVE_PATH"
(
    cd "$TMP_DIR"
    zip -r -X "$ARCHIVE_PATH" "waker" >/dev/null
)

echo "Source bundle: $ARCHIVE_PATH"
