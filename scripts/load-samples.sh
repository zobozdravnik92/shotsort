#!/bin/zsh
# Copies the screenshots in SampleScreenshots/ into the app's debug samples
# folder on a booted Simulator, then relaunches the app so it sorts them.
# Usage: scripts/load-samples.sh [simulator-id]   (defaults to the booted one)
set -euo pipefail

BUNDLE_ID="com.rokpremuz.ScreenshotSorter"
DEVICE="${1:-booted}"
SOURCE="$(cd "$(dirname "$0")/.." && pwd)/SampleScreenshots"

if [[ ! -d "$SOURCE" ]] || [[ -z "$(ls -A "$SOURCE")" ]]; then
  echo "No images in $SOURCE. Add some screenshots there first."
  exit 1
fi

CONTAINER="$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" data)" || {
  echo "The app isn't installed on that Simulator. Run it from Xcode once first."
  exit 1
}

mkdir -p "$CONTAINER/Documents/Samples"
cp "$SOURCE"/* "$CONTAINER/Documents/Samples/"
echo "Copied $(ls "$SOURCE" | wc -l | tr -d ' ') screenshots."

xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$DEVICE" "$BUNDLE_ID" >/dev/null
echo "Relaunched the app; it will sort them now."
