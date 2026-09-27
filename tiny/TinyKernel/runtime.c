// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// TinyKernel.ml's runtime: TinyML's (the allocator, Cheney's collector,
// the strings, compare), given the kernel's memory; write and exit on
// the machine's devices; and the few functions of bytes the ML code
// calls as externals (its values: an integer n is 2n+1).
//
// The memory (16 MB): the image at 0, the files it carries after it;
// the value stack at 1 MB; the processes' frames; the heap's two halves
// from 2 MB to 5 MB; then ten partitions of 1 MB, a process each
// (TinyKernel.ml); the devices in the last 32 bytes.
#include "../TinyML_core.c"

#define VSTACK 0x100000
#define HEAP0 0x200000
#define HEAP1 0x380000
#define HALF 393216
#define CONS_OUT 0xfffff0
#define HALT 0xfffff4

long
write(int fd, void *buf, long n)
{
	char *p;
	long i;

	p = buf;
	for(i = 0; i < n; i++)
		*(char*)CONS_OUT = p[i];
	return n;
}

void
exit(int status)
{
	*(int*)HALT = status;
}

// entry.tm's _entry: the whole of the heap at once (it does not grow),
// then the kernel, TinyKernel.ml's toplevel, which never returns
void
kmain(void)
{
	ml_run((value*)VSTACK, (value*)HEAP0, (value*)HEAP1, HALF, HALF);
}

// memory by word and by byte, at a physical address
value
peek(value a)
{
	return *(int*)(a >> 1) * 2 + 1;
}

value
poke(value a, value v)
{
	*(int*)(a >> 1) = v >> 1;
	return 1;
}

value
peekb(value a)
{
	return (*(uchar*)(a >> 1)) * 2 + 1;
}

value
pokeb(value a, value v)
{
	*(uchar*)(a >> 1) = v >> 1;
	return 1;
}

// n bytes of memory at a, as a string (a write's data)
value
k_string(value a, value n)
{
	value s;
	value i;
	uchar *p;

	s = string_alloc(n >> 1);
	p = (uchar*)(a >> 1);
	for(i = 0; i < n >> 1; i++)
		((uchar*)s)[i] = p[i];
	return s;
}

// s's n bytes from off to memory at a (a read's, a program's)
value
k_blit(value s, value off, value a, value n)
{
	value i;
	uchar *p;
	uchar *q;

	p = (uchar*)s + (off >> 1);
	q = (uchar*)(a >> 1);
	for(i = 0; i < n >> 1; i++)
		q[i] = p[i];
	return 1;
}

// the console's output: n bytes at a
value
k_console(value a, value n)
{
	write(1, (void*)(a >> 1), n >> 1);
	return 1;
}
