/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A process of mini-singularity: the system under its C library and
 * its run-time system (lib_core/libc, mini-ml's runtime.c, built as
 * for Linux), which reach it through one function, _syscall6. As the
 * kernel's own machine/shim.c, but here the system is the kernel's ABI
 * (Abi: the same numbers), called through the address the kernel gave
 * at the start: write is the debug line, exit the process's end, the
 * others say ENOSYS. */
#include <mlvalues.h>

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

/* Abi's: the two the C library's calls become */
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

/* A call: its number and its arguments, words the kernel reads here,
 * and where it leaves an answer's second word and the next. */
enum { WORDS = 8 };
static word words[WORDS];

static word
abi(word n, word a1, word a2, word a3, word a4)
{
	words[0] = n;
	words[1] = a1;
	words[2] = a2;
	words[3] = a3;
	words[4] = a4;
	return sip_abi(words);
}

word
_syscall6(word n, word a1, word a2, word a3, word a4, word a5, word a6)
{
	switch((int)n){
	case WRITE:	/* any descriptor is the debug line */
		return abi(ABI_DEBUG, a2, a3, 0, 0);
	case EXIT:
	case EXIT_GROUP:
		abi(ABI_EXIT, a1, 0, 0, 0);
	}
	return -38;
}

/* the same, for the calls whose answer is 64 bits (lseek) */
word
_syscall6v(word n, word a1, word a2, word a3, word a4, word a5, word a6)
{
	return _syscall6(n, a1, a2, a3, a4, a5, a6);
}

/* Sip's: a call of integers; one whose first argument is the address
 * of a string's or of bytes' first one (nothing is allocated before
 * the kernel returns: they do not move); a word of the last answer */
value
sip_call(value n, value a1, value a2, value a3, value a4)
{
	return Val_long(abi(Long_val(n), Long_val(a1), Long_val(a2), Long_val(a3), Long_val(a4)));
}

value
sip_call_s(value n, value s, value a2, value a3, value a4)
{
	return Val_long(abi(Long_val(n), (word)String_val(s), Long_val(a2), Long_val(a3), Long_val(a4)));
}

value sip_word(value i) { return Val_long(words[Long_val(i)]); }

/* start_*.s's: the run-time system's main, which ends by exit */
void
sip_main(void)
{
	static char *argv[] = { "sip", nil };

	main(1, argv);
	for(;;)
		abi(ABI_EXIT, 0, 0, 0, 0);
}
