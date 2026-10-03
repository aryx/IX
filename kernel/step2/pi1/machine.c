/* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 */
/* mini-xv6, step 2, on the Pi 1 by ix's tools (plan_kernel_mini_ml.md,
 * step 9): the machine as Main.ml sees it, by mini-cc over mini-ml's
 * runtime; ../machine.c is the same for gcc and ocaml-light's. The
 * trap frame is xv6 arm-pi1's, the one Main.ml reads (17 words: r0-r12,
 * sp, lr, pc, the status): no view of it as on the Pi 4. */

#include <mlvalues.h>
#include <callback.h>

/* the trap frame, and where l.s finds it */
static uint trapframe[17];
uint *cur_tf;

/* l.s's */
extern void user_return(void);
extern void vectors_install(void);
extern void halt(void);
/* user.s's */
extern void user_main(void);
extern char ustack[];

/*****************************************************************************/
/* The primitives */
/*****************************************************************************/

value mem_get8(value a) { return Val_long(*(uchar*)Long_val(a)); }
value mem_get32(value a) { return Val_long(*(uint*)Long_val(a)); }
value mem_set32(value a, value v) { *(uint*)Long_val(a) = Long_val(v); return Val_unit; }

value trapframe_addr(value unit) { return Val_long((uintptr)trapframe); }

/* the console: the PL011, a character at a time */
value
uart_putc(value c)
{
	uint *u;

	u = (uint*)0x20201000;
	while(u[6] & 0x20)
		;
	u[0] = Long_val(c) & 0xff;
	return Val_unit;
}

value machine_halt(value unit) { halt(); return unit; }

/* to user mode (the interrupts masked: no interrupt yet) at pc with stack sp: the
 * frame set, then l.s's way back from a trap. It does not return: the
 * user's system calls come back through trap() */
value
user_enter(value pc, value sp)
{
	int i;

	for(i = 0; i < 17; i++)
		trapframe[i] = 0;
	trapframe[13] = Long_val(sp);
	trapframe[15] = Long_val(pc);
	trapframe[16] = 0x10 | 0x80 | 0x40;	/* USR, I and F masked */
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

/* a fault: the machine stops, saying which and where */
void
kfault(int kind, uint lr)
{
	static char *names[] = { "", "undefined instruction", "prefetch abort", "data abort" };
	char line[80];

	snprint(line, sizeof line, "mini-xv6: %s, lr %08ux\n", names[kind], lr);
	say(line);
	halt();
}

/* a system call: the kernel's OCaml handler, registered by name */
void
trap(void)
{
	static value *handler;

	if(handler == nil)
		handler = caml_named_value("trap");
	callback(*handler, Val_unit);
}

/* the user program's entry and stack (user.s) */
value user_entry(value unit) { return Val_long((uintptr)user_main); }
value user_stack(value unit) { return Val_long((uintptr)(ustack + 4096)); }
