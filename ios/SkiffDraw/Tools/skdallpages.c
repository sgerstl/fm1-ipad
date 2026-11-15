/* SPDX-License-Identifier: GPL-3.0-only */
/* skdallpages (spike, decision 45): every page of params.c PAGES[] on every engine, through skiffdraw.h: does it draw,
 * how long it takes, and which state the drawing read beyond song.g and the selected track's p[] (by changing that
 * state and seeing whether the frame changes). Writes OUT/page_<i>_<eng>.ppm for engine 0 and one contact list. */
#include "skiffdraw.c"
static uint32_t hash(const uint8_t *p, uint32_t n) { uint32_t h = 2166136261u; while (n--) h = (h ^ *p++) * 16777619u; return h; }
int main(int argc, char **argv)
{
    static uint8_t img[240 * 240 * 4];
    uint32_t e, i, worst = 0, n = 0, steps_dep = 0, other_dep = 0, time_dep = 0;
    for (i = 0; i < NPAGES; i++) {
        uint32_t seen = 0, depS = 0, depO = 0, depT = 0;
        for (e = 0; e < NENGINES; e++) {
            uint32_t h0, h1;
            if (ENGINES[e] == ENGINES[1] && e == 1) continue;      /* (reserved slot) */
            skd_reset(); skd_set_engine(0, (int)e); skd_select_track(0); skd_goto_page((int)i);
            if (ui.home || ui.page != i) continue;                   /* the page isn't this engine's */
            seen++;
            skd_set_ms(1000); skd_render_rgba(img); h0 = hash(img, sizeof img); n++;
            if (skd_draw_cost_us() > worst) worst = skd_draw_cost_us();
            trk[0].step[0].note[0] = 72; trk[0].step[0].n = 1; trk[0].step[3].note[0] = 40; trk[0].step[3].n = 1;   /* the steps */
            skd_render_rgba(img); h1 = hash(img, sizeof img); if (h1 != h0) depS = 1;
            skd_reset(); skd_set_engine(0, (int)e); skd_select_track(0); skd_goto_page((int)i); skd_set_ms(1000);
            trk[3].p[P_LEVEL] = 20; trk[4].p[P_MUTE] = 1; trk[1].p[P_E0] += 7;   /* another track's values */
            skd_render_rgba(img); if (hash(img, sizeof img) != h0) depO = 1;
            skd_reset(); skd_set_engine(0, (int)e); skd_select_track(0); skd_goto_page((int)i); skd_set_ms(1600);   /* only the clock */
            skd_render_rgba(img); if (hash(img, sizeof img) != h0) depT = 1;
            if (e == 0 && argc > 1) {
                char p[256]; FILE *f; uint32_t k;
                skd_set_ms(1000); skd_render_rgba(img);
                snprintf(p, sizeof p, "%s/page_%02u.ppm", argv[1], i); f = fopen(p, "wb"); fprintf(f, "P6\n240 240\n255\n");
                for (k = 0; k < 240u * 240u; k++) fwrite(img + 4 * k, 1, 3, f); fclose(f);
            }
        }
        steps_dep += depS; other_dep += depO; time_dep += depT;
        printf("%2u %-11s fam %2u engines %2u  reads: %s%s%s\n", i, PAGES[i].title, PAGES[i].fam, seen,
               depS ? "steps " : "", depO ? "other-tracks " : "", depT ? "clock " : "");
    }
    printf("frames %u, worst %u us; pages reading the steps %u, other tracks %u, the clock %u\n", n, worst, steps_dep, other_dep, time_dep);
    return 0;
}
