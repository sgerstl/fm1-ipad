/* SPDX-License-Identifier: GPL-3.0-only */
/* SkiffDraw (spike, decision 45): see include/skiffdraw.h. One translation unit, as Skiff's own host tests are built:
 * tests/ui_test.c brings hostsim.c (the sound code, for the state structs the UI reads), the HAL stubs (the panel a
 * 240 x 240 buffer) and firmware/src/ui*.c, gfx.c. The vendored tree is Skiff-Lupe 2.5.1 at 737e3fb
 * (skiff/VERSION), untouched; build/gen's headers are Skiff's own generators' output. */
#define UI_TEST_NO_MAIN 1
#ifndef FELUCCA_VERSION
#define FELUCCA_VERSION "v2.5.1"
#endif
#include "skiff/tests/ui_test.c"
#include <sys/time.h>
#include "skiffdraw.h"

static uint32_t skd_cost;
static int skd_ready;

static void skd_need(void) { if (!skd_ready) skd_reset(); }

void skd_reset(void)
{
    ui_power_on();
    memset(scope_buf, 0, sizeof scope_buf);
    scope_w = 0;
    memset(&scd, 0, sizeof scd);
    skd_ready = 1;
}

int skd_global_count(void) { return G_COUNT; }
int skd_track_param_count(void) { return P_COUNT; }
int skd_track_count(void) { return NTRK; }
void skd_set_global(int id, int v) { skd_need(); if (id >= 0 && id < G_COUNT) song.g[id] = (int16_t)v; ui.force = 1; }
int skd_get_global(int id) { skd_need(); return id >= 0 && id < G_COUNT ? song.g[id] : 0; }
void skd_set_track_param(int t, int id, int v)
{
    skd_need();
    if (t >= 0 && t < (int)NTRK && id >= 0 && id < P_COUNT) trk[t].p[id] = (int16_t)v;
    ui.force = 1;
}
int skd_get_track_param(int t, int id) { skd_need(); return t >= 0 && t < (int)NTRK && id >= 0 && id < P_COUNT ? trk[t].p[id] : 0; }
void skd_set_engine(int t, int e)
{
    skd_need();
    if (t < 0 || t >= (int)NTRK || e < 0 || e >= (int)NENGINES) return;
    set_engine_of(&trk[t], (uint32_t)e);
    trk[t].engine = trk[t].eng_req;
    ui.force = 1;
}
void skd_select_track(int t) { skd_need(); if (t >= 0 && t < (int)NTRK) sel_set((uint32_t)t); ui.force = 1; }
void skd_set_playing(int on) { skd_need(); song.playing = (uint8_t)(on != 0); }
void skd_set_playhead(int t, int step) { skd_need(); if (t >= 0 && t < (int)NTRK) trk[t].seq_idx = (uint8_t)step; }
void skd_set_bar_step(int step) { skd_need(); clk_pos = 0; clk_step = (uint32_t)step & 15u; }
void skd_set_palette(int p) { skd_need(); if (p >= 0 && p < (int)UI_NPALETTES) { settings.palette = (uint8_t)p; palette_set((uint32_t)p); } ui.force = 1; }
int skd_palette_count(void) { return (int)UI_NPALETTES; }
const char *skd_palette_name(int p) { return p >= 0 && p < (int)UI_NPALETTES ? UI_PALETTES[p].name : ""; }
void skd_set_ms(uint32_t ms) { fm1_ms = ms; }

int skd_page_count(void) { return (int)NPAGES; }
const char *skd_page_name(int i) { return i >= 0 && i < (int)NPAGES ? PAGES[i].title : ""; }
int skd_page_family(int i) { return i >= 0 && i < (int)NPAGES ? PAGES[i].fam : -1; }
int skd_page_graph(int i) { return i >= 0 && i < (int)NPAGES ? PAGES[i].graph : -1; }
int skd_page_find(const char *name, int nth)
{
    uint32_t i;
    for (i = 0; i < NPAGES; i++)
        if (!strcmp(PAGES[i].title, name) && nth-- == 0) return (int)i;
    return -1;
}
void skd_goto_page(int i)
{
    skd_need();
    if (i < 0 || i >= (int)NPAGES) return;
    ui.home = 0;
    ui.home_scope = 0;
    ui.page = (uint8_t)i;
    page_entered();
    ui.hot_t = 0;                                   /* no card lit: the page at rest */
    ui.force = 1;
}
void skd_goto_home(int scope)
{
    skd_need();
    ui.home = 1;
    ui.home_scope = (uint8_t)(scope != 0);
    ui.hot_t = 0;
    ui.force = 1;
}

