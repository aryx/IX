/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* TinyLib's C library: runtime.c includes it, first. What the runtime
 * asks, and no more: Linux's calls by their number (no wrapper of a
 * system-neutral name, as lib_core/libc's Plan 9 ones over Linux),
 * the environment the kernel left on the stack, memory given and
 * never taken back, bytes and strings, floor, and fmt.c (numbers
 * printed and read: lib_core/libc/ix/fmt.c, as it is). */

/* Linux's numbers: arm64's, or arm's */
#define SYS(n64, n32) (sizeof(intptr) == 8 ? (n64) : (n32))

long read(int fd, void *buf, long n) { return _syscall6(SYS(63, 3), fd, (intptr)buf, n, 0, 0, 0); }
long write(int fd, void *buf, long n) { return _syscall6(SYS(64, 4), fd, (intptr)buf, n, 0, 0, 0); }
int close(int fd) { return _syscall6(SYS(57, 6), fd, 0, 0, 0, 0, 0); }

/* exit_group: the process, with nothing run first (the runtime has
 * flushed its channels) */
void
exit(int n)
{
	_syscall6(SYS(94, 248), n, 0, 0, 0, 0, 0);
}

/* The environment: "NAME=value" strings, an array ended by a nil,
 * right after argv's own nil on the first stack (start.s keeps argv
 * and argc). The value is in place: not to be freed, nor written. */
char **_mainargv;
intptr _mainargc;

char*
getenv(char *name)
{
	char **e, *p, *q;

	if(_mainargv == nil)
		return nil;
	for(e = _mainargv + _mainargc + 1; *e != nil; e++){
		/* the name must end at the '=': "PATH" is not "PATHEXT=..." */
		for(p = *e, q = name; *q != 0 && *p == *q; p++, q++)
			;
		if(*q == 0 && *p == '=')
			return p + 1;
	}
	return nil;
}

/* Memory from one array, a block after the other; free does nothing.
 * The runtime asks for a channel's buffer and an exec's arrays: its
 * own heap is its own (gc.c). Not initialized, so in the bss: pages
 * the kernel gives when they are touched. */
enum { Heap = 16*1024*1024 };
static char heap[Heap];
static char *heapnext = heap;

void*
malloc(ulong n)
{
	char *p;

	/* 8 bytes: a vlong in the block is aligned */
	n = (n + 7) & ~7UL;
	if(heapnext + n > heap + Heap){
		write(2, "Fatal error: out of C memory\n", 29);
		exit(2);
	}
	p = heapnext;
	heapnext += n;
	return p;
}

void
free(void *p)
{
	USED(p);
}

/* (the two may overlap) */
void*
memmove(void *to, void *from, ulong n)
{
	char *t, *f;

	t = to;
	f = from;
	if(t <= f)
		while(n-- > 0)
			*t++ = *f++;
	else{
		t += n;
		f += n;
		while(n-- > 0)
			*--t = *--f;
	}
	return to;
}

int
memcmp(void *a, void *b, ulong n)
{
	uchar *p, *q;

	for(p = a, q = b; n > 0; n--, p++, q++)
		if(*p != *q)
			return *p < *q ? -1 : 1;
	return 0;
}

long
strlen(char *s)
{
	char *p;

	for(p = s; *p != 0; p++)
		;
	return p - s;
}

int
atoi(char *s)
{
	int n, neg;

	while(*s == ' ' || *s == '\t')
		s++;
	neg = *s == '-';
	if(*s == '-' || *s == '+')
		s++;
	for(n = 0; *s >= '0' && *s <= '9'; s++)
		n = n * 10 + (*s - '0');
	return neg ? -n : n;
}

/* the largest integer not above d (a NaN, an infinity and a float too
 * large to have a fraction as they are) */
double
floor(double d)
{
	vlong i;

	if(d != d || d >= 9007199254740992.0 || d <= -9007199254740992.0)
		return d;
	i = (vlong)d;
	if((double)i > d)
		i--;
	return (double)i;
}

#include "fmt.c"
