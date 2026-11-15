#!/bin/bash
# Builds libLupeThrough.so (app/src/main/cpp/through: audio through on AAudio) for arm64 Android with the NDK's clang,
# into the jniLibs folder Gradle packs. No CMake: one translation unit, linked against AAudio and the log.
#   build-through.sh <out-dir> [debug|release]     out-dir gets arm64-v8a/libLupeThrough.so
# Gradle's :app:buildThrough task runs it before every build.
set -euo pipefail
. "$(dirname "$0")/env.sh"
OUT="${1:?out dir}"; CONFIG="${2:-debug}"
SRC="$(cd "$(dirname "$0")/../app/src/main/cpp/through" && pwd)"
CXX="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android33-clang++"
DEST="$OUT/arm64-v8a"
mkdir -p "$DEST"
OPT="-O2"; [ "$CONFIG" = release ] && OPT="-O3 -DNDEBUG"
"$CXX" -std=c++17 $OPT -g -fPIC -shared -Wall -Wextra -fno-exceptions -fno-rtti -static-libstdc++ \
    -Wl,-z,max-page-size=16384 -Wl,--no-undefined \
    -o "$DEST/libLupeThrough.so" "$SRC/through_engine.cpp" -laaudio -llog
[ "$CONFIG" = release ] && "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-strip" --strip-unneeded "$DEST/libLupeThrough.so"
echo "build-through: $(du -h "$DEST/libLupeThrough.so" | cut -f1) $DEST/libLupeThrough.so"
