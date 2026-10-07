/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* mini-xv6, step 3, on the Pi 1 by ix's tools (plan_kernel_mini_ml.md,
 * step 9): the machine as Main.ml sees it, by mini-cc, over mini-ml's
 * runtime; ../machine.c is the same for gcc over ocaml-light's, and
 * pi4/machine.c the Pi 4's. Step 2's, and the processes: each a slot
 * with a trap frame, a kernel stack, and a context that swtch saves
 * and restores.
 *
 * The runtime's view of the stacks. For ocaml-light's collector a
 * stack is five globals, saved and put back at each switch, and a hook
 * walks the stacks that do not run (../machine.c). For mini-ml's, the
 * values a function keeps are on the value stack, not the machine's:
 * a process has its own (vstacks), given to the runtime once
 * (ml_stack), and a switch tells it which one runs (ml_stack_switch:
 * the top and the exception handler of each are the runtime's to
 * keep). The collector scans them all; no hook, nothing to walk. The
 * register that holds the top in ML's code is swtch's to keep (l.s).
 * The runtime's stack 0 is the boot's, the scheduler's here; a
 * process's slot i is its stack i + 1. */

#include <mlvalues.h>
#include <callback.h>

#define NPROC 8
#define KSTACK 16384
#define VSTACK 8192		/* words */

/* the runtime's */
extern void ml_stack(int, value*);
extern void ml_stack_switch(int);
/* l.s's */
extern void user_return(void);
extern void vectors_install(void);
extern void halt(void);
/* user.s's */
extern void user_main(void);

/* the trap frames (xv6 arm-pi1's 17 words: r0-r12, sp, lr, pc, the
 * status); l.s uses the running process's, and Main.ml reads it */
static uint trapframes[NPROC][17];
uint *cur_tf;

/* a context: the stack pointer, the link, the value stack's top (swtch) */
typedef struct Context Context;
struct Context {
	uint sp;
	uint lr;
	uint vsp;
};
extern void swtch(Context *from, Context *to);

/* the processes' slots, and one more: the scheduler's, on the boot stack */
static Context contexts[NPROC + 1];
static char kstacks[NPROC][KSTACK];
static value vstacks[NPROC][VSTACK];
static char ustacks[NPROC][4096];
static int current = NPROC;

/*****************************************************************************/
/* The primitives */
/*****************************************************************************/

value mem_get8(value a) { return Val_long(*(uchar*)Long_val(a)); }
value mem_get32(value a) { return Val_long(*(uint*)Long_val(a)); }
value mem_set32(value a, value v) { *(uint*)Long_val(a) = Long_val(v); return Val_unit; }

/* the running process's registers, as Main.ml reads them */
value trapframe_addr(value unit) { return Val_long((uintptr)trapframes[current]); }

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

/* back to user mode, from the running process's trap frame: from its
 * kernel stack, which the next trap finds where it is left */
value user_resume(value unit) { user_return(); return unit; }

/*****************************************************************************/
/* The processes */
/*****************************************************************************/

/* a new process's first run, on its kernel stack and its value stack,
 * both empty: OCaml entered by a callback to "process_start", which
 * enters user mode */
static void
trampoline(void)
{
	static value *start;

	if(start == nil)
		start = caml_named_value("process_start");
	callback(*start, Val_long(current));
	halt();			/* process_start never returns */
}

/* slot p: a process to start at pc with the user stack sp */
value
proc_init(value p, value pc, value sp)
{
	int i, k;

	i = Long_val(p);
	for(k = 0; k < 17; k++)
		trapframes[i][k] = 0;
	trapframes[i][13] = Long_val(sp);
	trapframes[i][15] = Long_val(pc);
	trapframes[i][16] = 0x10 | 0x80 | 0x40;	/* USR, I and F masked */
	contexts[i].sp = (uintptr)(kstacks[i] + KSTACK) & ~(uintptr)7;
	contexts[i].lr = (uintptr)trampoline;
	contexts[i].vsp = 0;
	ml_stack(i + 1, vstacks[i]);
	vectors_install();
	return Val_unit;
}

/* from the running slot to another (a process, or NPROC the
 * scheduler); returns when something switches back */
value
k_swtch(value to)
{
	int from, t;

	from = current;
	t = Long_val(to);
	current = t;
	if(t < NPROC)
		cur_tf = trapframes[t];
	ml_stack_switch(t < NPROC ? t + 1 : 0);
	swtch(&contexts[from], &contexts[t]);
	return Val_unit;
}

value k_current(value unit) { return Val_long(current); }

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

/* from user mode, a system call: the kernel's OCaml handler, on the
 * process's kernel stack. It may switch to others before it returns */
void
trap(void)
{
	static value *handler;

	if(handler == nil)
		handler = caml_named_value("trap");
	callback(*handler, Val_unit);
}

/* the user program's entry (user.s), and a user stack per slot */
value user_entry(value unit) { return Val_long((uintptr)user_main); }
value user_stack(value p) { return Val_long((uintptr)(ustacks[Long_val(p)] + 4096)); }
