#!/bin/bash
# Builds libLupeNative.so (android/core) for arm64 Android and copies it, with exactly the Swift runtime
# libraries it needs (followed through ELF NEEDED) and libc++_shared.so, into the jniLibs folder Gradle packs.
#   build-native.sh <out-dir> [debug|release]     out-dir gets arm64-v8a/*.so
# Gradle's :app:buildSwift task runs it before every build.
set -euo pipefail
. "$(dirname "$0")/env.sh"
OUT="${1:?out dir}"; CONFIG="${2:-debug}"
CORE="$(cd "$(dirname "$0")/../core" && pwd)"
"$SWIFT_TC/swift" build --package-path "$CORE" --swift-sdk "$SWIFT_ANDROID_TRIPLE" \
    --scratch-path "$CORE/.build-android" -c "$CONFIG" --product LupeNative
BUILT="$CORE/.build-android/$CONFIG"
READELF="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf"
STRIP="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-strip"
DEST="$OUT/arm64-v8a"
rm -rf "$DEST"; mkdir -p "$DEST"

locate() { for d in "$BUILT" "$SWIFT_ANDROID_LIBS"; do if [ -f "$d/$1" ]; then echo "$d/$1"; return 0; fi; done; return 0; }
queue="libLupeNative.so"; done_list=" "
while [ -n "$queue" ]; do
    lib="${queue%% *}"; [ "$queue" = "$lib" ] && queue="" || queue="${queue#* }"
    case "$done_list" in *" $lib "*) continue ;; esac
    done_list="$done_list$lib "
    if [ "$lib" = libc++_shared.so ]; then cp "$NDK_LIBCXX" "$DEST/"; continue; fi
    f="$(locate "$lib")"; [ -n "$f" ] || continue         # a system library (libc, liblog, libandroid…)
    cp "$f" "$DEST/"
    for n in $("$READELF" -d "$f" | sed -n 's/.*NEEDED.*\[\(.*\)\]/\1/p'); do queue="${queue:+$queue }$n"; done
done
if [ "$CONFIG" = release ]; then "$STRIP" --strip-unneeded "$DEST"/*.so; fi
echo "build-native: $(ls "$DEST" | wc -l | tr -d ' ') libraries, $(du -sh "$DEST" | cut -f1) in $DEST"
