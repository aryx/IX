// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// An ML program of TinyKernel.ml (tiny-ml -tm; tiny-windows is the
// first): TinyML's runtime, given the partition's memory, and the
// system calls as the externals an ML program declares (their values
// ML's: an integer n is 2n+1, a string its bytes and its length).
//
// The partition (1 MB): the program from 0, under 384 KB (the Makefile
// checks); the value stack at 0x60000; the heap's two halves, 256 KB
// each, from 0x70000; C's stack from the top.
#include "../../TinyML/core.c"
#include "user.h"

#define VSTACK 0x60000
#define HEAP0 0x70000
#define HEAP1 0xb0000
#define HALF 65536

void
main(void)
{
	ml_run((value*)VSTACK, (value*)HEAP0, (value*)HEAP1, HALF, HALF);
	flush();
	exit(0);
}

// up to n bytes of fd (4096 at most), as a string: "" at its end
char u_buf[4096];

value
u_read(value fd, value n)
{
	value s;
	int k, i;

	n = n >> 1;
	if(n > sizeof u_buf)
		n = sizeof u_buf;
	k = read(fd >> 1, u_buf, n);
	if(k < 0)
		k = 0;
	s = string_alloc(k);
	for(i = 0; i < k; i++)
		((uchar*)s)[i] = u_buf[i];
	return s;
}

// all of s, in pieces when fd is a pipe; -1 if it is refused
value
u_write(value fd, value s)
{
	int n, k, done;

	n = length(s);
	for(done = 0; done < n; done += k)
		if((k = write(fd >> 1, (char*)s + done, n - done)) <= 0)
			return -1;
	return 1;
}

// a pipe, a box: the reading end, and 256 times the writing one; -1
value
u_pipe(value unit)
{
	int fds[2];

	if(pipe(fds) < 0)
		return -1;
	return (fds[0] + 256 * fds[1]) * 2 + 1;
}

value
u_box(value unit)
{
	int fds[2];

	if(box(fds) < 0)
		return -1;
	return (fds[0] + 256 * fds[1]) * 2 + 1;
}

value
u_close(value fd)
{
	return close(fd >> 1) * 2 + 1;
}

// the first of the array's first n descriptors that can be read; -1
// at until
value
u_ready(value fds, value n, value until)
{
	int a[32], i;

	n = n >> 1;
	for(i = 0; i < n && i < 32; i++)
		a[i] = ((value*)fds)[i] >> 1;
	return ready(a, i, until >> 1) * 2 + 1;
}

value
u_ticks(value unit)
{
	return ticks() * 2 + 1;
}

// a program run with the five descriptors a window's has: in its 0,
// out its 1 and 2, draw its 3, mouse its 4, and none of the caller's
// others; its pid, or -1. (The lowest free descriptor is the one just
// closed: Unix's way, as sh's.)
value
u_spawn(value in, value out, value draw, value mouse, value path)
{
	char *argv[2];
	int pid, i;

	if((pid = fork()) != 0)
		return pid * 2 + 1;
	for(i = 0; i < 5; i++)
		close(i);
	dup(in >> 1);
	dup(out >> 1);
	dup(out >> 1);
	dup(draw >> 1);
	dup(mouse >> 1);
	for(i = 5; i < 32; i++)
		close(i);
	argv[0] = (char*)path;
	argv[1] = 0;
	exec((char*)path, argv);
	exit(1);
	return 1;
}

value
u_kill(value pid)
{
	return kill(pid >> 1) * 2 + 1;
}

// a child's end waited for; its pid, or -1 without children
value
u_wait(value unit)
{
	return wait(0) * 2 + 1;
}
