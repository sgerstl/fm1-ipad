#!/bin/sh
# Counts the Pixel's USB RX dejitter underrun lines per second while the audio spike runs (the app can't read the system log).
# Usage: android/scripts/count-dejitter.sh [seconds] [adb args, e.g. -s SERIAL]   Run once per input rate and compare.
secs=${1:-10}; shift 2>/dev/null
adb "$@" logcat -c
sleep "$secs"
n=$(adb "$@" logcat -d | grep -c "USB RX Dejitter underrun")
echo "dejitter underrun lines in ${secs} s: $n  (about $((n / secs)) per second)"
