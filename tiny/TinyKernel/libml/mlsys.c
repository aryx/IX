// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// An ML program of TinyKernel.ml (tiny-ml; tiny-windows is the
// first): TinyML's runtime, given the partition's memory, and the
// system calls as the externals an ML program declares (their values
// ML's: an integer n is 2n+1, a string its bytes and its length).
//
// The partition: the program from 0; the value stack at 0x60000, or
// after the program when it is larger (end.tm's _end, linked last:
// tiny-ml's 541 KB; old: the Makefile refused a program past 384 KB),
// 64 KB, or a sixteenth of a partition larger than 1 MB; the heap's
// two halves after it, as large
// as the partition allows; the last 64 KB for C's stack and the
// arguments. In the usual 1 MB, the halves are 256 KB each. A program
// linked as an a.out that asks for more memory (tiny-linker -a) gets
// bigger halves, and a deeper stack (cc's recursions over a file's
// tokens: 1 MB of its 16). The heap uses the whole half from
// the start: starting small and growing made it collect often while it
// grew, a quarter of the browser's time (plan_tiny_browser.md).
//
// The partition's size is found from the arguments: exec puts them at
// its top, so the partition ends at the first megabyte boundary above
// argv (partitions are whole megabytes).
#include "../../TinyMLRuntime/core.c"
#include "../libc/user.h"

#define VSTACK 0x60000

// the program's end (end.tm)
extern char _end[];

// the program's arguments, for u_argc and u_arg
int u_nargs;
char **u_args;

void
main(int argc, char **argv)
{
	long top, vstack, vsize, heap0, half;

	u_nargs = argc;
	u_args = argv;
	top = ((long)argv + 0xfffff) & ~0xfffff;
	vstack = ((long)_end + 0xffff) & ~0xffff;
	if(vstack < VSTACK)
		vstack = VSTACK;
	vsize = top / 16;
	if(vsize < 0x10000)
		vsize = 0x10000;
	// (what a few frames push between two allocations)
	ml_vlimit = (value*)(vstack + vsize - 0x1000);
	heap0 = vstack + vsize;
	half = (top - heap0 - 0x10000) / 2 / 4;		// in words
	ml_run((value*)vstack, (value*)heap0, (value*)(heap0 + half * 4),
		half, half);
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

value
u_time(value unit)
{
	return time() * 2 + 1;
}

value
u_seed(value unit)
{
	return seed() * 2 + 1;
}

// the path's entry (user.h's dirent, its 80 bytes) as a string, or ""
// when it is not there
value
u_stat(value path)
{
	value s;

	push(path);
	s = string_alloc(sizeof(struct dirent));
	path = pop();
	if(stat((char*)path, (struct dirent*)s) < 0)
		return string_alloc(0);
	return s;
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

// what a tool asks for (TinyLibSystem.ml, tiny-shell's): the
// program's arguments, a string each
value
u_argc(value unit)
{
	return u_nargs * 2 + 1;
}

value
u_arg(value i)
{
	char *a;
	value s;
	int n, k;

	a = u_args[i >> 1];
	n = strlen(a);
	s = string_alloc(n);
	for(k = 0; k < n; k++)
		((uchar*)s)[k] = a[k];
	return s;
}

value
u_flush(value unit)
{
	flush();
	return unit;
}

value
u_open(value path, value flags)
{
	return open((char*)path, flags >> 1) * 2 + 1;
}

// a connection to a port of the machine at an address ("10.0.0.1"):
// user.h's dial, -1 without a network or when nothing answers there
value
u_dial(value address, value port)
{
	return dial((char*)address, port >> 1) * 2 + 1;
}

value
u_seek(value fd, value n, value whence)
{
	return seek(fd >> 1, n >> 1, whence >> 1) * 2 + 1;
}

value
u_dup(value fd)
{
	return dup(fd >> 1) * 2 + 1;
}

value
u_chdir(value path)
{
	return chdir((char*)path) * 2 + 1;
}

// a new directory, a name removed (a directory only if empty): 0, or -1
value
u_mkdir(value path)
{
	return mkdir((char*)path) * 2 + 1;
}

value
u_unlink(value path)
{
	return unlink((char*)path) * 2 + 1;
}

value
u_link(value old, value new)
{
	return link((char*)old, (char*)new) * 2 + 1;
}

// the current directory's path, as a string
value
u_getcwd(value unit)
{
	value s;
	int n, k;

	n = getcwd(u_buf, sizeof u_buf);
	if(n < 0)
		n = 0;
	s = string_alloc(n);
	for(k = 0; k < n; k++)
		((uchar*)s)[k] = u_buf[k];
	return s;
}

value
u_rawcons(value on)
{
	return rawcons(on >> 1) * 2 + 1;
}

value
u_getpid(value unit)
{
	return getpid() * 2 + 1;
}

value
u_fork(value unit)
{
	return fork() * 2 + 1;
}

// the program at path, its arguments an ML list of strings (a cell is
// a block of two words, the end is not a block; a string ends by a 0;
// 63 at most, the kernel's limit); it returns only when it failed: -1,
// as for more (old: 15, the ones after them left out unsaid; ld's
// lines for a program in ML have 30)
value
u_exec(value path, value args)
{
	char *argv[64];
	int n;

	for(n = 0; n < 63 && (args & 1) == 0; n++){
		argv[n] = (char*)((value*)args)[0];
		args = ((value*)args)[1];
	}
	if((args & 1) == 0)
		return -1 * 2 + 1;
	argv[n] = 0;
	return exec((char*)path, argv) * 2 + 1;
}

// a child's end waited for: its pid and, 256 times it, its status's
// low byte; -1 without children
value
u_waits(value unit)
{
	int pid, status;

	if((pid = wait(&status)) < 0)
		return -1;
	return (pid * 256 + (status & 255)) * 2 + 1;
}
