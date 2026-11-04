/* SPDX-License-Identifier: GPL-3.0-only
 * skiff-sim: Skiff's firmware on the Mac, behind a virtual USB-MIDI port, for Jib to talk to without an FM-1.
 *
 * The device (sim_core.c) runs on one thread, a millisecond at a time against the wall clock, as the browser build
 * runs it against the audio. CoreMIDI's thread only fills an input ring; the device thread drains it, runs, and sends
 * what the firmware sends (editor replies, clock, notes) from the source endpoint. The NOR flash is kept in a file
 * between runs, as the unit keeps its flash.
 *
 *   skiff-sim [--name NAME] [--flash FILE] [--truth]       then type: help
 * (--truth, test-only: each track's step as a SysEx of the sim's own, for skiffprobe playhead) */
#include <CoreMIDI/CoreMIDI.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef void (*sim_out_fn)(const uint8_t *bytes, uint32_t n);
void sim_set_output(sim_out_fn f);
uint8_t *sim_nor(void);
uint32_t sim_nor_size(void);
void sim_boot(void);
void sim_midi_in(const uint8_t *b, uint32_t n);
void sim_step_ms(void);
uint32_t sim_now_ms(void);
uint32_t sim_playing(void);
const char *sim_version(void);
uint32_t sim_out_drops(void);
int sim_screen_ppm(const char *path);
int sim_press(const char *name, uint32_t down);
uint32_t sim_ntrk(void);                                /* TEST-ONLY (sim_core.c) */
uint32_t sim_track_step(uint32_t i);

static MIDIEndpointRef src;
static atomic_uint msgs_in, msgs_out, sysex_in, sysex_out;
static atomic_int quit;

/* ------------------------------------------------ CoreMIDI -> device --- */
#define IN_RING 65536u
static uint8_t in_ring[IN_RING];
static atomic_uint in_w, in_r;

static void midi_read(const MIDIPacketList *pl, void *ref, void *src_ref)
{
    const MIDIPacket *p = &pl->packet[0];
    uint32_t i, k;
    (void)ref;
    (void)src_ref;
    for (i = 0; i < pl->numPackets; i++) {
        uint32_t w = atomic_load_explicit(&in_w, memory_order_relaxed);
        if (IN_RING - (w - atomic_load_explicit(&in_r, memory_order_acquire)) < p->length) {
            fprintf(stderr, "skiff-sim: input ring full, %u bytes dropped\n", p->length);
        } else {
            for (k = 0; k < p->length; k++)
                in_ring[(w + k) % IN_RING] = p->data[k];
            if (p->length && p->data[0] == 0xF0)
                atomic_fetch_add(&sysex_in, 1);
            atomic_fetch_add(&msgs_in, 1);
            atomic_store_explicit(&in_w, w + p->length, memory_order_release);
        }
        p = MIDIPacketNext(p);
    }
}

/* ------------------------------------------------ device -> CoreMIDI --- */
static int trace;

static void midi_out(const uint8_t *b, uint32_t n)
{
    static Byte buf[sizeof(MIDIPacketList) + 9000];
    MIDIPacketList *pl = (MIDIPacketList *)buf;
    MIDIPacket *p = MIDIPacketListInit(pl);
    if (n > 8192)
        return;
    p = MIDIPacketListAdd(pl, sizeof buf, p, mach_absolute_time(), n, b);
    if (!p)
        return;
    MIDIReceived(src, pl);
    atomic_fetch_add(&msgs_out, 1);
    if (b[0] == 0xF0) {
        atomic_fetch_add(&sysex_out, 1);
        if (trace)
            fprintf(stderr, "skiff-sim: reply cmd %u, %u bytes\n", n > 4 ? b[4] : 0, n);
    }
}

/* ---------------------------------------------------- the console --- */
/* commands for the device thread, one at a time */
static pthread_mutex_t cmd_lock = PTHREAD_MUTEX_INITIALIZER;
static char cmd[512];
static atomic_int cmd_ready;

static const char *flash_path = "skiff-sim-flash.bin";

static void flash_save(void)
{
    FILE *f = fopen(flash_path, "wb");
    if (!f) {
        fprintf(stderr, "skiff-sim: can't write %s\n", flash_path);
        return;
    }
    fwrite(sim_nor(), 1, sim_nor_size(), f);
    fclose(f);
}

static void flash_load(void)
{
    FILE *f = fopen(flash_path, "rb");
    memset(sim_nor(), 0xFF, sim_nor_size());
    if (!f) {
        printf("skiff-sim: a new unit (no %s yet)\n", flash_path);
        return;
    }
    if (fread(sim_nor(), 1, sim_nor_size(), f) != sim_nor_size())
        printf("skiff-sim: %s is short; the rest is erased\n", flash_path);
    fclose(f);
}

static uint32_t press_up_at;
static char press_name[16];

static void run_cmd(const char *c)
{
    char a[400];
    if (!strcmp(c, "status")) {
        printf("%s, %u ms, %s; in %u msgs (%u SysEx), out %u msgs (%u SysEx), MIDI OUT drops %u\n", sim_version(),
               sim_now_ms(), sim_playing() ? "playing" : "stopped", atomic_load(&msgs_in), atomic_load(&sysex_in),
               atomic_load(&msgs_out), atomic_load(&sysex_out), sim_out_drops());
    } else if (sscanf(c, "screen %399s", a) == 1) {
        printf(sim_screen_ppm(a) ? "skiff-sim: can't write %s\n" : "screen -> %s\n", a);
    } else if (sscanf(c, "press %15s", press_name) == 1) {
        if (sim_press(press_name, 1))
            printf("no button %s (FX SCL ENV LFO EDIT GLO HOME SAVE ARP SEQ PLAY REC OCT- OCT+)\n", press_name);
        else
            press_up_at = sim_now_ms() + 80u;
    } else if (!strcmp(c, "save")) {
        flash_save();
        printf("flash -> %s\n", flash_path);
    } else if (!strcmp(c, "trace")) {
        trace = !trace;
        printf("trace %s\n", trace ? "on" : "off");
    } else if (*c) {
        printf("commands: status, screen FILE.ppm, press BUTTON, trace, save, quit\n");
    }
    fflush(stdout);
}

