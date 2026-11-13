/* What the FM-1 on Skiff 2.5.1 draws on each sound page: for every engine (at its first preset, as an engine change
 * loads it), each page of the sound families with whether the family's button reaches it (ui.c page_visible), and
 * each of the four columns as ui_draw.c draws it (the label, an action column, a blank) with the text param_format
 * gives a spread of raw values (every value of a list; the ends, the default and steps between for a number), and HOME's
 * four knobs (ui.c home_param: the engine's .knob) the same way. Two
 * cases more on the first engine: INSERT under every TYPE (its A B C take the TYPE's names) and ENV with ENV SYNC on
 * (note values). Then the sheets (ui.c sheet_t): FM6's OPERATOR and ALL OPS window by window with fm_val's text at every
 * value of each card, FINE in each mode, the numbers those come from, and DRUM-X's SOUND.
 *
 * Built against Skiff's own sources through tests/ui_test.c (the firmware's UI on the host, as Skiff's own UI tests
 * build it), by
 * android/scripts/skiff-page-dump.sh (it checks out the v2.5.1 tag; nothing here is Skiff's). The JSON it prints is
 * android/fixtures/skiff/skiff-2.5.1-pages.json, which PageParityTests compares PhoneCore's page area with
 * (decision 22, "match first"). */
#define UI_TEST_NO_MAIN 1
#include "ui_test.c"

static void js_str(const char *s)
{
    putchar('"');
    for (; s && *s; s++) {
        if (*s == '"' || *s == '\\')
            putchar('\\');
        if ((unsigned char)*s < 32 || (unsigned char)*s > 126)
            printf("\\u%04x", (unsigned char)*s);
        else
            putchar(*s);
    }
    putchar('"');
}

static const char *fam_name(uint32_t f)
{
    switch (f) {
    case FAM_ENV: return "ENV";
    case FAM_LFO: return "LFO";
    case FAM_FX: return "FX";
    case FAM_SCL: return "SEL";
    case FAM_EDIT: return "EDIT";
    case FAM_GLO: return "GLO";
    case FAM_ARP: return "ARP";
    default: return 0;
    }
}

/* the raw values a column is checked at */
static uint32_t spread(const param_desc_t *d, int32_t *out)
{
    uint32_t n = 0, i, j;
    int32_t span = d->max - d->min, v;
    if (d->fmt == F_ENUM || span <= 16) {
        for (v = d->min; v <= d->max && n < 140u; v++)
            out[n++] = v;
        return n;
    }
    out[n++] = d->min;
    out[n++] = d->max;
    out[n++] = clamp(d->def, d->min, d->max);
    for (i = 1; i < 12u; i++)
        out[n++] = d->min + (int32_t)((int64_t)span * (int32_t)i / 12);
    out[n++] = d->min + 1;
    out[n++] = d->max - 1;
    for (i = 0; i < n; i++)                         /* sorted, once each */
        for (j = i + 1; j < n; j++)
            if (out[j] < out[i]) { v = out[i]; out[i] = out[j]; out[j] = v; }
    for (i = 0, j = 0; i < n; i++)
        if (!j || out[i] != out[j - 1])
            out[j++] = out[i];
    return j;
}

static void page_json(uint32_t i)
{
    uint32_t c, k, n;
    int32_t vals[160];
    char val[16];
    const char *unit;
    ui.home = 0;
    ui.page = (uint8_t)i;
    printf("{\"index\":%u,\"title\":", i);
    js_str(PAGES[i].title);
    printf(",\"family\":");
    js_str(fam_name(PAGES[i].fam));
    printf(",\"graph\":%u,\"visible\":%s,\"slots\":[", PAGES[i].graph, page_visible(i) ? "true" : "false");
    for (c = 0; c < 4u; c++) {
        int16_t *vp;
        const param_desc_t *d = page_desc(&PAGES[i], c, &vp);
        if (c)
            putchar(',');
        if ((PAGES[i].graph == GR_LANES || PAGES[i].graph == GR_LMIX) && c == 0u) {
            printf("{\"label\":\"LANE\",\"drawnAbove\":true}");   /* (ui_draw.c: LANE is drawn above the columns) */
            continue;
        }
        if (!d || !d->label || d->label[0] == '-') {
            printf("{\"label\":\"\"}");
            continue;
        }
        printf("{\"label\":");
        js_str((PAGES[i].graph == GR_LANES || PAGES[i].graph == GR_LMIX) && c == 1u ? "LEVEL" : d->label);
        if ((act_cols() >> c) & 1u) {
            printf(",\"action\":true}");
            continue;
        }
        printf(",\"fmt\":%d,\"min\":%d,\"max\":%d,\"values\":[", d->fmt, d->min, d->max);
        n = spread(d, vals);
        for (k = 0; k < n; k++) {
            param_format(d, vals[k], val, &unit);
            printf("%s[%d,", k ? "," : "", vals[k]);
            js_str(val);
            putchar(',');
            js_str(unit);
            putchar(']');
        }
        printf("]}");
    }
    printf("]}");
}

