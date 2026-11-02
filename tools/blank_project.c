/* Writes the working project TOOLS > NEW leaves (project_new, then proj_capture) as the bytes BK_GET returns. */
#include <stddef.h>
#include "editor_host.c"
int main(int argc, char **argv)
{
    static project_t p;
    harness_init();
    project_new();
    proj_capture(&p);
    FILE *f = fopen(argv[1], "wb");
    fwrite(&p, 1, sizeof p, f);
    fclose(f);
    printf("size %zu, bpm %d, sel %d, engines %d %d %d, presets %d %d %d, kit %d\n", sizeof p, p.g[G_BPM], p.sel,
           p.t[0].engine, p.t[1].engine, p.t[2].engine, p.t[0].preset, p.t[1].preset, p.t[2].preset, p.t[3].e[0]);
    printf("offset t %zu, trk size %zu, step off %zu, mf off %zu, lock off %zu, sum off %zu\n", offsetof(project_t, t),
           sizeof(proj_trk_t), offsetof(proj_trk_t, step), offsetof(proj_trk_t, mf), offsetof(proj_trk_t, lock), offsetof(project_t, sum));
    return 0;
}
