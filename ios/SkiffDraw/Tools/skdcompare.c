/* SPDX-License-Identifier: GPL-3.0-only */
/* skdcompare (spike, decision 45): SkiffDraw's frames at the settings of design/boards/fm1-screens (fm1shots.c), set
 * the way the app sets them: skd_reset, then the mirror (song.g, the track's sends, transport) and the page, through
 * skiffdraw.h only. The G_/P_ ids are the firmware's, as the link's DESC numbers them. Writes OUT/<name>.ppm.
 *   cc -O1 -w -Iios/SkiffDraw/Sources/CSkiffDraw/include -Iios/SkiffDraw/Sources/CSkiffDraw \
 *      ios/SkiffDraw/Tools/skdcompare.c -lm -o skdcompare && ./skdcompare OUT */
#include "skiffdraw.c"

typedef struct { const char *name, *page; int nth; int16_t g[8][2]; int ng; int16_t sdly, srev; } shot_t;
#define G2(a, b) {a, b}
static const shot_t SH[] = {
    {"delay_a_default_1-8_fb60_mix90_stereo", "DELAY", 1, {G2(G_DTIME, 1), G2(G_DFDBK, 60), G2(G_DCOLOR, 70), G2(G_DMIX, 90), G2(G_DMODE, DM_STEREO)}, 5, -1, -1},
    {"delay_b_1-4_fb100_mix127_ping", "DELAY", 1, {G2(G_DTIME, 0), G2(G_DFDBK, 100), G2(G_DCOLOR, 70), G2(G_DMIX, 127), G2(G_DMODE, DM_PING)}, 5, -1, -1},
    {"delay_c_1-16_fb30_mix60_mono", "DELAY", 1, {G2(G_DTIME, 2), G2(G_DFDBK, 30), G2(G_DCOLOR, 20), G2(G_DMIX, 60), G2(G_DMODE, DM_MONO)}, 5, -1, -1},
    {"delay_d_2bar_fb110_mix110", "DELAY", 1, {G2(G_DTIME, 8), G2(G_DFDBK, 110), G2(G_DCOLOR, 70), G2(G_DMIX, 110), G2(G_DMODE, DM_STEREO)}, 5, -1, -1},
    {"delay_e_8T_fb80_mix90", "DELAY", 1, {G2(G_DTIME, 4), G2(G_DFDBK, 80), G2(G_DCOLOR, 70), G2(G_DMIX, 90), G2(G_DMODE, DM_STEREO)}, 5, -1, -1},
    {"reverb_a_room_size90_damp60", "REVERB", 1, {G2(G_RTYPE, 0), G2(G_RSIZE, 90), G2(G_RDAMP, 60)}, 3, -1, -1},
    {"reverb_b_room_size15_damp0", "REVERB", 1, {G2(G_RTYPE, 0), G2(G_RSIZE, 15), G2(G_RDAMP, 0)}, 3, -1, -1},
    {"reverb_c_spring_size90_damp60", "REVERB", 1, {G2(G_RTYPE, 1), G2(G_RSIZE, 90), G2(G_RDAMP, 60)}, 3, -1, -1},
    {"reverb_d_hall_size127_damp127", "REVERB", 1, {G2(G_RTYPE, 2), G2(G_RSIZE, 127), G2(G_RDAMP, 127)}, 3, -1, -1},
    {"reverb_e_hall_size40_damp20", "REVERB", 1, {G2(G_RTYPE, 2), G2(G_RSIZE, 40), G2(G_RDAMP, 20)}, 3, -1, -1},
    {"chorus_a_chorus_rate40_depth60_fb0", "CHORUS", 0, {G2(G_CRATE, 40), G2(G_CDEPTH, 60), G2(G_CMODE, 0), G2(G_CFDBK, 0)}, 4, -1, -1},
    {"chorus_b_chorus_rate127_depth127_fb90", "CHORUS", 0, {G2(G_CRATE, 127), G2(G_CDEPTH, 127), G2(G_CMODE, 0), G2(G_CFDBK, 90)}, 4, -1, -1},
    {"chorus_c_chorus_rate0_depth25_fb0", "CHORUS", 0, {G2(G_CRATE, 0), G2(G_CDEPTH, 25), G2(G_CMODE, 0), G2(G_CFDBK, 0)}, 4, -1, -1},
    {"chorus_d_flanger_depth60_fb60", "CHORUS", 0, {G2(G_CRATE, 40), G2(G_CDEPTH, 60), G2(G_CMODE, 1), G2(G_CFDBK, 60)}, 4, -1, -1},
    {"chorus_e_flanger_depth127_fb0", "CHORUS", 0, {G2(G_CRATE, 40), G2(G_CDEPTH, 127), G2(G_CMODE, 1), G2(G_CFDBK, 0)}, 4, -1, -1},
    {"chorus_f_phaser_depth60_fb60", "CHORUS", 0, {G2(G_CRATE, 40), G2(G_CDEPTH, 60), G2(G_CMODE, 2), G2(G_CFDBK, 60)}, 4, -1, -1},
    {"chorus_g_phaser_depth0_fb127", "CHORUS", 0, {G2(G_CRATE, 40), G2(G_CDEPTH, 0), G2(G_CMODE, 2), G2(G_CFDBK, 127)}, 4, -1, -1},
    {"global_a_swing0", "GLOBAL", 0, {G2(G_SWING, 0)}, 1, -1, -1},
    {"global_b_swing50", "GLOBAL", 0, {G2(G_SWING, 50)}, 1, -1, -1},
    {"global_c_swing100", "GLOBAL", 0, {G2(G_SWING, 100)}, 1, -1, -1},
    {"fxdelay_a_send89", "DELAY", 0, {G2(G_DTIME, 1), G2(G_DFDBK, 60), G2(G_DMIX, 90)}, 3, 89, -1},
    {"fxdelay_b_send30", "DELAY", 0, {G2(G_DTIME, 1), G2(G_DFDBK, 60), G2(G_DMIX, 90)}, 3, 30, -1},
    {"fxreverb_a_hall_send70", "REVERB", 0, {G2(G_RTYPE, 2), G2(G_RSIZE, 90), G2(G_RDAMP, 60)}, 3, -1, 70},
    {"fxreverb_b_room_send127", "REVERB", 0, {G2(G_RTYPE, 0), G2(G_RSIZE, 90), G2(G_RDAMP, 60)}, 3, -1, 127},
};

