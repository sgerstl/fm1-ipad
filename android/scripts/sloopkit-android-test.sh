#!/bin/bash
# Gate 1: builds SloopKit's tests for arm64 Android and runs them on whatever `adb` sees (the Pixel, or an
# arm64 emulator: `emulator -avd Medium_Phone_API_36.1 -no-window`). Extra arguments go to the test runner,
# e.g. --filter SessionTests. The Apple-only tests (CoreMIDI sims, firmware installs, AVFoundation) aren't built.
# The session tests wait 5 s at most, so run this on a quiet Mac: under load (a parallel `swift test`, Xcode
# builds) a few time out on both platforms alike.
set -euo pipefail
. "$(dirname "$0")/env.sh"
cd "$(dirname "$0")/../../ios/SloopKit"
SCRATCH="${SCRATCH:-$PWD/.build-android}"
"$SWIFT_TC/swift" build --build-tests --swift-sdk "$SWIFT_ANDROID_TRIPLE" --scratch-path "$SCRATCH"
P="$SCRATCH/debug"
D=/data/local/tmp/sloopkit
adb shell "rm -rf $D && mkdir -p $D"
adb push "$SWIFT_ANDROID_LIBS"/*.so "$NDK_LIBCXX" "$D/" >/dev/null
adb push "$P/SloopKitTests-test-runner" "$P/SloopKitTests.so" "$P/SloopKit_SloopKit.bundle" "$P/SloopKit_SloopKitTests.bundle" "$D/" >/dev/null
adb shell "cd $D && LD_LIBRARY_PATH=$D ./SloopKitTests-test-runner --testing-library swift-testing $*"
