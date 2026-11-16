#!/bin/sh
# Lupe's version, one number for iPad, iPhone and Android (Scott, 2026-11-17). Writes VERSION and the iOS
# MARKETING_VERSION, and bumps the iOS build. Android reads VERSION (android/app/build.gradle.kts) and keeps its
# own versionCode, bumped by hand when a new APK ships.
#   tools/set-version.sh 0.3.1
set -e
v="$1"
[ -n "$v" ] || { echo "usage: $0 X.Y.Z" >&2; exit 1; }
root="$(cd "$(dirname "$0")/.." && pwd)"
printf '%s\n' "$v" > "$root/VERSION"
yml="$root/ios/project.yml"
b=$(sed -n 's/.*CURRENT_PROJECT_VERSION: "\([0-9]*\)".*/\1/p' "$yml")
sed -i '' "s/MARKETING_VERSION: \"[^\"]*\"/MARKETING_VERSION: \"$v\"/; s/CURRENT_PROJECT_VERSION: \"$b\"/CURRENT_PROJECT_VERSION: \"$((b + 1))\"/" "$yml"
echo "Lupe $v (iOS build $((b + 1))). Run xcodegen in ios/; bump versionCode in android/app/build.gradle.kts for a new APK."
