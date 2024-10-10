#!/usr/bin/env bash

set -euo pipefail

# Default arguments
RUN_UNIT_TESTS=true
RUN_UI_TESTS=false

# Parse arguments
while getopts ":uv" opt; do
  case $opt in
    v)
      RUN_UI_TESTS=true
      RUN_UNIT_TESTS=false
      ;;
    u)
      RUN_UNIT_TESTS=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Run Unit Tests
if [ "$RUN_UNIT_TESTS" = true ]; then
  xcodebuild test \
    -project Cue.xcodeproj \
    -scheme Cue \
    -only-testing:CueTests

  cd "$(dirname "$0")/../CueApp"
  swift test
fi

# Run UI Tests
if [ "$RUN_UI_TESTS" = true ]; then
  cd "$(dirname "$0")/.."
  xcodebuild test \
    -project Cue.xcodeproj \
    -scheme Cue \
    -only-testing:CueUITests \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
fi
