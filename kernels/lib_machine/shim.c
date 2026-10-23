/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* Linux, in a kernel built by ix's tools (plan_kernel_mini_ml.md,
 * decision 8): the C library (lib_core/libc, goken's) and mini-ml's
 * runtime reach the system through one function, _syscall6 (the
 * number, six arguments, the kernel's answer). Here the system is two
 * calls: write, to the PL011 where the board maps it (board.h), and
 * exit, the end; the others say ENOSYS. step0's shim.c, for a kernel
 * with its MMU on. libc.c is the same thing for the Makefile's build:
 * a C library for ocaml-light's runtime, by gcc. */
#include <u.h>
#include <libc.h>
#include "board.h"

extern void halt(void);

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

static void
uart(int c)
{
	uint *u;

	u = (uint*)UART_BASE;
	while(u[6] & 0x20)	/* FR, at 0x18: the transmit FIFO full */
		;
	u[0] = c;
}

/* (a number is a long for the library, a word for the runtime: its low half) */
word
_syscall6(word n, word a1, word a2, word a3, word a4, word a5, word a6)
{
	char *s;
	word i;

	switch((int)n){
	case WRITE:	/* any descriptor is the console */
		s = (char*)a2;
		for(i = 0; i < a3; i++)
			uart(s[i]);
		return a3;
	case EXIT:
	case EXIT_GROUP:
		halt();
	}
	return -38;
}

/* the same, for the calls whose answer is 64 bits (lseek) */
word
_syscall6v(word n, word a1, word a2, word a3, word a4, word a5, word a6)
{
	return _syscall6(n, a1, a2, a3, a4, a5, a6);
}

/* claude: how far the kernel's own memory goes, and how far it may
 * (physical addresses: machine.c's heap_top and heap_limit, libc.c's
 * for the Makefile's build). The heap here is mini-ml's runtime's, two
 * arrays in the image's own data: the kernel's memory ends where the
 * image does. And that may be above board.h's HEAP_LIMIT (the Pi 1's 96
 * MB, chosen for ocaml-light's heap, which grows from a small image;
 * this one ends near 112 MB): the processes' pages, which start at the
 * limit (Arch.pages), then start at the megabyte after the image, not
 * inside it. */
extern char end[];
ulong
kernel_heap_top(void)
{
	return (ulong)end - KERNBASE;
}

ulong
kernel_heap_limit(void)
{
	ulong top, limit;

	top = (kernel_heap_top() + 0xfffff) & ~0xfffffUL;
	limit = (ulong)HEAP_LIMIT - KERNBASE;
	return top > limit ? top : limit;
}

/* claude: memmove and memcpy by words, libc.c's (the C library's,
 * Plan 9's, are a byte at a time): this object is linked before the
 * library, whose memmove.c is then not taken */
#define MWORD uintptr
#define MSIZE ulong
#define HOST_MOVE(d, s, n)
#include "move.c"
