/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* Linux, on the bare Pi 4 or Pi 1 (plan_kernel_mini_ml.md, decision
 * 8): the C library (lib_core/libc, goken's) and mini-ml's runtime
 * reach the system through one function, _syscall6 (svc_arm64.s's or
 * svc_arm.s's: the number, six arguments, the kernel's answer). Here
 * it is C, and the system is two calls: write, to the PL011, and exit,
 * the end. The others say ENOSYS, as a kernel that does not have them. */
#include <u.h>
#include <libc.h>

/* the board's PL011, Linux's numbers and a call's word, for arm (the
 * Pi 1) and arm64 (the Pi 4) */
#ifdef arm
#define UART 0x20201000
#define WRITE 4
#define EXIT 1
#define EXIT_GROUP 248
typedef long word;
#else
#define UART 0xFE201000
#define WRITE 64
#define EXIT 93
#define EXIT_GROUP 94
typedef vlong word;
#endif

extern void halt(void);

static void
uart(int c)
{
	uint *u;

	u = (uint*)UART;
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
