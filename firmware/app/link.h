/* SPDX-License-Identifier: GPL-3.0-only WITH GPL-3.0-linking-exception */
#ifndef FM1_LINK_H
#define FM1_LINK_H
#include <stddef.h>
#include <stdint.h>

/* fm1-ipad link: the iPad protocol, specified in protocol/README.md of the
 * fm1-ipad repo. sysex runs on the routing task and only queues; init and poll
 * run on the control task. */
enum { GROOVE_LINK_TRACK_ONLY = 0x7f };
void groove_link_init(void);
void groove_link_sysex(const uint8_t *message, size_t bytes);
void groove_link_poll(void);

/* screen.c: the panel selection that the link mirrors. selection fills track,
 * step and page. select returns 0, -1 for invalid input, -2 when busy. */
void groove_screen_selection(unsigned out[3]);
int groove_screen_select(unsigned track, unsigned step);
#endif
