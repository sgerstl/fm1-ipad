#!/bin/zsh
# Before/after captures for the one-row top bar (2026-11-10). Usage: capture.sh before|after
# Each scenario: settings written, the demo FM-1 launched stopped with flags, a settled screenshot, the app's window
# cropped out of the simulator's frame when it comes back portrait (iPadOS 26 then shows the landscape-only app
# scaled in a window); a landscape frame is the app, 1:1 at 2x.
set -e
D=758BB7A6-80EC-4437-865C-89A5B9A41750; APP=com.scottgerstl.fm1ipad
OUTD=${0:a:h}/$1; mkdir -p $OUTD
shot() {   # name position(0 full,1 half,2 max) controlsOpen rail extra-flags...
  local name=$1 pos=$2 open=$3 rail=$4; shift 4
  xcrun simctl terminate $D $APP 2>/dev/null || true
  # the settings as launch arguments (UserDefaults' argument domain): written with `defaults`, cfprefsd served the app
  # stale values; the demo held stopped so nothing moves between before and after
  xcrun simctl launch $D $APP -songPosition $pos -padControlsOpen $open -soundRail.v2 $rail \
    -demo-skiff -demo -demo-stopped -no-intro -demo-chord 4 "$@" >/dev/null
  sleep 6
  xcrun simctl io $D screenshot $OUTD/$name.png >/dev/null 2>&1
  python3 -c "
from PIL import Image; im=Image.open('$OUTD/$name.png'); w,h=im.size
(im if w > h else im.crop((0,int(h*0.219),w,int(h*0.781)))).save('$OUTD/$name.png')"
  echo $name
}
shot pads-full-t1        0 YES NO  -page song
shot pads-full-t5-up     0 YES NO  -page song -demo-track 5
shot pads-full-shut      0 NO  NO  -page song
shot pads-half-t1        1 YES NO  -page song
shot pads-half-t6        1 YES NO  -page song -demo-track 6
shot pads-max            2 YES NO  -page song
shot pads-full-env-rail  0 YES YES -page song -sound-panel ENV
shot pads-half-env-keys  1 YES NO  -page song -sound-panel ENV
shot sounds-beside-env   1 YES YES -page song -sound-panel ENV -presets-panel
shot sounds-alone        0 YES NO  -page song -presets-panel
shot timeline-full       0 YES NO  -page song -song-timeline
shot timeline-half       1 YES NO  -page song -song-timeline
shot timeline-half-t4    1 YES NO  -page song -song-timeline -demo-track 4
shot mix                 1 YES NO  -page mixer
shot mix-env             1 YES YES -page mixer -sound-panel ENV
