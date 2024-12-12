#!/usr/bin/env bash

set -euo pipefail

# Default arguments
RUN_UNIT_TESTS=true
RUN_UI_TESTS=false

# Parse arguments
while getopts ":uia" opt; do
  case $opt in
    i)
      RUN_UI_TESTS=true
      RUN_UNIT_TESTS=false
      ;;
    u)
      RUN_UNIT_TESTS=true
      ;;
    a)
      RUN_UI_TESTS=true
      RUN_UNIT_TESTS=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

echo "Cleaning build directory..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Cue-*

COMMON_SETTINGS=(
    -project Cue.xcodeproj
    -scheme Cue
    -skipPackagePluginValidation
    CODE_SIGN_IDENTITY=""
    CODE_SIGNING_REQUIRED=NO
    CODE_SIGNING_ALLOWED=NO
)

# Run Unit Tests
if [ "$RUN_UNIT_TESTS" = true ]; then
  xcodebuild test \
    "${COMMON_SETTINGS[@]}" \
    -only-testing:CueTests
fi

# Run UI Tests
if [ "$RUN_UI_TESTS" = true ]; then
  cd "$(dirname "$0")/.."
  xcodebuild test \
    "${COMMON_SETTINGS[@]}" \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
    -only-testing:CueUITests
fi
