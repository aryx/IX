/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* mini-singularity: the crossing, the kernel's side (decision 3 of
 * plan_system_singularity.md). A process is another mini-ml program in
 * the kernel's address space, at the kernel's privilege: it is entered
 * by a call (sip_enter) and calls the kernel by one (abi_entry, whose
 * address it is given at its start). No reference crosses: a call's
 * words are integers, and the bytes they point at are copied.
 *
 * What a crossing keeps, and why no more. Each program has its own
 * static base (R12, R28: mini-ld's setR12, setSB) and its own value
 * stack, whose top its ML code holds in a register (R10, R26: mini-ml's
 * Gen) that C never touches and ML's code expects back after a call of
 * C. Those two are saved and set by the board's cross_*.s. The rest is
 * the callee's to lose, by 5c's and 7c's convention; the exception
 * handler, the heap and the collector's roots are each program's own
 * data, found from its static base. The machine's stack is switched
 * too: a process's code runs on a stack in its own memory, the kernel's
 * for it on a kernel stack (below). */
#include <mlvalues.h>
#include <callback.h>
#include <alloc.h>
#include "board.h"

extern void sip_enter(void*);
extern void sip_leave(void);

/* the programs in the image (the mkfile's images.s): four words each,
 * the pristine copy's address, its bytes, the address it is linked at,
 * its slot's bytes. A program's second word is its end's address (its
 * bss's: lib/start_*.s) */
extern uintptr sip_images[];

value sip_image_base(value i) { return Val_long(sip_images[4 * Long_val(i)] - KERNBASE); }
value sip_image_size(value i) { return Val_long(sip_images[4 * Long_val(i) + 1]); }
value sip_image_addr(value i) { return Val_long(sip_images[4 * Long_val(i) + 2] - KERNBASE); }
value sip_image_slot(value i) { return Val_long(sip_images[4 * Long_val(i) + 3]); }
/* the memory a program takes, from its first byte to its bss's last */
value
sip_image_extent(value i)
{
	uintptr *image;

	image = (uintptr*)sip_images[4 * Long_val(i)];
	return Val_long(image[1] - sip_images[4 * Long_val(i) + 2]);
}

/* A process's thread in the kernel is a slot of machine/runtime.c
 * (mini-xv6's: a kernel stack and a value stack each, k_swtch between
 * them). What a crossing adds for each: where its kernel stack was
 * left when it entered its program, where its program's was when it
 * called the kernel (cross_*.s: the first two words), and the call it
 * is in. */
#define NPROC 64
struct sip {
	uintptr ksp;
	uintptr psp;
	uintptr *args;	/* the call's words, in the caller's memory */
};
static struct sip sips[NPROC];
struct sip *sip_cur;	/* the running one's: cross_*.s's */
/* the process asked to end: left once the kernel's ML has returned,
 * its value stack and its handler as they were at sip_run */
static int leaving;

extern value k_current(value);
static struct sip *running(void) { return &sips[Long_val(k_current(Val_unit))]; }

/* a process's first instruction is its image's first, at [pa]; its
 * stack's top at [stack]; back here when it ends */
value
sip_run(value pa, value stack)
{
	leaving = 0;
	sip_cur = running();
	sip_cur->psp = Long_val(stack) + KERNBASE;
	sip_enter((void*)(Long_val(pa) + KERNBASE));
	return Val_unit;
}

value sip_exit(value unit) { (void)unit; leaving = 1; return Val_unit; }

/* abi_entry's: the kernel's static base is back, and the caller's
 * kernel stack. Others may have run before the callback returns: the
 * running one is said again. */
uintptr
abi_dispatch(uintptr *a)
{
	static value *handler;
	value r;

	if(handler == nil)
		handler = caml_named_value("abi");
	running()->args = a;
	r = callback(*handler, Val_unit);
	sip_cur = running();
	if(leaving){
		leaving = 0;
		sip_leave();
	}
	return Long_val(r);
}

/* word i set: an answer's second word and the next */
value abi_set(value i, value v) { running()->args[Long_val(i)] = Long_val(v); return Val_unit; }

/* n bytes from the address word i is into bytes b at off, and back */
value
abi_get(value i, value b, value off, value n)
{
	memmove(Bytes(b) + Long_val(off), (void*)running()->args[Long_val(i)], Long_val(n));
	return Val_unit;
}

value
abi_put(value i, value b, value off, value n)
{
	memmove((void*)running()->args[Long_val(i)], Bytes(b) + Long_val(off), Long_val(n));
	return Val_unit;
}

/* word i as an integer; n bytes at the address word i is, copied */
value abi_arg(value i) { return Val_long(running()->args[Long_val(i)]); }

value
abi_bytes(value i, value n)
{
	value s;

	s = alloc_string(Long_val(n));
	memmove(String_val(s), (void*)running()->args[Long_val(i)], Long_val(n));
	return s;
}

/* The time, in microseconds, its low 30 bits: the Pi 1's system timer
 * (CLO), the Pi 4's generic timer (its count over its frequency:
 * cross_arm64.s), the ones machine.c arms for its ticks. */
#ifdef arm
value sip_time(value unit) { (void)unit; return Val_long(*(uint*)(IO_BASE + 0x3004) & 0x3fffffff); }
#else
extern uvlong cntvct(void);
extern uvlong cntfrq(void);
value
sip_time(value unit)
{
	uvlong f;

	(void)unit;
	f = cntfrq();
	if(f == 0)
		return Val_long(0);
	/* (no overflow: the count's seconds, then its rest) */
	return Val_long(((cntvct() / f) * 1000000 + (cntvct() % f) * 1000000 / f) & 0x3fffffff);
}
#endif
