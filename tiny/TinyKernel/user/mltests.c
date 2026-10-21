// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// TinyKernel.ml's tests, each a line "... ok", or what went wrong: fork
// and wait's statuses, exec's arguments, pipes (a child writer, the
// end seen when no writer is left, a big write in pieces), files,
// directories and "..", a fault killed, the preemption, a process
// traced.
#include "../libc/user.h"

char buf[2048];
int failed;
char *argv[] = { "echo", "one", "two", 0 };

void
fail(char *what)
{
	print("mltests: %s FAILED\n", what);
	failed = 1;
}

void
forks(void)
{
	int pid, st, i;

	for(i = 0; i < 3; i++){
		if((pid = fork()) == 0)
			exit(10 + i);
		if(pid < 0)
			{ fail("fork"); return; }
	}
	st = 0;
	for(i = 0; i < 3; i++){
		if(wait(&st) < 0 || st < 10 || st > 12)
			{ fail("wait"); return; }
	}
	if(wait(0) != -1)
		{ fail("wait without children"); return; }
	print("forks ok\n");
}

// echo's output, through a pipe: exec's arguments
void
execs(void)
{
	int p[2], n, m;

	pipe(p);
	if(fork() == 0){
		close(1);
		dup(p[1]);
		close(p[0]);
		close(p[1]);
		exec("/bin/echo", argv);
		exit(1);
	}
	close(p[1]);
	n = 0;
	while((m = read(p[0], buf + n, 100)) > 0)
		n += m;
	close(p[0]);
	wait(0);
	buf[n] = 0;
	if(strcmp(buf, "one two\n") != 0)
		{ fail("exec"); return; }
	if(exec("/nothing", argv) != -1)
		{ fail("exec of nothing"); return; }
	print("execs ok\n");
}

// a child writes 1500 bytes (the pipe holds 512: it waits for the
// reader), the reader sees them all, then the end
void
pipes(void)
{
	int p[2], n, m, i;

	pipe(p);
	if(fork() == 0){
		close(p[0]);
		for(i = 0; i < 1500; i++)
			buf[i] = 'a' + i % 26;
		for(n = 0; n < 1500; n += m)
			if((m = write(p[1], buf + n, 1500 - n)) <= 0)
				exit(1);
		exit(0);
	}
	close(p[1]);
	for(i = 0; i < 1500; i++)
		buf[i] = 0;
	n = 0;
	while((m = read(p[0], buf + n, 700)) > 0)
		n += m;
	close(p[0]);
	wait(0);
	if(n != 1500 || buf[0] != 'a' || buf[1499] != 'a' + 1499 % 26)
		{ fail("pipes"); return; }
	print("pipes ok\n");
}

void
files(void)
{
	int fd, n;

	if((fd = open("f", O_CREATE | O_WRONLY)) < 0)
		{ fail("create"); return; }
	write(fd, "hello, ", 7);
	write(fd, "world\n", 6);
	close(fd);
	fd = open("f", O_RDONLY);
	n = read(fd, buf, 100);
	close(fd);
	buf[n] = 0;
	if(strcmp(buf, "hello, world\n") != 0)
		{ fail("files"); return; }
	if(open("f", O_CREATE | O_WRONLY | O_TRUNC) < 0 ||
	   (fd = open("f", O_RDONLY)) < 0 || read(fd, buf, 10) != 0)
		{ fail("truncate"); return; }
	if(unlink("f") != 0 || open("f", O_RDONLY) >= 0)
		{ fail("unlink"); return; }
	print("files ok\n");
}

void
dirs(void)
{
	int fd;

	if(mkdir("d") != 0 || mkdir("d/e") != 0 || chdir("d/e") != 0)
		{ fail("mkdir"); return; }
	if((fd = open("../g", O_CREATE | O_WRONLY)) < 0)
		{ fail(".."); return; }
	write(fd, "x", 1);
	close(fd);
	chdir("/");
	if((fd = open("/d/g", O_RDONLY)) < 0 || read(fd, buf, 10) != 1)
		{ fail("a file by .."); return; }
	close(fd);
	if(unlink("/d") == 0)
		{ fail("unlink of a directory not empty"); return; }
	unlink("/d/g");
	unlink("/d/e");
	if(unlink("/d") != 0)
		{ fail("unlink of an empty directory"); return; }
	print("dirs ok\n");
}

