/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* Plan 9's, by principia and goken (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* sbrk: n more bytes of heap, and where they start. After principia's
 * 9sys/sbrk.c, over brk, the kernel's call (Plan 9's is this shape;
 * no Linux program of ix asks it). bloc is where the last block ended:
 * the kernel only knows the limit. It starts at end, the linker's
 * symbol for the end of the BSS. */

extern char end[];

static char *bloc = { end };

enum
{
	Round	= 7
};

void*
sbrk(ulong n)
{
	uintptr bl;

	bl = ((uintptr)bloc + Round) & ~(uintptr)Round;

	/* not principia's: a huge n wraps around to a low address, and
	 * brk to a low address is a shrink, which succeeds (an emulator's
	 * brk does not refuse it either). On 32 bits only: n is a ulong. */
	if(bl + n < bl)
		return (void*)-1;
	if(brk((void*)(bl+n)) < 0)
		return (void*)-1;
	bloc = (char*)bl + n;
	return (void*)bl;
}
