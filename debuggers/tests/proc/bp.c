/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
#include <u.h>
#include <libc.h>

/* A breakpoint and a hang, through a child's /proc, as acid sets them
 * (debuggers/tests/proc.sh; plan_debugger.md, stage 8's step 2): the
 * breakpoint instruction written at a function (5db's BKPT), the child
 * started until it stops there (ctl's startstop), its note read, its
 * instruction put back, the child gone on; then a child hung at its
 * exec (its own ctl's hang), waited for (waitstop), started. What it
 * prints says yes or no. */

long n;         /* the child's count */
long flag;      /* written by the parent: the child is to exit */

/* where the breakpoint is set */
void
tick(void)
{
	n++;
}

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
	say(2, "bp: %s failed\n", what);
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

static void
poke(int pid, uintptr a, ulong v)
{
	fdt fd;

	fd = file(pid, "mem", OWRITE);
	if(pwrite(fd, &v, sizeof v, a) != sizeof v)
		fail("write mem");
	close(fd);
}

static ulong
pc(int pid)
{
	ulong regs[18];
	fdt fd;

	fd = file(pid, "regs", OREAD);
	if(read(fd, regs, sizeof regs) != sizeof regs)
		fail("regs");
	close(fd);
	return regs[17];
}

/* whether the exit message of the next child to exit has s in it */
static int
exited(char *s)
{
	char buf[200], *p;

	memset(buf, 0, sizeof buf);
	if(await(buf, sizeof buf - 1) < 0)
		fail("await");
	for(p = buf; *p != 0; p++)
		if(strncmp(p, s, strlen(s)) == 0)
			return 1;
	return 0;
}

void
main(int argc, char **argv)
{
	char note[128];
	ulong orig;
	int pid;
	fdt fd;

	if(argc > 1 && strcmp(argv[1], "target") == 0)
		exits("hung, then started");

	pid = fork();
	if(pid < 0)
		fail("fork");
	if(pid == 0)
		for(;;){
			tick();
			if(flag)
				exits("went on");
		}
	sleep(100);
	ctl(pid, "stop");
	fd = file(pid, "mem", OREAD);
	if(pread(fd, &orig, sizeof orig, (uintptr)tick) != sizeof orig)
		fail("mem");
	close(fd);
	poke(pid, (uintptr)tick, 0xE1200070);
	ctl(pid, "startstop");
	memset(note, 0, sizeof note);
	fd = file(pid, "note", OREAD);
	if(read(fd, note, sizeof note - 1) < 0)
		fail("note");
	close(fd);
	say(1, "stopped at the breakpoint: %d; its note: %s\n", pc(pid) == (uintptr)tick, note);
	poke(pid, (uintptr)tick, orig);
	poke(pid, (uintptr)&flag, 1);
	ctl(pid, "start");
	say(1, "the instruction put back, it went on: %d\n", exited("went on"));

	pid = fork();
	if(pid < 0)
		fail("fork");
	if(pid == 0){
		ctl(getpid(), "hang");
		execl(argv[0], argv[0], "target", nil);
		fail("exec");
	}
	ctl(pid, "waitstop");
	say(1, "hung at its exec, stopped: %d\n", pc(pid) != 0);
	ctl(pid, "start");
	say(1, "started, it ran its program: %d\n", exited("hung, then started"));
	exits(nil);
}
