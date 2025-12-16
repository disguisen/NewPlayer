#!/usr/bin/env bash
set -euo pipefail

# Fetch FFmpegKit iOS full shared build from GitHub releases and print the checksum
# so it can be wired into Package.swift via the FFMPEG_KIT_BINARY_URL and
# FFMPEG_KIT_CHECKSUM environment variables.

VERSION="6.0-lts"
ARTIFACT="ffmpeg-kit-ios-full-shared-${VERSION}.zip"
BASE_URL="https://github.com/tanersener/ffmpeg-kit/releases/download/v${VERSION}/${ARTIFACT}"
DEST="${TMPDIR:-/tmp}/${ARTIFACT}"

echo "Downloading ${BASE_URL} -> ${DEST}" >&2
curl -L -o "${DEST}" "${BASE_URL}"

echo "Computing checksum for ${DEST}" >&2
swift package compute-checksum "${DEST}"

echo "Use the values below to enable FFmpegKit in Package.swift:" >&2
echo "FFMPEG_KIT_BINARY_URL=${BASE_URL}" >&2
