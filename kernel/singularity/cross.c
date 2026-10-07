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
 * data, found from its static base. The machine's stack is shared for
 * now: a process runs on its caller's. */
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
extern uintptr sip_nimages;

value sip_count(value unit) { (void)unit; return Val_long(sip_nimages); }
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

/* the call being served: its words, in the caller's memory */
static uintptr *args;
/* the process asked to end: left once the kernel's ML has returned,
 * its value stack and its handler as they were at sip_run */
static int leaving;

/* a process's first instruction is its image's first, at [pa]; back
 * here when it ends */
value
sip_run(value pa)
{
	leaving = 0;
	sip_enter((void*)(Long_val(pa) + KERNBASE));
	return Val_unit;
}

value sip_exit(value unit) { (void)unit; leaving = 1; return Val_unit; }

/* abi_entry's: the kernel's static base and value stack are back */
uintptr
abi_dispatch(uintptr *a)
{
	static value *handler;
	value r;

	if(handler == nil)
		handler = caml_named_value("abi");
	args = a;
	r = callback(*handler, Val_unit);
	if(leaving)
		sip_leave();
	return Long_val(r);
}

/* word i as an integer; n bytes at the address word i is, copied */
value abi_arg(value i) { return Val_long(args[Long_val(i)]); }

value
abi_bytes(value i, value n)
{
	value s;

	s = alloc_string(Long_val(n));
	memmove(String_val(s), (void*)args[Long_val(i)], Long_val(n));
	return s;
}