// a store outside the partition: the child killed, its status -1
void
fault(void)
{
	int st;

	if(fork() == 0){
		*(int*)0x200000 = 1;
		exit(0);
	}
	wait(&st);
	if(st != -1)
		{ fail("fault"); return; }
	print("fault ok\n");
}

// a child spinning forever, killed: its status -1; a pid that is no
// process, -1
void
kills(void)
{
	int pid, st;

	if((pid = fork()) == 0)
		for(;;)
			;
	if(kill(pid) != 0 || wait(&st) != pid || st != -1 || kill(pid) != -1)
		{ fail("kill"); return; }
	print("kill ok\n");
}

// two children spinning, writing a letter before and after: with the
// timer's preemption each starts before either ends
void
preemption(void)
{
	int p[2], i, k, n, x;

	pipe(p);
	for(k = 0; k < 2; k++)
		if(fork() == 0){
			write(p[1], k == 0 ? "a" : "b", 1);
			for(i = 0, x = 0; i < 100000; i++)
				x += i;
			write(p[1], k == 0 ? "A" : "B", 1);
			exit(0);
		}
	close(p[1]);
	n = 0;
	while(n < 4 && read(p[0], buf + n, 1) == 1)
		n++;
	close(p[0]);
	wait(0);
	wait(0);
	if(n != 4 || buf[0] < 'a' || buf[1] < 'a')
		{ fail("preemption: one ran to its end first"); return; }
	print("preemption ok\n");
}

// what the traced child calls, where its tracer stops it
int
traced(int x)
{
	return x + 1;
}

// a command to the trace t (none: 0), and whether its answer is want
// (the answer's end only, when want starts with a dot)
int
ask(int t, char *command, char *want)
{
	char line[200];
	int n, k;

	if(command != 0 && write(t, command, strlen(command)) < 0)
		return 0;
	n = read(t, line, sizeof line - 1);
	if(n < 0)
		return 0;
	line[n] = 0;
	if(want[0] != '.')
		return strcmp(line, want) == 0;
	k = strlen(want) - 1;
	return n >= k && strcmp(line + n - k, want + 1) == 0;
}

// a child stopped at a breakpoint (traced's first word), its pc read,
// resumed to its end; a child stopped by a fault rather than killed;
// a child traced from its exec, stopped at its first instruction
void
traces(void)
{
	int p[2], pid, t, st;
	char b[40], pc[40];

	pipe(p);
	if((pid = fork()) == 0){
		read(p[0], b, 1);
		exit(traced(6));
	}
	t = trace(pid);
	sprint(b, "b %d", (int)traced);
	sprint(pc, ".pc %d\n", (int)traced);
	if(t < 0 || !ask(t, b, "ok\n"))
		{ fail("trace: a breakpoint set"); return; }
	write(p[1], "x", 1);
	if(!ask(t, 0, ".break\n") || !ask(t, "r", pc) || !ask(t, "c", "exited 7\n")
	|| read(t, b, 1) != 0 || wait(&st) != pid || st != 7)
		{ fail("trace: a breakpoint"); return; }
	close(t);

	if((pid = fork()) == 0){
		read(p[0], b, 1);
		*(int*)0x200000 = 1;
		exit(0);
	}
	t = trace(pid);
	write(p[1], "x", 1);
	if(!ask(t, 0, ".fault 2097152\n") || kill(pid) != 0 ||
	   !ask(t, 0, "exited -1\n") || wait(&st) != pid)
		{ fail("trace: a fault"); return; }
	close(t);

	if((pid = fork()) == 0){
		close(1);
		trace(0);
		exec("/bin/echo", argv);
		exit(1);
	}
	t = trace(pid);
	if(!ask(t, 0, "stopped 0 exec\n") || !ask(t, "c", ".exited 0\n") ||
	   wait(&st) != pid)
		{ fail("trace: an exec"); return; }
	close(t);
	close(p[0]);
	close(p[1]);
	print("trace ok\n");
}

void
main(void)
{
	forks();
	execs();
	pipes();
	files();
	dirs();
	fault();
	kills();
	preemption();
	traces();
	print(failed ? "mltests: FAILED\n" : "mltests: ALL OK\n");
	exit(failed);
}
