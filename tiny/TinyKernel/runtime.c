// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// TinyKernel.ml's runtime: TinyML's (the allocator, Cheney's collector,
// the strings, compare), given the kernel's memory; write and exit on
// the machine's devices; and the few functions of bytes the ML code
// calls as externals (its values: an integer n is 2n+1).
//
// The memory (128 MB). The kernel uses the first 32 MB: the image at 0
// and the files it carries after it (10 MB at most: the Makefile
// checks); the file system's buffers and map (TinyKernelFS.ml), 80 KB
// at 10 MB; the value stack at 11 MB; the processes' frames, and a
// packet's place; the rest unused but the speaker's ring; 2 MB of
// images, and the screen's megabyte (its 640 by 480 bytes, then images
// again); the heap's two halves of 8 MB from 16 MB to 32 MB, where a
// file written lives (a compiler's output: TinyML.ml's object is 1.3
// MB). (old: the image's limit was 2.5 MB, with the stack, the frames
// and the heap 2 MB lower, and the processes' partitions from 5 MB: the
// browser filled the image; then 4.5 MB, the rest 3 MB lower, until
// tiny-db, tiny-vcs and tiny-build came; the heap's halves were 1 MB,
// at 8 MB, until the toolchain came, plan_tiny_self_hosting.md's step
// 7; the image's limit 7.5 MB, the value stack, the frames and the
// packet below 8 MB, until its sources came, step 8.) The processes'
// partitions are above 32 MB (TinyKernel.ml). The devices are in the
// last 48 bytes, reached by negative addresses, which the machine takes
// modulo its memory size.
#include "../TinyMLRuntime/core.c"

#define VSTACK 0xb00000
#define HEAP0 0x1000000
#define HEAP1 0x1800000
#define HALF 2097152
#define CONS_OUT 0xfffffff0
#define HALT 0xfffffff4

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
