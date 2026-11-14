/* fm1shots: GLO's pages (and FX > DELAY / REVERB) rendered by Skiff 2.5.1's own UI code, through tests/ui_render.c's
 * stubs and scenes, at chosen parameter settings. Writes OUT/ppm/<PALETTE>_<name>.ppm. Scratch tool, not part of Skiff. */

#include "ui_render_lib.c"


typedef struct { const char *name; int scene; int16_t g[8][2]; int ng; int16_t send_dly, send_rev; } shot_t;
#define G2(a, b) {a, b}
static const shot_t SHOTS[] = {
    /* GLO > DELAY: TIME (0 1/4, 1 1/8, 2 1/16, 4 8T, 8 2BAR, 10 1/8D), FEEDBACK 0..120, COLOR, MIX, MODE */
    {"delay_a_default_1-8_fb60_mix90_stereo", S_DLY, {G2(G_DTIME, 1), G2(G_DFDBK, 60), G2(G_DCOLOR, 70), G2(G_DMIX, 90), G2(G_DMODE, DM_STEREO)}, 5, -1, -1},
    {"delay_b_1-4_fb100_mix127_ping", S_DLY, {G2(G_DTIME, 0), G2(G_DFDBK, 100), G2(G_DCOLOR, 70), G2(G_DMIX, 127), G2(G_DMODE, DM_PING)}, 5, -1, -1},
    {"delay_c_1-16_fb30_mix60_mono", S_DLY, {G2(G_DTIME, 2), G2(G_DFDBK, 30), G2(G_DCOLOR, 20), G2(G_DMIX, 60), G2(G_DMODE, DM_MONO)}, 5, -1, -1},
    {"delay_d_2bar_fb110_mix110", S_DLY, {G2(G_DTIME, 8), G2(G_DFDBK, 110), G2(G_DCOLOR, 70), G2(G_DMIX, 110), G2(G_DMODE, DM_STEREO)}, 5, -1, -1},
    {"delay_e_8T_fb80_mix90", S_DLY, {G2(G_DTIME, 4), G2(G_DFDBK, 80), G2(G_DCOLOR, 70), G2(G_DMIX, 90), G2(G_DMODE, DM_STEREO)}, 5, -1, -1},
    /* GLO > REVERB: TYPE 0 ROOM 1 SPRING 2 HALL, SIZE, DAMP */
    {"reverb_a_room_size90_damp60", S_REVERB, {G2(G_RTYPE, 0), G2(G_RSIZE, 90), G2(G_RDAMP, 60)}, 3, -1, -1},
    {"reverb_b_room_size15_damp0", S_REVERB, {G2(G_RTYPE, 0), G2(G_RSIZE, 15), G2(G_RDAMP, 0)}, 3, -1, -1},
    {"reverb_c_spring_size90_damp60", S_REVERB, {G2(G_RTYPE, 1), G2(G_RSIZE, 90), G2(G_RDAMP, 60)}, 3, -1, -1},
    {"reverb_d_hall_size127_damp127", S_REVERB, {G2(G_RTYPE, 2), G2(G_RSIZE, 127), G2(G_RDAMP, 127)}, 3, -1, -1},
    {"reverb_e_hall_size40_damp20", S_REVERB, {G2(G_RTYPE, 2), G2(G_RSIZE, 40), G2(G_RDAMP, 20)}, 3, -1, -1},
    /* GLO > CHORUS: RATE, DEPTH, MODE 0 CHORUS 1 FLANGER 2 PHASER, FEEDBACK */
    {"chorus_a_chorus_rate40_depth60_fb0", S_CHORUS, {G2(G_CRATE, 40), G2(G_CDEPTH, 60), G2(G_CMODE, 0), G2(G_CFDBK, 0)}, 4, -1, -1},
    {"chorus_b_chorus_rate127_depth127_fb90", S_CHORUS, {G2(G_CRATE, 127), G2(G_CDEPTH, 127), G2(G_CMODE, 0), G2(G_CFDBK, 90)}, 4, -1, -1},
    {"chorus_c_chorus_rate0_depth25_fb0", S_CHORUS, {G2(G_CRATE, 0), G2(G_CDEPTH, 25), G2(G_CMODE, 0), G2(G_CFDBK, 0)}, 4, -1, -1},
    {"chorus_d_flanger_depth60_fb60", S_CHORUS, {G2(G_CRATE, 40), G2(G_CDEPTH, 60), G2(G_CMODE, 1), G2(G_CFDBK, 60)}, 4, -1, -1},
    {"chorus_e_flanger_depth127_fb0", S_CHORUS, {G2(G_CRATE, 40), G2(G_CDEPTH, 127), G2(G_CMODE, 1), G2(G_CFDBK, 0)}, 4, -1, -1},
    {"chorus_f_phaser_depth60_fb60", S_CHORUS, {G2(G_CRATE, 40), G2(G_CDEPTH, 60), G2(G_CMODE, 2), G2(G_CFDBK, 60)}, 4, -1, -1},
    {"chorus_g_phaser_depth0_fb127", S_CHORUS, {G2(G_CRATE, 40), G2(G_CDEPTH, 0), G2(G_CMODE, 2), G2(G_CFDBK, 127)}, 4, -1, -1},
    /* GLO > GLOBAL: BPM, SWING+ 0..100 */
    {"global_a_swing0", S_GLOBAL, {G2(G_SWING, 0)}, 1, -1, -1},
    {"global_b_swing50", S_GLOBAL, {G2(G_SWING, 50)}, 1, -1, -1},
    {"global_c_swing100", S_GLOBAL, {G2(G_SWING, 100)}, 1, -1, -1},
    /* GLO > MIXER (GLO's first page): as ui_render's scenes set it */
    {"mixer_a_levels", S_MIXER, {{0}}, 0, -1, -1},
    {"mixer_b_pans", S_MIXER_PAN, {{0}}, 0, -1, -1},
    /* FX > DELAY and FX > REVERB (the track's send into the bus) */
    {"fxdelay_a_send89", S_FX_DELAY, {G2(G_DTIME, 1), G2(G_DFDBK, 60), G2(G_DMIX, 90)}, 3, 89, -1},
    {"fxdelay_b_send30", S_FX_DELAY, {G2(G_DTIME, 1), G2(G_DFDBK, 60), G2(G_DMIX, 90)}, 3, 30, -1},
    {"fxreverb_a_hall_send70", S_FX_REVERB, {G2(G_RTYPE, 2), G2(G_RSIZE, 90), G2(G_RDAMP, 60)}, 3, -1, 70},
    {"fxreverb_b_room_send127", S_FX_REVERB, {G2(G_RTYPE, 0), G2(G_RSIZE, 90), G2(G_RDAMP, 60)}, 3, -1, 127},
};

int main(int argc, char **argv)
{
    const char *out = argc > 1 ? argv[1] : "build/fm1shots";
    int all = argc > 2;                              /* any 2nd arg: every theme for the "_a_" shots too */
    uint32_t i, k, p;
    for (i = 0; i < sizeof SHOTS / sizeof SHOTS[0]; i++) {
        const shot_t *s = &SHOTS[i];
        for (p = 0; p < NPALETTES; p++) {
            if (p != UI_SKIFF_INDEX && !(all && strstr(s->name, "_a_")))
                continue;
            setup(s->scene);
            for (k = 0; k < (uint32_t)s->ng; k++) song.g[s->g[k][0]] = s->g[k][1];
            if (s->send_dly >= 0) TSEL->p[P_DLY] = s->send_dly;
            if (s->send_rev >= 0) TSEL->p[P_REV] = s->send_rev;
            ui.hot_t = 0;                            /* no card lit: the page at rest */
            pal(p);
            draw(s->scene);
            write_ppm(out, UI_PALETTES[p].name, s->name);
        }
    }
    printf("fm1shots: %u shots (FELUCCA_VERSION %s)\n", (unsigned)(sizeof SHOTS / sizeof SHOTS[0]), FELUCCA_VERSION);
    return 0;
}
