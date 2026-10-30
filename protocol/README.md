# FM-1 ↔ iPad protocol

The full design lives in my vault's interaction spec (`Projects/Dev/fm1-ipad/interaction-spec.md`, "Protocol"). This file is the exact byte layout of what is built. The firmware side is `firmware/app/link.c`.

**Status:** slice 1 (connect + select a step). Protocol version 1.

## Framing

```
F0 7D 46 49 01 <type> <seq> <packed payload ...> <checksum> F7
```

| Byte | Meaning |
|---|---|
| `7D` | MIDI ID for non-commercial use, as FM1 Open and the workbench use |
| `46 49` | `'F' 'I'`, which keeps these messages apart from the workbench's `'F' 'M'` |
| `01` | Framing version |
| `type` | Message type, below. Replies set bit 6 (`0x40`) |
| `seq` | 0–127. In a request it's the iPad's choice, and the reply echoes it. In an event it's the FM-1's event counter |
| payload | 8-bit bytes packed into 7-bit MIDI data, LSB first. Same packing as `firmware/app/transfer.c` |
| `checksum` | Makes the sum of every byte from `7D` through the checksum zero modulo 128 |

Packing: keep a bit accumulator. Append each payload byte's 8 bits above the bits already held. Whenever 7 or more bits are held, emit the low 7 as one MIDI byte. At the end, emit any leftover bits as one more byte. Unpacking reverses this and requires the leftover bits to be zero.

Every message is at most 128 bytes, which is the limit of the FM-1's outgoing MIDI queue.

## Session

- The FM-1 accepts these messages on USB and Bluetooth MIDI.
- `hello` binds the session to the port it arrived on, and resets the event counter to 0. Events go only to that port.
- The session ends when that port goes away (cable unplugged, Bluetooth link lost). Sending `hello` again starts a new one.
- **Events** are sent without waiting for a reply. All event types share one counter. If the iPad sees a gap, it should request a new snapshot.
- **Requests** get exactly one reply. If no reply arrives within 500 ms, send the same request again. Every slice 1 request is safe to repeat.

## Requests (iPad → FM-1) and replies

Every reply payload starts with a status byte:

| Status | Meaning |
|---|---|
| 0 | OK |
| 1 | Bad request (wrong length or out-of-range value) |
| 2 | Busy: the FM-1 can't do it right now. For example, a step select while the FM-1 is on a page that isn't a step page, or while a key is held |
| 3 | No session: send `hello` first |

### `0x01` hello

- **Request:** `version` (1 byte, currently 1).
- **Reply `0x41`:** `status`, `version`, `release` (4 bytes of ASCII, zero-padded, for example `V14\0`), `tracks` (8), `steps` (64).

### `0x02` snapshot

- **Request:** empty.
- **Reply `0x42`:** `status`, `tempo` (u16 LE), `playing` (0/1), `track`, `step` (the current selection), then 8 track records of 4 bytes each: `type`, `length`, `role`, `muted`.
  - `type`: 0 DX7, 1 303, 2 808, 3 PSG, 4 pluck, 5 sampler.
  - `length`: 16, 32, 48 or 64.
  - `role`: 0 normal, 1 play, 2 off.
- **Then 32 `steps` events** follow (`0x22`, below), covering all 8 tracks × 64 steps. The snapshot is complete when all 32 have arrived with no gap in the event counter.

### `0x03` select

- **Request:** `track` (0–7), `step` (0–63, or `0x7F` for the track only).
- **Reply `0x43`:** `status`.
- **The iPad moves its highlight only on the `selection` event that follows**, never on the reply. A select the FM-1 refused never shows as selected.
- Selecting a step switches the FM-1 to its step page, the same as tapping a step in the browser workbench. That works from the overview and the step page. On any other page, or while a key is held, the reply is busy (2). Selecting only the track works from any page.

## Events (FM-1 → iPad)

### `0x20` selection

`track`, `step`, `length` (the track's sequence length), `view` (the FM-1's current screen page; firmware-internal, for debugging).

Sent when the track, step or page changes, at most 30 times a second, latest value wins. One is also sent right after `hello`.

### `0x21` heartbeat

`uptime` (u32 LE, milliseconds, wraps), `flags` (bit 0 playing). Once a second. Three missed heartbeats mean disconnected.

### `0x22` steps

`track`, `first` (step index), `count` (16), then `count` cells of 4 bytes each: `note`, `velocity`, `drums` (u16 LE). The cell layout is `struct groove_step` in `firmware/app/instrument.h`:
- **Melodic tracks:** a step is on when `velocity` isn't 0. In `drums`, bits 0–4 are the chord, 5–8 gate, 9–11 probability, bit 12 tie, bit 13 alternate tuning.
- **Pad tracks (808 drums and the sampler):** a step is on when `drums` isn't 0. `drums` is the pad mask, and `note` holds probability.

## Not in slice 1

Editing steps, transport, blocks, song playback, sounds and samples. Their message types are reserved in the vault spec.
