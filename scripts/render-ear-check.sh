#!/bin/bash
# B25 (#36) — render all 13 seed songs to ~/Downloads/ylapiano-ear-check/
# One command, re-runnable after any transcription edit.
set -euo pipefail
cd "$(dirname "$0")/.."

SIM="${EAR_CHECK_SIM:-iPad Pro 13-inch (M4)}"

xcodebuild test \
  -project Ylapiano.xcodeproj \
  -scheme Ylapiano \
  -destination "platform=iOS Simulator,name=${SIM}" \
  -only-testing:YlapianoTests/EarCheckRenderTests

echo
echo "Renders → ~/Downloads/ylapiano-ear-check/"
open "$HOME/Downloads/ylapiano-ear-check" 2>/dev/null || true
