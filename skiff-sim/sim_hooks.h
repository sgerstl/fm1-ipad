/* SPDX-License-Identifier: GPL-3.0-only
 * skiff-sim: what the unit's ota.c, ota_hw.c, storage_hw.c and fm1_flash.h give editor.c and main.c, over the
 * simulated NOR of web/emu/felucca_web.c. build.sh puts this file into felucca_sim.c just before editor.c. */

static void sim_drain(void);                           /* sim_core.c: the editor's SysEx and MIDI OUT to the host */

static uint32_t ota_now_ms(void) { return fm1_ms; }
static void ota_idle(void) { sim_drain(); }            /* ota_wire_send waits here while the SysEx ring is full */
static void ota_service(void) {}                       /* (no M-UPGRADE: updates go to the unit, not the sim) */
static int ota_session(void) { return 0; }
static int ota_boot_cleanup(void) { return 0; }

static void audio_silence(void) {}                     /* (storage_hw.c: no DMA to keep quiet) */
static void fl_inval(uint32_t off, uint32_t n) { (void)off; (void)n; }   /* (no XIP cache: nor is read directly) */
static int fl_erase4k(uint32_t off, uint32_t *took_us)
{
    *took_us = 0;
    return st_erase(off) ? -1 : 0;
}
static int fl_write(uint32_t off, const uint8_t *src_ram, uint32_t n)
{
    return st_prog(off, src_ram, n) ? -1 : 0;
}
