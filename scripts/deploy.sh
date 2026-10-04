#!/usr/bin/env bash
# Builds and installs WalkPadSteps onto the paired Apple Watch. Re-run this
# every ~7 days to refresh a free Apple ID's expiring provisioning profile.
# Usage: ./deploy.sh (optionally set WATCH_DEVICE_ID to skip auto-detection)

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$PROJECT_DIR/WalkPadSteps.xcodeproj"
SCHEME="WalkPadSteps Watch App"
DERIVED_DATA="$PROJECT_DIR/.build/DerivedData"
CONFIGURATION="Debug"

if [ -z "${WATCH_DEVICE_ID:-}" ]; then
  WATCH_DEVICE_ID=$(xcrun devicectl list devices | awk '/watchOS/ {for (i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) print $i}' | head -n 1)
fi

if [ -z "$WATCH_DEVICE_ID" ]; then
  echo "ERROR: couldn't auto-detect a paired Apple Watch. Set WATCH_DEVICE_ID manually (see xcrun devicectl list devices)."
  exit 1
fi

echo "=== $(date) : starting deploy ==="

echo "Building for device: $WATCH_DEVICE_ID"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=watchOS,id=$WATCH_DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates \
  build

APP_PATH=$(find "$DERIVED_DATA/Build/Products/$CONFIGURATION-watchos" -maxdepth 1 -name "*.app" | head -n 1)

if [ -z "$APP_PATH" ]; then
  echo "ERROR: couldn't find built .app in $DERIVED_DATA/Build/Products/$CONFIGURATION-watchos"
  exit 1
fi

echo "Installing $APP_PATH to $WATCH_DEVICE_ID"
xcrun devicectl device install app --device "$WATCH_DEVICE_ID" "$APP_PATH"

echo "=== $(date) : deploy complete ==="
