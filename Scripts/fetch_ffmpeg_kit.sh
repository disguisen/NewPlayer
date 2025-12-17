#!/usr/bin/env bash
set -euo pipefail

RELEASE_URL=${1:-"https://github.com/tanersener/ffmpeg-kit/releases/download/v6.0-lts/ffmpeg-kit-ios-full-shared-6.0-lts.zip"}
TMP_FILE="/tmp/ffmpeg-kit.zip"

curl -L "$RELEASE_URL" -o "$TMP_FILE"
checksum=$(shasum -a 256 "$TMP_FILE" | awk '{print $1}')
echo "URL: $RELEASE_URL"
echo "Checksum: $checksum"
