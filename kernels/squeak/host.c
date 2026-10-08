/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* What mini-squeak's Host asks of C. Its clock: the milliseconds since
 * the board started, by the Pi 4's generic timer (its count over its
 * frequency: l.s's), the one machine.c arms for its ticks. And the
 * Display's pixels made the board's of 16 bits, where a pixel at a
 * time in OCaml would be most of a pass of the world. */
#include <mlvalues.h>
#include <alloc.h>
#include "board.h"

/* (machine.c's: a physical address, as the kernel sees it) */
#define P2V(pa) ((uchar*)((uintptr)(pa) + KERNBASE))

extern uintptr timer_frequency(void);
extern uintptr timer_count(void);

value
squeak_milliseconds(value unit)
{
	uintptr f;

	(void)unit;
	f = timer_frequency();
	if(f == 0)
		return Val_long(0);
	return Val_long((timer_count() / (f / 1000)) & 0x3fffffff);
}

/* [squeak_show16 fb pitch pixels w red]: pixels of four bytes, w a
 * row, their red at byte [red] and green and blue after it (0: red,
 * green, blue, alpha; 1: alpha, red, green, blue), written to the
 * framebuffer at the physical address fb, pitch bytes a row, as 5, 6
 * and 5 bits of red, green and blue, the low byte first. */
value
squeak_show16(value fb, value pitch, value pixels, value w, value red)
{
	uchar *s, *d;
	long width, rows, x, y, v;

	width = Long_val(w);
	rows = string_length(pixels) / (4 * width);
	s = (uchar*)String_val(pixels) + Long_val(red);
	for(y = 0; y < rows; y++){
		d = (uchar*)P2V(Long_val(fb)) + y * Long_val(pitch);
		for(x = 0; x < width; x++){
			v = ((s[0] >> 3) << 11) | ((s[1] >> 2) << 5) | (s[2] >> 3);
			d[0] = v;
			d[1] = v >> 8;
			d += 2;
			s += 4;
		}
	}
	return Val_unit;
}
