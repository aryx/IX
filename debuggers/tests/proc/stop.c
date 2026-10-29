/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
#include <u.h>
#include <libc.h>

/* A process stopped and looked at by its parent through its /proc, as
 * a debugger does (debuggers/tests/proc.sh; plan_debugger.md, decision
 * 12: mini-5i serves another process's files): its status, a word of
 * its memory, its registers, its memory written, started again,
 * killed. What it prints says yes or no, not the numbers of the day. */

long n;         /* the child's count */
long flag;      /* written by the parent, through the child's mem */
long seen;      /* the child saw it */

/* (ix's libc formats into a buffer only: snprint, vsnprint) */
static void
say(fdt fd, char *fmt, ...)
{
	char buf[256];
	va_list arg;

	va_start(arg, fmt);
	vsnprint(buf, sizeof buf, fmt, arg);
	va_end(arg);
	write(fd, buf, strlen(buf));
}

static void
fail(char *what)
{
	say(2, "stop: %s failed\n", what);
	exits("fail");
}

static fdt
file(int pid, char *name, int mode)
{
	char path[64];
	fdt fd;

	snprint(path, sizeof path, "/proc/%d/%s", pid, name);
	fd = open(path, mode);
	if(fd < 0)
		fail(path);
	return fd;
}

static void
ctl(int pid, char *msg)
{
	fdt fd;

	fd = file(pid, "ctl", OWRITE);
	if(write(fd, msg, strlen(msg)) != strlen(msg))
		fail(msg);
	close(fd);
}

/* a word of the child's, at the address of ours (the same program) */
static long
word(int pid, long *a)
{
	long v;
	fdt fd;

	fd = file(pid, "mem", OREAD);
	if(pread(fd, &v, sizeof v, (uintptr)a) != sizeof v)
		fail("mem");
	close(fd);
	return v;
}

void
main(void)
{
	char st[200], *s;
	ulong regs[18];
	long a, b, v;
	int pid;
	fdt fd;

	pid = fork();
	if(pid < 0)
		fail("fork");
	if(pid == 0)
		for(;;){
			n++;
			if(flag)
				seen = 1;
		}
	sleep(200);

	ctl(pid, "stop");
	fd = file(pid, "status", OREAD);
	memset(st, 0, sizeof st);
	if(read(fd, st, sizeof st - 1) < 68)
		fail("status");
	close(fd);
	st[67] = 0;
	for(s = st + 66; s > st + 56 && *s == ' '; s--)
		*s = 0;
	a = word(pid, &n);
	sleep(100);
	b = word(pid, &n);
	say(1, "stopped: %s; its count read, the same twice: %d\n", st + 56, a > 0 && a == b);

	fd = file(pid, "regs", OREAD);
	if(read(fd, regs, sizeof regs) != sizeof regs)
		fail("regs");
	close(fd);
	say(1, "its pc in main: %d\n", regs[17] >= (uintptr)main && regs[17] < (uintptr)main + 4096);

	/* (a word it only reads: one it counts in could be written over
	 * by its own store, stopped between its load and its store) */
	v = 1;
	fd = file(pid, "mem", OWRITE);
	if(pwrite(fd, &v, sizeof v, (uintptr)&flag) != sizeof v)
		fail("write mem");
	close(fd);
	ctl(pid, "start");
	sleep(100);
	ctl(pid, "stop");
	say(1, "started again, it saw the word written: %d\n", word(pid, &seen) == 1);

	ctl(pid, "kill");
	memset(st, 0, sizeof st);
	if(await(st, sizeof st - 1) < 0)
		fail("await");
	for(s = st; *s != 0 && strncmp(s, "killed", 6) != 0; s++)
		;
	say(1, "killed: %s\n", *s != 0 ? "yes" : "no");
	exits(nil);
}
