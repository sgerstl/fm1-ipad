#!/bin/sh
# How evenly the Pixel's "USB RX Dejitter underrun" lines are spaced while Lupe plays the FM-1.
# Evenly spaced (CV under ~0.3) at about |clock offset| x 48,000 a second means the phone takes a fixed number of
# frames per USB millisecond from a source whose clock is off (the FM-1's is): a rate mismatch, which the FM-1 could
# remove by sending exactly 48 frames every packet (qa/device-checks/2026-11-15-audio-through.md, option B).
# Irregular spacing means something else (load, the bus, the FM-1's own pacing).
# Usage: android/scripts/dejitter-intervals.sh [seconds] [adb args, e.g. -s SERIAL]
secs=${1:-20}; shift 2>/dev/null
adb "$@" logcat -c
sleep "$secs"
adb "$@" logcat -d -v epoch | grep "USB RX Dejitter underrun" | awk -v secs="$secs" '
    { t = $1 + 0; if (n > 0) { d = (t - last) * 1000; s += d; ss += d * d; iv[++m] = d } last = t; n++
      if (match($0, /Avail: *[0-9]+ Had: *[0-9]+ Received *[0-9]+/)) sig[substr($0, RSTART, RLENGTH)]++ }
    END {
      printf "dejitter lines in %d s: %d (%.1f a second)\n", secs, n, n / secs
      if (m < 2) exit
      mean = s / m; sd = sqrt(ss / m - mean * mean); cv = sd / mean
      printf "intervals: mean %.1f ms, sd %.1f ms, CV %.2f -> %s\n", mean, sd, cv, (cv < 0.3 ? "evenly spaced: a clock-rate mismatch" : (cv < 0.7 ? "partly regular" : "irregular"))
      printf "as a clock offset at one frame per line: ~%d ppm\n", (1000 / mean) / 48000 * 1e6
      print "the numbers in the lines, and how often:"
      for (k in sig) print "  " sig[k] "x  " k
    }'