/* HOME's four (ui.c home_param: the engine's .knob, through track_desc), as ui_draw.c draws them on HOME */
static void home_json(void)
{
    uint32_t c, k, n;
    int32_t vals[160];
    char val[16];
    const char *unit;
    ui.home = 1;
    printf("[");
    for (c = 0; c < 4u; c++) {
        int16_t *vp;
        const param_desc_t *d = home_param(c, &vp);
        printf("%s{\"id\":%d,\"label\":", c ? "," : "", (int)(vp - TSEL->p));
        js_str(d->label);
        printf(",\"fmt\":%d,\"min\":%d,\"max\":%d,\"values\":[", d->fmt, d->min, d->max);
        n = spread(d, vals);
        for (k = 0; k < n; k++) {
            param_format(d, vals[k], val, &unit);
            printf("%s[%d,", k ? "," : "", vals[k]);
            js_str(val);
            putchar(',');
            js_str(unit);
            putchar(']');
        }
        printf("]}");
    }
    printf("]");
    ui.home = 0;
}

/* ---- the sheets (ui.c sheet_t): FM6's OPERATOR and ALL OPS (ui_fm6.c), DRUM-X's SOUND (ui_dx.c) */

static void vals_out(int32_t v, const char *val, const char *unit, int first)
{
    printf("%s[%d,", first ? "" : ",", v);
    js_str(val);
    putchar(',');
    js_str(unit);
    putchar(']');
}

/* an FM6 card's text at every value of its field (fm_val: the FM-1's own), on the track's patch with that field set.
 * RATIO's value is the knob's position (x0.5 .. x31, then 1 .. 1K HZ); ALGO and FEEDBACK with EDIT 1's at PAT and 0 */
static void fm_card_json(uint32_t pg, uint32_t w, uint32_t k)
{
    const fm_field_t *f = &FM_F[pg][w][k];
    uint8_t p[FP_SIZE + 1u];
    char val[16];
    const char *unit;
    uint32_t i, v, mx;
    if (!f->label) { printf("{\"label\":\"\"}"); return; }
    i = fm_at(pg, f);
    printf("{\"label\":");
    js_str(f->label);
    printf(",\"values\":[");
    trk[0].p[P_E0] = 0; trk[0].p[P_E0 + 1] = 0;
    if (f->fmt == FMF_RATIO) {
        for (v = 0; v < 36u; v++) {
            memcpy(p, fm6_patch[0], sizeof p);
            uint8_t *op = p + (i / FP_OP) * FP_OP;
            op[FP_MODE] = (uint8_t)(v >= 32); op[FP_FC] = (uint8_t)(v >= 32 ? v - 32 : v);
            fm_val(f, i, p, &trk[0], val, &unit);
            vals_out((int32_t)v, val, unit, v == 0);
        }
    } else {
        mx = f->fmt == FMF_ALG ? 31u : f->fmt == FMF_FB ? 7u : fm6_max(i);
        for (v = 0; v <= mx; v++) {
            memcpy(p, fm6_patch[0], sizeof p);
            p[i] = (uint8_t)v;
            memcpy(fm6_patch[0], p, sizeof p);         /* (ALGO reads the track's patch: fm6_alg_of) */
            fm_val(f, i, p, &trk[0], val, &unit);
            vals_out((int32_t)v, val, unit, v == 0);
        }
    }
    printf("]}");
}

