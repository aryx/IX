// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// TinyKernel.ml's tests, each a line "... ok", or what went wrong: fork
// and wait's statuses, exec's arguments, pipes (a child writer, the
// end seen when no writer is left, a big write in pieces), files,
// directories and "..", a fault killed, the preemption.
#include "user.h"

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
		exec("/echo", argv);
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
	if(open("f", O_CREATE | O_WRONLY | O_TRUNC) < 0 || (fd = open("f", O_RDONLY)) < 0 || read(fd, buf, 10) != 0)
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
	print(failed ? "mltests: FAILED\n" : "mltests: ALL OK\n");
	exit(failed);
}