/* SCOPE's 120 points back into the ring graph_scope reads (ui_scope.c scope_take): each point twice (ed_osc_reply kept
 * the larger of each pair), scaled by K; one sample of -63 K before the trace makes scope_take's peak 63 K, so the
 * picture's scale (y = cy - s * a / peak) is the firmware's own: (v - 64) K * a / 63 K = s * a / peak. The trace starts
 * at the rising zero crossing, as the firmware's did (ring[0] < 0 <= ring[1]). */
#define SKD_K 400
void skd_set_scope(const uint8_t *pts, int n)
{
    int i;
    skd_need();
    memset(scope_buf, 0, sizeof scope_buf);
    scope_buf[0] = (int16_t)(-63 * SKD_K);
    for (i = 0; i < n && 1 + 2 * i + 1 < (int)SCOPE_N; i++) {
        int32_t s = ((int32_t)pts[i] - 64) * SKD_K;
        if (i == 0 && s < 0) s = 0;                 /* (the crossing: the first point at or above the centre) */
        scope_buf[1 + 2 * i] = scope_buf[2 + 2 * i] = (int16_t)s;
    }
    scope_w = 0;
}
void skd_set_scope_ring(const int16_t *ring, int n)
{
    skd_need();
    memset(scope_buf, 0, sizeof scope_buf);
    memcpy(scope_buf, ring, (size_t)(n < (int)SCOPE_N ? n : (int)SCOPE_N) * sizeof *ring);
    scope_w = 0;
}
/* editor.c ed_osc_reply (Skiff-Lupe 2.5.1, 737e3fb), copied: editor.c isn't part of the UI's host build */
int skd_scope_from_ring(const int16_t *ring, int n, uint8_t *out)
{
    int32_t peak, s, t;
    uint32_t i, trig;
    skd_set_scope_ring(ring, n);
    trig = scope_take(&peak);
    for (i = 0; i < SCOPE_SPAN / 2u; i++) {
        s = scope_snap[trig + 2u * i];
        t = scope_snap[trig + 2u * i + 1u];
        if ((t < 0 ? -t : t) > (s < 0 ? -s : s)) s = t;
        out[i] = (uint8_t)clamp(64 + s * 63 / peak, 1, 127);
    }
    return (int)(SCOPE_SPAN / 2u);
}

/* METER's 0..127 (editor.c ed_met_lvl: 8 log2(|sample|), 48..128 over 0..127) back to a peak for peak_take: the sea
 * (ui_graph.c scope_levels) and the MIXER's meters read trk[].peak through it */
void skd_set_meters(const uint8_t *lv, int n)
{
    int k;
    skd_need();
    for (k = 0; k < n && k < (int)NTRK; k++) {
        int32_t v = 48 + (int32_t)lv[k] * 80 / 127, lg = v / 8, fr = v % 8;
        trk[k].peak = lv[k] ? (int32_t)((1L << lg) + ((1L << lg) * fr >> 3)) : 0;
    }
}

void skd_render_565(uint16_t *out)
{
    struct timeval a, b;
    uint32_t i;
    skd_need();
    gettimeofday(&a, 0);
    memset(host_screen, 0, sizeof host_screen);
    ui.force = 1;
    mt.frame = ui.frame + 7u;
    ui_draw();
    gettimeofday(&b, 0);
    skd_cost = (uint32_t)((b.tv_sec - a.tv_sec) * 1000000 + (b.tv_usec - a.tv_usec));
    for (i = 0; i < 240u * 240u; i++) out[i] = swap16(host_screen[i]);
}
void skd_render_rgba(uint8_t *out)
{
    static uint16_t px[240u * 240u];
    uint32_t i;
    skd_render_565(px);
    for (i = 0; i < 240u * 240u; i++) {             /* as tests/ui_render.c write_ppm expands it */
        uint16_t c = px[i];
        out[4u * i] = (uint8_t)((c >> 11) * 255u / 31u);
        out[4u * i + 1u] = (uint8_t)(((c >> 5) & 63u) * 255u / 63u);
        out[4u * i + 2u] = (uint8_t)((c & 31u) * 255u / 31u);
        out[4u * i + 3u] = 255u;
    }
}
uint32_t skd_draw_cost_us(void) { return skd_cost; }
