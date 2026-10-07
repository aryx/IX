/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A process of mini-singularity: the system under its C library and
 * its run-time system (lib_core/libc, mini-ml's runtime.c, built as
 * for Linux), which reach it through one function, _syscall6. As the
 * kernel's own machine/shim.c, but here the system is the kernel's ABI
 * (Abi: the same numbers), called through the address the kernel gave
 * at the start: write is the debug line, exit the process's end, the
 * others say ENOSYS. */
#include <u.h>
#include <libc.h>

/* Linux's numbers and a call's word, for arm (the Pi 1) and arm64 (the Pi 4) */
#ifdef arm
#define WRITE 4
#define EXIT 1
#define EXIT_GROUP 248
typedef long word;
#else
#define WRITE 64
#define EXIT 93
#define EXIT_GROUP 94
typedef vlong word;
#endif

/* Abi's */
enum { ABI_EXIT = 0, ABI_DEBUG = 1 };

extern void main(int, char**);
extern word sip_abi(word*);
/* the kernel's entry (start_*.s) */
uintptr sip_kernel;

/* The C library's malloc is 64 MB of bss, never given back (its
 * minimal_malloc.c), and a process's memory is its slot: here what the
 * run-time system asks it for, its channels' buffers, as small. All of
 * that file's names, so that it is not linked. A block's bytes are in
 * the word before it (realloc's). */
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

/* a call: its number and its arguments, words the kernel reads here */
static word
abi(word n, word a1, word a2)
{
	word a[3];

	a[0] = n;
	a[1] = a1;
	a[2] = a2;
	return sip_abi(a);
}

word
_syscall6(word n, word a1, word a2, word a3, word a4, word a5, word a6)
{
	switch((int)n){
	case WRITE:	/* any descriptor is the debug line */
		return abi(ABI_DEBUG, a2, a3);
	case EXIT:
	case EXIT_GROUP:
		abi(ABI_EXIT, a1, 0);
	}
	return -38;
}

/* the same, for the calls whose answer is 64 bits (lseek) */
word
_syscall6v(word n, word a1, word a2, word a3, word a4, word a5, word a6)
{
	return _syscall6(n, a1, a2, a3, a4, a5, a6);
}

/* start_*.s's: the run-time system's main, which ends by exit */
void
sip_main(void)
{
	static char *argv[] = { "sip", nil };

	main(1, argv);
	for(;;)
		abi(ABI_EXIT, 0, 0);
}
