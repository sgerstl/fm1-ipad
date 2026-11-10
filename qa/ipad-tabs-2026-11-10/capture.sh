#!/bin/zsh
# Before/after captures for the iPad tabs Pads · Timeline · Mix (2026-11-10). Usage: capture.sh before|after
# Each scenario: settings written, the demo FM-1 launched stopped with flags, a settled screenshot, the app's window
# cropped out of the simulator's frame when it comes back portrait (iPadOS 26 then shows the landscape-only app
# scaled in a window); a landscape frame is the app, 1:1 at 2x.
set -e
D=758BB7A6-80EC-4437-865C-89A5B9A41750; APP=com.scottgerstl.fm1ipad
OUTD=${0:a:h}/$1; mkdir -p $OUTD
shot() {   # name position(0 full,1 half,2 max) controlsOpen rail extra-flags...
  local name=$1 pos=$2 open=$3 rail=$4; shift 4
  # ONLY="a b": just those scenes (a retake when one caught the app still connecting)
  if [[ -n "$ONLY" && " $ONLY " != *" $name "* ]]; then return; fi
  xcrun simctl terminate $D $APP 2>/dev/null || true
  # the settings as launch arguments (UserDefaults' argument domain): written with `defaults`, cfprefsd served the app
  # stale values; the demo held stopped so nothing moves between before and after
  xcrun simctl launch $D $APP -songPosition $pos -padControlsOpen $open -soundRail.v2 $rail \
    -demo-skiff -demo -demo-stopped -no-intro -demo-chord 4 "$@" >/dev/null
  # settled: two frames a second apart that match, after at least 6 s (the FM-1 read can take longer), at most 30 s
  sleep 6
  for i in {1..24}; do
    xcrun simctl io $D screenshot $OUTD/.a.png >/dev/null 2>&1; sleep 1
    xcrun simctl io $D screenshot $OUTD/$name.png >/dev/null 2>&1
    cmp -s $OUTD/.a.png $OUTD/$name.png && break
  done
  rm -f $OUTD/.a.png
  python3 -c "
from PIL import Image; im=Image.open('$OUTD/$name.png'); w,h=im.size
(im if w > h else im.crop((0,int(h*0.219),w,int(h*0.781)))).save('$OUTD/$name.png')"
  echo $name
}
# the Timeline: full size, Half (T1 and T4 selected), Max, controls shut; and the Pads and Mix, which shouldn't change
shot tl-full           0 YES NO  -page song -song-timeline
shot tl-half           1 YES NO  -page song -song-timeline
shot tl-half-t4        1 YES NO  -page song -song-timeline -demo-track 4
shot tl-half-t4-shut   1 NO  NO  -page song -song-timeline -demo-track 4
shot tl-max            2 YES NO  -page song -song-timeline
shot pads-full-t1      0 YES NO  -page song
shot pads-half-t4      1 YES NO  -page song -demo-track 4
shot mix               1 YES NO  -page mixer
