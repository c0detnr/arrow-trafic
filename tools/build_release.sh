#!/usr/bin/env bash
# Builds the signed Play Store AAB. Keystore secrets stay outside the repo.
set -euo pipefail
cd "$(dirname "$0")/.."
CRED="${CRED:-$HOME/.keys/arrowtrafic/credentials.txt}"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$(sed -n 's/^keystore=//p' "$CRED")"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$(sed -n 's/^alias=//p' "$CRED")"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(sed -n 's/^password=//p' "$CRED")"
export JAVA_HOME="${JAVA_HOME:-$(mise where java@temurin-17)}"
mkdir -p build
godot --headless --export-release "Android" build/arrowtrafic.aab
ls -la build/arrowtrafic.aab
