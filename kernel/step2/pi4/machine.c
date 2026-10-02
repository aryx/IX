/* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 */
/* mini-xv6, step 2, on the Pi 4 (plan_kernel_mini_ml.md, step 4): the
 * machine as Main.ml sees it, by mini-cc; ../machine.c is the Pi 1's,
 * by gcc. The same primitives, so that Main.ml is the same file for
 * the two boards: it reads the user's registers as xv6 arm-pi1 lays
 * them out (17 words of 32 bits: r0-r12, sp, lr, pc, the status), and
 * here that is a view, filled from the real frame (l.s's: x0-x30, the
 * user's sp, pc and status, 64 bits each) before the kernel's OCaml
 * runs, its r0 (the result) copied back after. user.s's program
 * follows the same convention: the call's number in its first
 * register, its arguments on its stack, 32 bits each. */

#include <mlvalues.h>
#include <callback.h>

/* the trap frame, and where l.s finds it */
static uvlong trapframe[34];
uvlong *cur_tf;

/* l.s's */
extern void user_return(void);
extern void vectors_install(void);
extern void halt(void);
/* user.s's */
extern void user_main(void);
extern char ustack[];

static uint view[17];

/*****************************************************************************/
/* The primitives */
/*****************************************************************************/

value mem_get8(value a) { return Val_long(*(uchar*)Long_val(a)); }
value mem_get32(value a) { return Val_long(*(uint*)Long_val(a)); }
value mem_set32(value a, value v) { *(uint*)Long_val(a) = Long_val(v); return Val_unit; }

value trapframe_addr(value unit) { return Val_long((uintptr)view); }

/* the console: the PL011, a character at a time */
value
uart_putc(value c)
{
	uint *u;

	u = (uint*)0xFE201000;
	while(u[6] & 0x20)
		;
	u[0] = Long_val(c) & 0xff;
	return Val_unit;
}

value machine_halt(value unit) { halt(); return unit; }

/* to user mode (EL0, the interrupts masked) at pc with stack sp: the
 * frame set, then l.s's way back from a trap. It does not return: the
 * user's system calls come back through trap() */
value
user_enter(value pc, value sp)
{
	int i;

	for(i = 0; i < 31; i++)
		trapframe[i] = 0;
	trapframe[31] = Long_val(sp);
	trapframe[32] = Long_val(pc);
	trapframe[33] = 0x3c0;
	cur_tf = trapframe;
	vectors_install();
	user_return();
	return Val_unit;
}

/*****************************************************************************/
/* The traps */
/*****************************************************************************/

static void
say(char *s)
{
	for(; *s != 0; s++)
		uart_putc(Val_long(*s));
}

/* a fault: the machine stops, saying which (ESR's class) and where */
void
kfault(uvlong esr, uvlong elr)
{
	char line[80];

	snprint(line, sizeof line, "mini-xv6: a fault, class %#llux, at %#llux\n", esr >> 26, elr);
	say(line);
	halt();
}

/* from user mode, a system call (ESR's class 0x15: SVC): the kernel's
 * OCaml handler, registered by name */
void
trap(uvlong esr)
{
	static value *handler;
	int i;

	if(esr >> 26 != 0x15)
		kfault(esr, trapframe[32]);
	for(i = 0; i < 13; i++)
		view[i] = trapframe[i];
	view[13] = trapframe[31];
	view[15] = trapframe[32];
	if(handler == nil)
		handler = caml_named_value("trap");
	callback(*handler, Val_unit);
	trapframe[0] = (int)view[0];
}

/* the user program's entry and stack (user.s) */
value user_entry(value unit) { return Val_long((uintptr)user_main); }
value user_stack(value unit) { return Val_long((uintptr)(ustack + 4096)); }