/* ------------------------------------------------- the device thread --- */
/* TEST-ONLY, --truth: while playing, each time a track's step changes, F0 7D 53 4D s0..s5 F7 (each track's seq_idx),
 * sent after the millisecond's clock and notes. Not the unit's: it is skiffprobe playhead's ground truth */
static int truth;
static void truth_send(void)
{
    static uint8_t last[16] = {0xFF};
    static uint32_t was_playing;
    uint8_t m[32] = {0xF0, 0x7D, 0x53, 0x4D};
    uint32_t i, n = sim_ntrk(), changed = 0;
    if (!sim_playing()) {
        was_playing = 0;
        return;
    }
    for (i = 0; i < n && i < 16u; i++) {
        m[4 + i] = (uint8_t)(sim_track_step(i) & 127u);
        changed |= m[4 + i] != last[i] || !was_playing;
        last[i] = m[4 + i];
    }
    was_playing = 1;
    m[4 + i] = 0xF7;
    if (changed)
        midi_out(m, 5 + i);
}

static void *device(void *arg)
{
    mach_timebase_info_data_t tb;
    uint64_t t0, done = 0;
    (void)arg;
    mach_timebase_info(&tb);
    t0 = mach_absolute_time();
    while (!atomic_load(&quit)) {
        uint64_t now_ms = (mach_absolute_time() - t0) * tb.numer / tb.denom / 1000000u;
        if (now_ms - done > 200u) {                     /* far behind (the Mac slept, a debugger): don't race */
            done = now_ms - 1u;
        }
        while (done < now_ms) {
            uint32_t w = atomic_load_explicit(&in_w, memory_order_acquire), r = atomic_load(&in_r);
            uint8_t chunk[256];
            while (r != w) {
                uint32_t n = 0;
                while (r != w && n < sizeof chunk)
                    chunk[n++] = in_ring[r++ % IN_RING];
                sim_midi_in(chunk, n);
            }
            atomic_store_explicit(&in_r, r, memory_order_release);
            sim_step_ms();
            if (truth)
                truth_send();
            if (press_up_at && (int32_t)(sim_now_ms() - press_up_at) >= 0) {
                sim_press(press_name, 0);
                press_up_at = 0;
            }
            done++;
        }
        if (atomic_load(&cmd_ready)) {
            pthread_mutex_lock(&cmd_lock);
            run_cmd(cmd);
            atomic_store(&cmd_ready, 0);
            pthread_mutex_unlock(&cmd_lock);
        }
        usleep(500);
    }
    flash_save();
    return 0;
}

static void on_sigint(int s)
{
    (void)s;
    atomic_store(&quit, 1);
}

int main(int argc, char **argv)
{
    const char *name = "Felucca (Skiff sim)";
    MIDIClientRef client;
    MIDIEndpointRef dst;
    CFStringRef cf;
    pthread_t th;
    char line[512];
    int i;
    for (i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--name") && i + 1 < argc)
            name = argv[++i];
        else if (!strcmp(argv[i], "--flash") && i + 1 < argc)
            flash_path = argv[++i];
        else if (!strcmp(argv[i], "--truth"))
            truth = 1;
        else {
            fprintf(stderr, "usage: skiff-sim [--name NAME] [--flash FILE] [--truth]\n");
            return 2;
        }
    }
    setvbuf(stdout, 0, _IOLBF, 0);
    if (MIDIClientCreate(CFSTR("skiff-sim"), 0, 0, &client)) {
        fprintf(stderr, "skiff-sim: no CoreMIDI client\n");
        return 1;
    }
    cf = CFStringCreateWithCString(0, name, kCFStringEncodingUTF8);
    if (MIDISourceCreate(client, cf, &src) || MIDIDestinationCreate(client, cf, midi_read, 0, &dst)) {
        fprintf(stderr, "skiff-sim: can't make the virtual port\n");
        return 1;
    }
    CFRelease(cf);

    flash_load();
    sim_set_output(midi_out);
    sim_boot();
    printf("skiff-sim: %s on \"%s\". Type help.\n", sim_version(), name);
    signal(SIGINT, on_sigint);
    pthread_create(&th, 0, device, 0);

    while (!atomic_load(&quit) && fgets(line, sizeof line, stdin)) {
        line[strcspn(line, "\r\n")] = 0;
        if (!strcmp(line, "quit"))
            break;
        pthread_mutex_lock(&cmd_lock);
        snprintf(cmd, sizeof cmd, "%s", line);
        atomic_store(&cmd_ready, 1);
        pthread_mutex_unlock(&cmd_lock);
        while (atomic_load(&cmd_ready) && !atomic_load(&quit))
            usleep(1000);
    }
    if (!atomic_load(&quit) && feof(stdin))             /* no console (run in the background): wait for ^C */
        while (!atomic_load(&quit))
            pause();
    atomic_store(&quit, 1);
    pthread_join(th, 0);
    printf("skiff-sim: flash saved to %s\n", flash_path);
    MIDIEndpointDispose(src);
    MIDIEndpointDispose(dst);
    return 0;
}
