/* SPDX-License-Identifier: GPL-3.0-only */
/* skdscope (spike, decision 45): the SCOPE round trip. For a few signals in the ring audio.c fills: the EDIT page's
 * scope drawn by graph_scope from the ring itself (what the FM-1 shows), against the same page drawn from the 120
 * points SCOPE sends (ed_osc_reply's reading) put back into the ring (skd_set_scope). Also the SKIFF theme's sea
 * from METER levels. Writes OUT/scope_<sig>_<pal>_{ring,link}.ppm and prints the pixels that differ in the panel.
 *   cc -O1 -w -I$C/include -I$C -I$C/skiff/gen -I$C/skiff/firmware/src ios/SkiffDraw/Tools/skdscope.c -lm */
#include "skiffdraw.c"

static void put(const char *out, const char *name, const uint8_t *img)
{
    char path[512];
    FILE *f;
    uint32_t k;
    snprintf(path, sizeof path, "%s/%s.ppm", out, name);
    f = fopen(path, "wb");
    fprintf(f, "P6\n240 240\n255\n");
    for (k = 0; k < 240u * 240u; k++) fwrite(img + 4 * k, 1, 3, f);
    fclose(f);
}

int main(int argc, char **argv)
{
    static uint8_t a[240 * 240 * 4], b[240 * 240 * 4];
    static int16_t ring[SCOPE_N];
    static const char *SIG[] = {"sine441", "saw", "quiet", "pluck"};
    const char *out = argc > 1 ? argv[1] : ".";
    uint8_t pts[120];
    uint32_t s, i, p;
    for (s = 0; s < 4; s++) {
        for (i = 0; i < SCOPE_N; i++) {
            double t = i, v;
            if (s == 0) v = 12000.0 * sin(6.2831853 * t / 100.0) + 4500.0 * sin(6.2831853 * t / 50.0 + 0.7);  /* ui_render S_HOME_SCOPE */
            else if (s == 1) v = (fmod(t, 73.0) / 73.0 * 2.0 - 1.0) * 9000.0 + sin(t * 0.4908) * 2500.0;
            else if (s == 2) v = 900.0 * sin(6.2831853 * t / 37.0);                                         /* under SCOPE_FLOOR */
            else v = 20000.0 * exp(-t / 160.0) * sin(6.2831853 * t / 23.0) * (1.0 + 0.4 * sin(t * 0.05));
            ring[(i + 5u) % SCOPE_N] = (int16_t)v;                                                          /* (not phase 0) */
        }
        for (p = 1; p <= 2; p++) {                   /* HI-CON, PAPER: the trace (SKIFF, CRYPT, QUARK draw levels) */
            char nm[96];
            uint32_t d = 0, k;
            skd_reset();
            skd_select_track(2);                     /* LOFI: EDIT 1 has no graph of its own, so the scope */
            skd_set_palette((int)p);
            skd_goto_page(skd_page_find("EDIT 1", 0));
            skd_set_scope_ring(ring, SCOPE_N);
            skd_render_rgba(a);
            skd_scope_from_ring(ring, SCOPE_N, pts);
            skd_set_scope(pts, 120);
            skd_render_rgba(b);
            for (k = 0; k < 240u * 240u; k++) d += memcmp(a + 4 * k, b + 4 * k, 3) != 0;
            snprintf(nm, sizeof nm, "scope_%s_%s_ring", SIG[s], skd_palette_name((int)p)); put(out, nm, a);
            snprintf(nm, sizeof nm, "scope_%s_%s_link", SIG[s], skd_palette_name((int)p)); put(out, nm, b);
            printf("%-8s %-7s pixels differing ring vs link: %u\n", SIG[s], skd_palette_name((int)p), d);
        }
    }
    {   /* SKIFF: the sea from METER levels, at two moments */
        static const uint8_t LV[6] = {110, 80, 0, 95, 60, 30};
        skd_reset();
        skd_select_track(2);
        skd_goto_page(skd_page_find("EDIT 1", 0));
        skd_set_playing(1);
        for (i = 0; i < 2; i++) {
            char nm[64];
            skd_set_ms(1000u + i * 400u);
            skd_set_meters(LV, 6);
            skd_render_rgba(a);
            snprintf(nm, sizeof nm, "sea_SKIFF_%u", i); put(out, nm, a);
        }
        printf("sea: drawn (%u us)\n", skd_draw_cost_us());
    }
    return 0;
}
