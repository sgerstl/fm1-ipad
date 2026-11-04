/* SPDX-License-Identifier: GPL-3.0-only
 * skiff-sim's device: Skiff's firmware as its browser build runs it (web/emu/felucca_web.c, copied by build.sh into
 * felucca_sim.c with the editor switched on), plus what the browser build leaves out: USB MIDI in and out, the
 * editor's SysEx (editor.c, unchanged) and MIDI OUT (clock, Start / Stop, the tracks' notes). One translation unit,
 * kept apart from the Mac's headers; sim_main.c drives it through the functions at the end, from one thread. */
#include "felucca_sim.c"

/* ------------------------------------------------------ to the host --- */
typedef void (*sim_out_fn)(const uint8_t *bytes, uint32_t n);
static sim_out_fn sim_out;
static uint8_t sx_acc[8192];                            /* a SysEx reply, sent whole */
static uint32_t sx_n;

static void sim_emit(uint32_t pkt)
{
    static const uint8_t LEN[16] = {0, 0, 2, 3, 3, 1, 2, 3, 3, 3, 3, 3, 2, 2, 3, 1};   /* bytes by CIN */
    uint32_t cin = pkt & 15u, n = LEN[cin], i;
    uint8_t b[3];
    for (i = 0; i < n; i++)
        b[i] = (uint8_t)(pkt >> (8u * (i + 1u)));
    if (cin >= 4u && cin <= 7u && (cin != 5u || b[0] == 0xF7u || sx_n)) {
        for (i = 0; i < n && sx_n < sizeof sx_acc; i++)
            sx_acc[sx_n++] = b[i];
        if (b[n - 1u] == 0xF7u) {
            if (sim_out)
                sim_out(sx_acc, sx_n);
            sx_n = 0;
        }
        return;
    }
    if (n && sim_out)
        sim_out(b, n);
}

/* the editor's SysEx first, never split by notes (as usb.c ep1_tx); then the MIDI OUT events due by mo.now */
static void sim_drain(void)
{
    uint8_t p[64];
    uint32_t n, i;
    while (so_r != so_w)
        sim_emit(sx_out_q[so_r++ % SXQ]);
    if (sx_busy || sx_n)
        return;
    while ((n = mo_take(p, sizeof p, mo.now)) != 0u)
        for (i = 0; i < n; i += 4u)
            sim_emit((uint32_t)p[i] | (uint32_t)p[i + 1u] << 8 | (uint32_t)p[i + 2u] << 16 | (uint32_t)p[i + 3u] << 24);
}

/* ----------------------------------------------------- from the host --- */
/* a MIDI byte stream into USB-MIDI event packets, as the host's USB driver makes them, then usb.c midi_in_event */
static struct { uint8_t in_sx, n, need, b[3]; } rx;

static void rx_pkt(uint32_t cin, const uint8_t *b, uint32_t n)
{
    uint32_t pkt = cin, i;
    for (i = 0; i < n; i++)
        pkt |= (uint32_t)b[i] << (8u * (i + 1u));
    midi_in_event(pkt);
}

static void rx_byte(uint8_t c)
{
    if (c >= 0xF8u) {                                   /* realtime: anywhere, one byte */
        rx_pkt(0xFu, &c, 1);
        return;
    }
    if (c == 0xF0u) {
        rx.in_sx = 1;
        rx.n = 0;
    }
    if (rx.in_sx) {
        rx.b[rx.n++] = c;
        if (c == 0xF7u) {                               /* the end: CIN 5, 6 or 7 by the bytes left */
            rx_pkt(4u + rx.n, rx.b, rx.n);
            rx.in_sx = 0;
            rx.n = 0;
        } else if (rx.n == 3u) {
            rx_pkt(4u, rx.b, 3);
            rx.n = 0;
        }
        return;
    }
    if (c & 0x80u) {                                    /* a channel message (no running status from Jib) */
        uint32_t hi = c >> 4;
        rx.n = 0;
        if (c >= 0xF1u && c != 0xF2u)                   /* other system common: not taken by the firmware */
            return;
        rx.b[rx.n++] = c;
        rx.need = hi == 0xCu || hi == 0xDu ? 2u : 3u;
        return;
    }
    if (!rx.n)
        return;
    rx.b[rx.n++] = c;
    if (rx.n == rx.need) {
        rx_pkt(rx.b[0] == 0xF2u ? 3u : rx.b[0] >> 4, rx.b, rx.n);
        rx.n = 0;
    }
}

/* ------------------------------------------------- for sim_main.c --- */
void sim_set_output(sim_out_fn f) { sim_out = f; }
uint8_t *sim_nor(void) { return nor; }
uint32_t sim_nor_size(void) { return sizeof nor; }

/* power on (the NOR loaded or erased first), with a host attached: usb.c's MIDI OUT queues only then */
void sim_boot(void)
{
    web_boot();
    usb.up = 1;
    usb.config = 1;
}

void sim_midi_in(const uint8_t *b, uint32_t n)
{
    uint32_t i;
    for (i = 0; i < n; i++)
        rx_byte(b[i]);
}

/* one millisecond: the device (audio, sequencer, UI), then main.c's ed_service once its loop runs, then the host */
void sim_step_ms(void)
{
    web_ms();
    mo.now = web_ticks;                                 /* (TIMER5's tick on the unit) */
    if (web_booted && !web_boot_ms)
        ed_service();
    sim_drain();
}

uint32_t sim_now_ms(void) { return fm1_ms; }
uint32_t sim_playing(void) { return song.playing; }
const char *sim_version(void) { return FELUCCA_VERSION; }
uint32_t sim_out_drops(void) { return mo.drops; }

/* the screen as a binary PPM (240 x 240) */
int sim_screen_ppm(const char *path)
{
    static uint8_t px[240 * 240 * 3];
    uint32_t i;
    FILE *f;
    for (i = 0; i < 240u * 240u; i++) {
        const uint8_t *b = (const uint8_t *)&web_fb[i];   /* high byte first, as the panel takes it */
        uint32_t v = (uint32_t)b[0] << 8 | b[1];
        px[3u * i] = (uint8_t)(((v >> 11) & 31u) * 255u / 31u);
        px[3u * i + 1u] = (uint8_t)(((v >> 5) & 63u) * 255u / 63u);
        px[3u * i + 2u] = (uint8_t)((v & 31u) * 255u / 31u);
    }
    if (!(f = fopen(path, "wb")))
        return -1;
    fprintf(f, "P6\n240 240\n255\n");
    fwrite(px, 1, sizeof px, f);
    fclose(f);
    return 0;
}

/* the panel, by printed label, for a quick press from the console: -1 when the name is not a button */
int sim_press(const char *name, uint32_t down)
{
    static const char *const NAMES[NB] = {"FX", "SCL", "ENV", "LFO", "EDIT", "GLO", "HOME", "SAVE", "ARP", "SEQ",
                                          "PLAY", "REC", "OCT-", "OCT+"};       /* panel.c's B_* order */
    uint32_t b;
    for (b = 0; b < NB; b++)
        if (!strcmp(name, NAMES[b])) {
            web_buttons(down ? web_btn_labels | 1u << b : web_btn_labels & ~(1u << b));
            return 0;
        }
    return -1;
}
