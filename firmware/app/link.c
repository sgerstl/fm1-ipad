/* SPDX-License-Identifier: GPL-3.0-only WITH GPL-3.0-linking-exception */
#include "instrument.h"
#include "link.h"
#include "version.h"
#include <string.h>

/* fm1-ipad link: F0 7D 'F' 'I' 01 type seq packed checksum F7.
 * Packing and checksum match transfer.c: an LSB-first stream of 8-bit bytes in
 * 7-bit MIDI data, and the sum from 7D through checksum is zero modulo 128.
 * Requests get one reply each (type bit 6, same seq). Events carry one shared
 * counter and go only to the port that sent hello. Every frame fits the SDK's
 * 128-byte outgoing queue. See protocol/README.md for the message layouts.
 */
#ifdef FM1_HOST_TEST
#include <stdatomic.h>
#define LINK_WORD _Atomic(unsigned)
#else
#define LINK_WORD volatile unsigned
#endif
enum {
    LINK_VERSION = 1,
    LINK_HELLO = 0x01, LINK_SNAPSHOT = 0x02, LINK_SELECT = 0x03, LINK_REPLY = 0x40,
    LINK_SELECTION = 0x20, LINK_HEARTBEAT = 0x21, LINK_STEPS = 0x22,
    LINK_OK = 0, LINK_BAD = 1, LINK_BUSY = 2, LINK_NO_SESSION = 3,
    LINK_NONE = 255, LINK_PAYLOAD = 104,
    LINK_CHUNK = 16, LINK_CHUNKS = GROOVE_TRACKS * GROOVE_STEPS / LINK_CHUNK, LINK_CHUNKS_PER_POLL = 4,
    LINK_SLOTS = 4, LINK_REQUEST_BYTES = 32,
    LINK_SELECTION_MS = 33, LINK_HEARTBEAT_MS = 1000, LINK_REPLY_MS = 2000
};
/* Requests cross from the routing task through a single-producer ring. */
static struct { uint8_t bytes[LINK_REQUEST_BYTES], length, source; } inbox[LINK_SLOTS];
static LINK_WORD inbox_write, inbox_read;
static uint8_t reply[128];
static unsigned reply_length, reply_port;
static uint32_t reply_ms, selection_ms, heartbeat_ms;
static unsigned port = LINK_NONE, event_seq, snapshot_next = LINK_CHUNKS, selection_dirty, shown[3];
static void barrier(void)
{
#ifndef FM1_HOST_TEST
    __asm__ volatile("csync" ::: "memory");
#endif
}
static unsigned frame(uint8_t out[128], unsigned type, unsigned seq, const uint8_t *data, unsigned n)
{
    unsigned at = 0, value = 0, bits = 0, sum = 0;
    out[at++] = 0xf0; out[at++] = 0x7d; out[at++] = 'F'; out[at++] = 'I'; out[at++] = 1;
    out[at++] = (uint8_t)type; out[at++] = (uint8_t)(seq & 127U);
    for (unsigned i = 0; i < n; ++i) {
        value |= (unsigned)data[i] << bits;
        bits += 8;
        while (bits >= 7) {
            out[at++] = value & 127U;
            value >>= 7;
            bits -= 7;
        }
    }
    if (bits)
        out[at++] = value & 127U;
    for (unsigned i = 1; i < at; ++i)
        sum += out[i];
    out[at++] = (uint8_t)((0U - sum) & 127U);
    out[at++] = 0xf7;
    return at;
}
/* 0 queued, -2 output full, -1 offline. Only a queued event uses a number. */
static int event(unsigned type, const uint8_t *data, unsigned n)
{
    uint8_t out[128];
    if (n > LINK_PAYLOAD) return -1;
    int r = fm1_midi_send_port(port, out, frame(out, type, event_seq, data, n));
    if (!r) event_seq = (event_seq + 1) & 127U;
    return r;
}
static void end_session(void)
{
    port = LINK_NONE;
    snapshot_next = LINK_CHUNKS;
}
void groove_link_init(void)
{
    end_session();
    reply_length = 0;
    inbox_read = inbox_write;
}
void groove_link_sysex(const uint8_t *m, size_t n)
{
    unsigned w = inbox_write;
    if (n > LINK_REQUEST_BYTES || w - inbox_read >= LINK_SLOTS) return;
    unsigned at = w % LINK_SLOTS;
    memcpy(inbox[at].bytes, m, n);
    inbox[at].length = (uint8_t)n;
    inbox[at].source = (uint8_t)fm1_midi_input_source();
    barrier();
    inbox_write = w + 1;
    fm1_control_request();
}
static void request(const uint8_t *m, unsigned n, unsigned source)
{
    if (n < 9 || source >= 3 || m[0] != 0xf0 || m[n - 1] != 0xf7 || m[1] != 0x7d || m[2] != 'F' || m[3] != 'I' || m[4] != 1)
        return;
    unsigned sum = 0;
    for (unsigned i = 1; i + 1 < n; ++i) {
        if (m[i] >= 128) return;
        sum += m[i];
    }
    if ((sum & 127U) || m[5] >= LINK_REPLY) return;
    uint8_t data[LINK_REQUEST_BYTES], out[40];
    unsigned bytes = 0, value = 0, bits = 0, count = 1, status = LINK_OK;
    for (unsigned i = 7; i + 2 < n; ++i) {
        value |= (unsigned)m[i] << bits;
        bits += 7;
        if (bits >= 8) {
            data[bytes++] = (uint8_t)value;
            value >>= 8;
            bits -= 8;
        }
    }
    if (value || bits >= 7) return;
    unsigned type = m[5], current[3];
    groove_screen_selection(current);
    if (type == LINK_HELLO) {
        if (bytes != 1 || !data[0]) status = LINK_BAD;
        else {
            port = source;
            event_seq = 0;
            snapshot_next = LINK_CHUNKS;
            selection_dirty = 1;
            heartbeat_ms = fm1_millis();
            out[count++] = LINK_VERSION;
            strncpy((char *)out + count, FM1_RELEASE_VERSION, 4);
            count += 4;
            out[count++] = GROOVE_TRACKS;
            out[count++] = GROOVE_STEPS;
        }
    } else if (source != port) status = LINK_NO_SESSION;
    else if (type == LINK_SNAPSHOT) {
        if (bytes) status = LINK_BAD;
        else {
            struct groove_view v = {0};
            groove_get_view(current[0], current[1], &v);
            out[count++] = (uint8_t)v.tempo;
            out[count++] = (uint8_t)(v.tempo >> 8);
            out[count++] = v.playing ? 1 : 0;
            out[count++] = (uint8_t)current[0];
            out[count++] = (uint8_t)current[1];
            for (unsigned t = 0; t < GROOVE_TRACKS; ++t) {
                groove_get_view(t, 0, &v);
                out[count++] = (uint8_t)groove_source_type(t);
                out[count++] = (uint8_t)groove_sequence_length(t);
                out[count++] = (uint8_t)groove_track_role(t);
                out[count++] = v.muted ? 1 : 0;
            }
            snapshot_next = 0;
        }
    } else if (type == LINK_SELECT) {
        if (bytes != 2 || data[0] >= GROOVE_TRACKS || (data[1] >= GROOVE_STEPS && data[1] != GROOVE_LINK_TRACK_ONLY))
            status = LINK_BAD;
        else {
            int r = groove_screen_select(data[0], data[1]);
            status = r == -1 ? LINK_BAD : r ? LINK_BUSY : LINK_OK;
        }
    } else status = LINK_BAD;
    if (status != LINK_OK) count = 1;
    out[0] = (uint8_t)status;
    reply_length = frame(reply, type | LINK_REPLY, m[6], out, count);
    reply_port = source;
    reply_ms = fm1_millis();
}
static void send_chunks(void)
{
    for (unsigned sent = 0; snapshot_next < LINK_CHUNKS && sent < LINK_CHUNKS_PER_POLL; ++sent) {
        unsigned track = snapshot_next / (GROOVE_STEPS / LINK_CHUNK), first = snapshot_next % (GROOVE_STEPS / LINK_CHUNK) * LINK_CHUNK;
        struct groove_step cells[LINK_CHUNK];
        uint8_t out[3 + LINK_CHUNK * 4] = {(uint8_t)track, (uint8_t)first, LINK_CHUNK};
        groove_sequence_read(track, first, cells, LINK_CHUNK);
        for (unsigned i = 0; i < LINK_CHUNK; ++i) {
            uint8_t *cell = out + 3 + i * 4;
            cell[0] = cells[i].note;
            cell[1] = cells[i].velocity;
            cell[2] = (uint8_t)cells[i].drums;
            cell[3] = (uint8_t)(cells[i].drums >> 8);
        }
        int r = event(LINK_STEPS, out, sizeof out);
        if (r == -1) snapshot_next = LINK_CHUNKS;
        if (r) return;
        ++snapshot_next;
    }
}
void groove_link_poll(void)
{
    uint32_t now = fm1_millis();
    /* A reply is retried until queued. Later requests and events wait behind
     * it, so a hello or snapshot reply always precedes its events. */
    if (reply_length) {
        int r = fm1_midi_send_port(reply_port, reply, reply_length);
        if (r == -2 && now - reply_ms < LINK_REPLY_MS) return;
        reply_length = 0;
    }
    while (!reply_length && inbox_read != inbox_write) {
        barrier();
        unsigned at = inbox_read % LINK_SLOTS;
        request(inbox[at].bytes, inbox[at].length, inbox[at].source);
        barrier();
        inbox_read = inbox_read + 1;
        if (reply_length && fm1_midi_send_port(reply_port, reply, reply_length) != -2) reply_length = 0;
    }
    if (reply_length) return;
    if (port != LINK_NONE && !(fm1_midi_ready_ports() & (1U << port))) end_session();
    if (port == LINK_NONE) return;
    unsigned current[3];
    groove_screen_selection(current);
    if (memcmp(current, shown, sizeof shown)) selection_dirty = 1;
    if (selection_dirty && now - selection_ms >= LINK_SELECTION_MS) {
        uint8_t out[4] = {(uint8_t)current[0], (uint8_t)current[1], (uint8_t)groove_sequence_length(current[0]), (uint8_t)current[2]};
        if (!event(LINK_SELECTION, out, sizeof out)) {
            memcpy(shown, current, sizeof shown);
            selection_dirty = 0;
            selection_ms = now;
        }
    }
    if (now - heartbeat_ms >= LINK_HEARTBEAT_MS) {
        struct groove_view v = {0};
        groove_get_view(current[0], current[1], &v);
        uint8_t out[5] = {(uint8_t)now, (uint8_t)(now >> 8), (uint8_t)(now >> 16), (uint8_t)(now >> 24), v.playing ? 1 : 0};
        if (event(LINK_HEARTBEAT, out, sizeof out) != -2) heartbeat_ms = now;
    }
    send_chunks();
}