static void fm_sheet_json(uint32_t pg)
{
    uint32_t w, k;
    uint8_t keep[FP_SIZE + 1u];
    memcpy(keep, fm6_patch[0], sizeof keep);
    fm_ui[0] = 0;                                    /* OP1 (the operator changes which bytes, not the text) */
    printf("[");
    for (w = 0; w < FM_NWIN; w++) {
        printf("%s{\"window\":%u,\"slots\":[", w ? ",\n  " : "", w);
        for (k = 0; k < 4u; k++) { if (k) putchar(','); fm_card_json(pg, w, k); memcpy(fm6_patch[0], keep, sizeof keep); }
        printf("]}");
    }
    printf("]");
}

/* FINE in each mode: the ratio it plays (FC 0 and 1..31) or a fixed operator's frequency (FC 0..3), FF 0..99 */
static void fm_fine_json(void)
{
    static const uint8_t CASES[][2] = {{0, 0}, {0, 1}, {0, 7}, {0, 31}, {1, 0}, {1, 1}, {1, 2}, {1, 3}};
    uint32_t c, v;
    const fm_field_t *f = &FM_F[0][0][2];
    uint8_t p[FP_SIZE + 1u];
    char val[16];
    const char *unit;
    printf("[");
    for (c = 0; c < NELEM(CASES); c++) {
        printf("%s{\"mode\":%u,\"coarse\":%u,\"values\":[", c ? ",\n  " : "", CASES[c][0], CASES[c][1]);
        for (v = 0; v < 100u; v++) {
            memcpy(p, fm6_patch[0], sizeof p);
            uint8_t *op = p + 5u * FP_OP;                /* OP1 */
            op[FP_MODE] = CASES[c][0]; op[FP_FC] = CASES[c][1]; op[FP_FF] = (uint8_t)v;
            fm_val(f, 5u * FP_OP + FP_FF, p, &trk[0], val, &unit);
            vals_out((int32_t)v, val, unit, v == 0);
        }
        printf("]}");
    }
    printf("]");
}

/* DRUM-X's SOUND: each window's four as dx_cards labels and shows them (its tables; the numbers as fmt_int and
 * param_format write them) */
static void dx_sheet_json(void)
{
    uint32_t w, k, v, l = 0;
    char val[16];
    const char *unit;
    printf("[");
    for (w = 0; w < DX_NWIN; w++) {
        printf("%s{\"window\":%u,\"slots\":[", w ? ",\n  " : "", w);
        for (k = 0; k < 4u; k++) {
            uint32_t what = DX_WIN[w][k][0], i = DX_WIN[w][k][1];
            char lab[16];
            if (k) putchar(',');
            switch (what) {
            case DXK_A: case DXK_B:
                str_cpy(lab, DX_VAL[i], sizeof lab);
                str_cpy(lab + str_len(lab), what == DXK_A ? " A" : " B", 3);
                break;
            case DXK_LEVEL: str_cpy(lab, "LEVEL", sizeof lab); break;
            case DXK_DRV: str_cpy(lab, "DRIVE", sizeof lab); break;
            case DXK_WAVE: str_cpy(lab, "WAVE", sizeof lab); break;
            case DXK_FILT: str_cpy(lab, "FILTER", sizeof lab); break;
            case DXK_SNAP: str_cpy(lab, "SNAP", sizeof lab); break;
            default: str_cpy(lab, "P SHAPE", sizeof lab); break;
            }
            printf("{\"label\":");
            js_str(lab);
            printf(",\"values\":[");
            switch (what) {
            case DXK_A: case DXK_B:
                for (v = 0; v < 128u; v += (v < 4u || v > 123u) ? 1u : 9u) { fmt_int(val, (int32_t)v); vals_out((int32_t)v, val, "", v == 0); }
                break;
            case DXK_LEVEL:
                for (v = 0; v < 128u; v += (v < 4u || v > 123u) ? 1u : 9u) { param_format(&TP[P_LN0 + l], (int32_t)v, val, &unit); vals_out((int32_t)v, val, unit, v == 0); }
                break;
            case DXK_DRV: case DXK_SNAP:
                vals_out(0, "OFF", "", 1); vals_out(1, "ON", "", 0);
                break;
            case DXK_WAVE: for (v = 0; v < 4u; v++) vals_out((int32_t)v, DX_WAVE[v], "", v == 0); break;
            case DXK_FILT: for (v = 0; v < 3u; v++) vals_out((int32_t)v, DX_FILT[v], "", v == 0); break;
            default: for (v = 0; v < 4u; v++) vals_out((int32_t)v, DX_PMOD[v], "", v == 0); break;
            }
            printf("]}");
        }
        printf("]}");
    }
    printf("]");
}

