# FM-1 ↔ iPad protocol (v0, not implemented)

The full v0 sketch is in my vault's interaction spec (`Projects/Dev/fm1-ipad/interaction-spec.md`, "Protocol"). The short version:

- **Framing:** `F0 7D 'F' 'I' 01 <type> <seq> <payload> <checksum> F7`. It reuses FM1 Open's packing and checksum from `firmware/app/transfer.c`, under its own `'F' 'I'` tag so it never collides with the workbench's `'F' 'M'`.
- **Requests** (`hello`, `snapshot`, `select`, `set step`, `block …`, `queue`) get a reply, one at a time, with retries.
- **Events** (`selection`, `step`, `param`, `transport`, `position`, `block playing`, `heartbeat`) are sent without waiting for a reply. They carry a sequence number, and a gap triggers a fresh snapshot.
- **Rate:** at most 30 events a second per kind; latest value wins.

The plan: keep the encoder and decoder as plain C here, compiled into the firmware and also natively on the Mac for tests against the Swift side.