int main(int argc, char **argv)
{
    static uint8_t img[240 * 240 * 4];
    const char *out = argc > 1 ? argv[1] : ".";
    uint32_t i, k;
    for (i = 0; i < sizeof SH / sizeof SH[0]; i++) {
        const shot_t *s = &SH[i];
        char path[512];
        FILE *f;
        skd_reset();
        /* the header as the board's renders have it (ui_render.c state()): playing, 124 BPM, the bar's 3rd beat */
        skd_set_playing(1);
        skd_set_global(G_BPM, 124);
        skd_set_bar_step(8);
        for (k = 0; k < NTRK; k++) skd_set_playhead((int)k, 5);
        if (s->sdly >= 0) skd_set_track_param(0, P_DLY, s->sdly);
        if (s->srev >= 0) skd_set_track_param(0, P_REV, s->srev);
        skd_goto_page(skd_page_find(s->page, s->nth));
        for (k = 0; k < (uint32_t)s->ng; k++) skd_set_global(s->g[k][0], s->g[k][1]);
        skd_render_rgba(img);
        snprintf(path, sizeof path, "%s/%s.ppm", out, s->name);
        f = fopen(path, "wb");
        fprintf(f, "P6\n240 240\n255\n");
        for (k = 0; k < 240u * 240u; k++) fwrite(img + 4 * k, 1, 3, f);
        fclose(f);
        printf("%-40s %4u us\n", s->name, skd_draw_cost_us());
    }
    return 0;
}
