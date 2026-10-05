/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* TinyML's runtime, compiled by tiny-c: TinyML_core.c (the allocator
 * and Cheney's copying collector, the primitives the prelude names,
 * stdout's buffer, the uncaught exception), and main, which gives it
 * the memory.
 */
#include "TinyML_core.c"

extern char *getenv(char*);
extern int atoi(char*);

static value vstack[1 << 22];  /* 32MB, in the bss, not malloc's 64MB */
#define MAXHEAP 8388608       /* words, a half's */
static value space0[MAXHEAP];
static value space1[MAXHEAP];

/* the heap's halves are the bss's, as big as it can be, the part in
 * use growing (goken's malloc is a bump allocator of 64MB whose free
 * is a no-op, and its sbrk fails under Linux's ASLR: bugs/goken.md) */
void
main(int argc, char *argv[])
{
	char *s;
	value n;

	n = 1 << 18;
	s = getenv("ML_HEAP");
	if(s != 0)
		n = atoi(s);
	ml_run(vstack, space0, space1, MAXHEAP, n);
	flush();
	exit(0);
}
