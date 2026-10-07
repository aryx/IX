/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* mini-squeak's clock: the milliseconds since the board started, by
 * the Pi 4's generic timer (its count over its frequency: l.s's), the
 * one machine.c arms for its ticks. Smalltalk's millisecond clock. */
#include <mlvalues.h>

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