/* the numbers the FM6 cards come from, for the phone's own copy (PhoneCore SkiffSheetTables.swift): a fixed operator's
 * Hz x 100 (FC & 3, FF: fm_fixed_hz100), the LFO's rate in tenths of a Hz (fm_lfo_hz10), a pitch level in tenths of a
 * semitone (FM6_PENV_TAB x 15 / 4) */
static void fm_tables_json(void)
{
    uint32_t c, v;
    uint8_t op[FP_OP];
    printf("{\"fixedHz100\":[");
    for (c = 0; c < 4u; c++)
        for (v = 0; v < 100u; v++) {
            memset(op, 0, sizeof op);
            op[FP_FC] = (uint8_t)c; op[FP_FF] = (uint8_t)v;
            printf("%s%u", c || v ? "," : "", fm_fixed_hz100(op));
        }
    printf("],\"lfoHz10\":[");
    for (v = 0; v < 100u; v++) printf("%s%u", v ? "," : "", fm_lfo_hz10(v));
    printf("],\"pitchTenths\":[");
    for (v = 0; v < 100u; v++) printf("%s%d", v ? "," : "", FM6_PENV_TAB[v] * 15 / 4);
    printf("]}");
}

static void pages_json(int only_fam, const char *only_title)
{
    uint32_t i, first = 1;
    printf("[");
    for (i = 0; i < NPAGES; i++) {
        if (!fam_name(PAGES[i].fam))
            continue;
        if (only_title && strcmp(PAGES[i].title, only_title) != 0)
            continue;
        if (only_fam && (int)PAGES[i].fam != only_fam)
            continue;
        if (!first)
            printf(",\n   ");
        first = 0;
        page_json(i);
    }
    printf("]");
}

int main(void)
{
    uint32_t e, k, first = 1;
    ui_power_on();                                  /* the power-on state, as Skiff's UI tests start */
    tsel = &trk[0];
    printf("{\"firmware\":\"FELUCCA v2.5.1\",\"note\":\"Made by android/scripts/skiff-page-dump.sh from Skiff's v2.5.1 "
           "sources (android/tools/skiff-pagedump/pagedump.c); don't edit by hand.\",\n\"engines\":[");
    for (e = 0; e < NENGINES; e++) {
        const engine_t *en = ENGINES[e];
        if (!en || !en->name || en->name[0] == '-' || en->npresets == 0)
            continue;
        host_preset(&trk[0], e, 0);
        tsel = &trk[0];
        mod_ui_route = 0;
        if (!first)
            printf(",\n");
        first = 0;
        printf("{\"engine\":%u,\"name\":", e);
        js_str(en->name);
        printf(",\"preset\":");
        js_str(en->presets[0].name);
        printf(",\"home\":");
        home_json();
        printf(",\"pages\":");
        pages_json(0, 0);
        printf("}");
    }
    printf("],\n\"insert\":[");
    host_preset(&trk[0], 0, 0);
    tsel = &trk[0];
    for (k = 0; k < NELEM(N_ITYPE); k++) {
        trk[0].p[P_ITYPE] = (int16_t)k;
        printf("%s{\"type\":%u,\"pages\":", k ? ",\n" : "", k);
        pages_json(0, "INSERT");
        printf("}");
    }
    trk[0].p[P_ITYPE] = 0;
    printf("],\n\"envSync\":");
    trk[0].p[P_ESYNC] = 1;
    pages_json(0, "ENV");
    trk[0].p[P_ESYNC] = 0;
    host_preset(&trk[0], ENGI_FM6, 0);
    tsel = &trk[0];
    printf(",\n\"sheets\":{\"operator\":");
    fm_sheet_json(0);
    printf(",\n\"allOps\":");
    fm_sheet_json(1);
    printf(",\n\"fine\":");
    fm_fine_json();
    printf(",\n\"fm6Tables\":");
    fm_tables_json();
    host_preset(&trk[0], ENGI_DRUMX, 0);
    tsel = &trk[0];
    printf(",\n\"sound\":");
    dx_sheet_json();
    printf("}}\n");
    return 0;
}
