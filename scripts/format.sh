#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

echo "Running format ..."
swiftlint . --quiet --strict
swiftlint --fix Cue CueApp
