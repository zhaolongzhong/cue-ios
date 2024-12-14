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

CONFIGURATION="Debug"

COMMON_SETTINGS=(
    -project Cue.xcodeproj
    -scheme Cue
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
    -configuration "${CONFIGURATION}"
    -skipPackagePluginValidation
    CODE_SIGN_IDENTITY="-"
    CODE_SIGNING_REQUIRED=NO
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_STYLE=Manual
    COMPILER_INDEX_STORE_ENABLE=NO
    ENABLE_TESTABILITY=YES
)

echo "Building for testing..."
# Clean up before build
rm -rf "./TestResults.xcresult"
xcodebuild build-for-testing \
    "${COMMON_SETTINGS[@]}" \
    -resultBundlePath "./TestResults.xcresult"

# Run Unit Tests
if [ "$RUN_UNIT_TESTS" = true ]; then
    echo "Running unit tests..."
    # Clean up before test run
    rm -rf "./TestResults.xcresult"
    xcodebuild test-without-building \
        "${COMMON_SETTINGS[@]}" \
        -only-testing:CueTests \
        -resultBundlePath "./TestResults.xcresult"
fi

# Run UI Tests
if [ "$RUN_UI_TESTS" = true ]; then
    echo "Running UI tests..."
    # Clean up before UI test run
    rm -rf "./TestResults.xcresult"
    xcodebuild test-without-building \
        "${COMMON_SETTINGS[@]}" \
        -only-testing:CueUITests \
        -resultBundlePath "./TestResults.xcresult"
fi
