/* What the FM-1 on Skiff 2.5.1 draws on each sound page: for every engine (at its first preset, as an engine change
 * loads it), each page of the sound families with whether the family's button reaches it (ui.c page_visible), and
 * each of the four columns as ui_draw.c draws it (the label, an action column, a blank) with the text param_format
 * gives a spread of raw values (every value of a list; the ends, the default and steps between for a number), and HOME's
 * four knobs (ui.c home_param: the engine's .knob) the same way. Two
 * cases more on the first engine: INSERT under every TYPE (its A B C take the TYPE's names) and ENV with ENV SYNC on
 * (note values).
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
    printf("}\n");
    return 0;
}
