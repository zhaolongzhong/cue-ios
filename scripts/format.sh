#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

echo "Running format ..."
swiftlint --fix Cue CueApp
