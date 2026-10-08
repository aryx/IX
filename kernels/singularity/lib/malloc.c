/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* mini-singularity: malloc, for the kernel and for each process (one
 * of these in each program: its own arena). */
#include <u.h>
#include <libc.h>

/* The C library's malloc is 64 MB of bss, never given back (its
 * minimal_malloc.c); a process's memory is its slot, and the kernel's
 * is below the exchange heap: here what the run-time system asks it
 * for, its channels' buffers, as small. All of that file's names, so
 * that it is not linked. A block's bytes are in the word before it
 * (realloc's). */
enum { ARENA = 64 * 1024 };
static uintptr arena[ARENA / sizeof(uintptr)];
static ulong used;	/* words */

void*
malloc(ulong n)
{
	uintptr *p;
	ulong words;

	words = 1 + (n + sizeof(uintptr) - 1) / sizeof(uintptr);
	if(used + words > nelem(arena))
		return nil;
	p = arena + used;
	used += words;
	p[0] = n;
	return p + 1;
}

void*
calloc(ulong n, ulong size)
{
	return malloc(n * size);	/* (the bss: zeros, and nothing is given back) */
}

void
free(void *p)
{
	USED(p);
}

void*
realloc(void *p, ulong n)
{
	void *q;
	ulong old;

	q = malloc(n);
	if(p != nil && q != nil){
		old = ((uintptr*)p)[-1];
		memmove(q, p, old < n ? old : n);
	}
	return q;
}

void setmalloctag(void *v, ulong pc) { USED(v); USED(pc); }
ulong getmalloctag(void *v) { USED(v); return 0; }
ulong getrealloctag(void *v) { USED(v); return 0; }
