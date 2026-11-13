# The lag after a sound key (Scott, 2026-11-14)

Scott's report: a family key on the phone (FX, ENV…) changes the FM-1 at once, but the phone takes a noticeable
moment.

## What was measured

A trace runs from the intent to the page being published. It starts on `pickPage` or `goHome` and lasts 1.5 s.

- **Swift** (`PhoneCore/LagTrace.swift`): each step with its offset. That covers the screen set (Session's
  optimistic copy, then the FM-1's reply or push) and every area built in that time: its build time in ms, its size,
  and whether it changed and was published. Lines start `lag pickPage …` in LupeLog.
- **Kotlin** (`BridgedLupeCore`): when the intent leaves, when `shell` and `page` arrive and how long each takes to
  decode, and the next display frame after each (Choreographer). Lines start `lag kotlin …`.

Both read CLOCK_MONOTONIC: `DispatchTime` in Swift and `SystemClock.uptimeMillis` on Android. So the two sets of
lines share one timeline.

## On the Mac, FakeSkiff 2.5.1

From `GoHomeAndLagTests.aFamilyKeyPublishesThePageWithinFrames`, which prints them:

| | stopped | playing |
|---|---|---|
| Before: intent → page published | 21.8–22.7 ms | about the same |
| After | 0.8–1.0 ms | 1.2–2.2 ms |

Session puts its optimistic screen in place inside the intent's call: it doesn't wait for the FM-1. So the page's
shape and values are known at once. They come from cells the session already holds, so no read is needed.

What the phone waited for was its own frame. Every area is rebuilt 16 ms after a change, coalesced. Building is quick:
the largest area, the editor (3.2 KB), takes about 1 ms. So `pickPage` and `goHome` now build and publish `shell` and
`page` in the same call (`PhoneCore.publishNow`). `pickRoute` and `pickTile` do the same for `page`. Everything else
keeps the frame's coalescing.

There was nothing to batch: a page change reads no parameters. The engine's descriptors are read only when the
engine changes.

## On the FM-1: still to measure

The Mac's numbers leave out the parts that only the Pixel has: its CPU, the JNI hop, Kotlin decoding, and Compose's
frame. If Scott still sees a moment, the `lag` lines in LupeLog from one key press will show where it goes. Filter
with:

```bash
adb logcat -s LupeLog | grep " lag "
```

- If `lag kotlin … page decoded` is close to `sent`, but the `next frame` line comes late, the time is in Compose.
  That's P2's page screen.
- If `page decoded` itself is late, the time is in Swift, or in the hop between Swift and Kotlin.

That run waits for the main session's go-ahead, because Scott uses the phone too.
