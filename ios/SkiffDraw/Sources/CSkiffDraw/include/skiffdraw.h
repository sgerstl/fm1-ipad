/* SPDX-License-Identifier: GPL-3.0-only */
/* SkiffDraw (spike, decision 45): Skiff-Lupe 2.5.1's own UI drawing code (firmware/src/ui*.c, gfx.c) built for the
 * app, on Skiff's host-test stubs (tests/ui_test.c: the display a 240 x 240 RGB565 buffer). The app keeps a mirror of
 * the firmware state the drawing reads (song.g, each track's p[], the selected track, the page, the theme, the
 * levels and the scope) and asks for a frame. Not thread-safe: one caller (the main actor). */
#ifndef SKIFFDRAW_H
#define SKIFFDRAW_H
#include <stdint.h>

#define SKD_W 240
#define SKD_H 240

/* power-on state (ui_test.c ui_power_on: the default song, six tracks as a new unit has them, SKIFF theme) */
void skd_reset(void);

/* the mirror */
int skd_global_count(void);                         /* G_COUNT */
int skd_track_param_count(void);                    /* P_COUNT */
int skd_track_count(void);                          /* NTRK */
void skd_set_global(int id, int value);             /* song.g[id] */
int skd_get_global(int id);
void skd_set_track_param(int track, int id, int value);   /* trk[track].p[id] (raw, as the firmware stores it) */
int skd_get_track_param(int track, int id);
void skd_set_engine(int track, int engine);         /* the track's engine (set_engine_of, as a sound load does) */
void skd_select_track(int track);                   /* song.sel */
void skd_set_playing(int on);
void skd_set_playhead(int track, int step);        /* trk[track].seq_idx: the header's bar.beat reads the selected track's */
void skd_set_bar_step(int step);                     /* seq.c clk_step (0..15, the bar's 1/16), clk_pos 0: the header's metronome */
void skd_set_palette(int p);                        /* 0 SKIFF 1 HI-CON 2 PAPER 3 CRYPT 4 NEON 5 QUARK (UI_PALETTES order) */
int skd_palette_count(void);
const char *skd_palette_name(int p);
void skd_set_ms(uint32_t ms);                       /* fm1_ms: the clock the animated pictures (the sea) read */

/* pages: PAGES[] in params.c */
int skd_page_count(void);
const char *skd_page_name(int i);
int skd_page_family(int i);
int skd_page_graph(int i);
int skd_page_find(const char *name, int nth);       /* the nth (0-based) page of that name; -1 none */
void skd_goto_page(int i);                          /* ui.page = i, as the editor's SCREEN_GOTO lands */
void skd_goto_home(int scope);                      /* HOME; scope 1: HOME's scope (ui.home_scope) */

/* the screen link's live data */
void skd_set_scope(const uint8_t *points, int n);   /* SCOPE (93): ED_OSC_N (120) points 1..127, 64 the centre */
void skd_set_meters(const uint8_t *levels, int n);  /* METER (92): each track 0..127 */

/* one frame: the whole screen (header, cards, panel, foot) as the FM-1 draws it, RGBA8888 (240 * 240 * 4 bytes) */
void skd_render_rgba(uint8_t *out);
/* the same, raw RGB565 as the panel takes it (host order) */
void skd_render_565(uint16_t *out);

/* spike checks: SCOPE as the firmware would send it from a given ring (editor.c ed_osc_reply), for the round trip */
int skd_scope_from_ring(const int16_t *ring, int n, uint8_t *out120);
void skd_set_scope_ring(const int16_t *ring, int n); /* the raw ring, as audio.c fills it (the reference picture) */
uint32_t skd_draw_cost_us(void);                    /* the last skd_render's time */
#endif
