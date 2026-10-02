/* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 */
/* Linux, on the bare Pi 4 (plan_kernel_mini_ml.md, decision 8): the C
 * library (lib_core/libc, goken's) and mini-ml's runtime reach the
 * system through one function, _syscall6 (svc_arm64.s's: the number,
 * six arguments, the kernel's answer). Here it is C, and the system is
 * two calls: write, to the PL011, and exit, the end. The others say
 * ENOSYS, as a kernel that does not have them. */
#include <u.h>
#include <libc.h>

extern void halt(void);

static void
uart(int c)
{
	uint *u;

	u = (uint*)0xFE201000;
	while(u[6] & 0x20)	/* FR, at 0x18: the transmit FIFO full */
		;
	u[0] = c;
}

/* (a number is a long for the library, a word for the runtime: its low half) */
vlong
_syscall6(vlong n, vlong a1, vlong a2, vlong a3, vlong a4, vlong a5, vlong a6)
{
	char *s;
	vlong i;

	switch((int)n){
	case 64:	/* write: any descriptor is the console */
		s = (char*)a2;
		for(i = 0; i < a3; i++)
			uart(s[i]);
		return a3;
	case 93:	/* exit, exit_group */
	case 94:
		halt();
	}
	return -38;
}

/* the same, for the calls whose answer is 64 bits (lseek) */
vlong
_syscall6v(vlong n, vlong a1, vlong a2, vlong a3, vlong a4, vlong a5, vlong a6)
{
	return _syscall6(n, a1, a2, a3, a4, a5, a6);
}
