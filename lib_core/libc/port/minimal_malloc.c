/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* A stand-in for an allocator: memory is given from one array, a block
 * after the other, and free does nothing, so a program that counts on
 * freed memory fills the array and aborts. Plan 9's pool.c (principia's
 * port/pool.c) is the real one, not here yet. */

/* what a process may ask in its whole life; not initialized, so in
 * the BSS: pages the kernel gives when they are touched */
enum { HEAPSIZE = 64*1024*1024 };

static char heap[HEAPSIZE];
static char *heapnext = heap;

void*
malloc(ulong n)
{
	char *p;

	/* 8 bytes: a double or a vlong in the block is aligned */
	n = (n + 7) & ~7UL;
	if(heapnext + n > heap + HEAPSIZE)
		abort();
	p = heapnext;
	heapnext += n;
	return p;
}

void*
calloc(ulong n, ulong size)
{
	void *p;

	p = malloc(n * size);
	memset(p, 0, n * size);
	return p;
}

void
free(void *p)
{
	USED(p);
}

/* The old block's size is not known: n bytes of it are copied, the
 * new size, which reads past a smaller block (inside the array still).
 * What is past the old content is not zeroed, as POSIX's. */
void*
realloc(void *p, ulong n)
{
	void *q;

	if(p == nil)
		return malloc(n);
	q = malloc(n);
	memcpy(q, p, n);
	return q;
}

/* a tag is who allocated a block, for debugging: nowhere to keep it */
void
setmalloctag(void *v, ulong pc)
{
	USED(v);
	USED(pc);
}

ulong
getmalloctag(void *v)
{
	USED(v);
	return 0;
}

ulong
getrealloctag(void *v)
{
	USED(v);
	return 0;
}
