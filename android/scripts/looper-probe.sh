#!/bin/bash
# Gate 2: the @MainActor-on-Looper proof, on whatever `adb` sees. Runs the probe, then the control run
# (no hook: the main actor must never run). Both must print PASS.
set -euo pipefail
. "$(dirname "$0")/env.sh"
cd "$(dirname "$0")/../core"
"$SWIFT_TC/swift" build --swift-sdk "$SWIFT_ANDROID_TRIPLE" --scratch-path .build-android --product looper-probe
D=/data/local/tmp/lupe
adb shell "mkdir -p $D"
adb push "$SWIFT_ANDROID_LIBS"/*.so "$NDK_LIBCXX" .build-android/debug/looper-probe "$D/" >/dev/null
adb shell "cd $D && LD_LIBRARY_PATH=$D ./looper-probe"
adb shell "cd $D && LD_LIBRARY_PATH=$D ./looper-probe --control"
