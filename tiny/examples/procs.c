// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// procs: what a shell does for echo ... | its reader, by hand. A pipe;
// fork, a copy of this process; in the child, its standard output made
// the pipe's writing end (close 1, then dup: the lowest free
// descriptor), then exec, the child becoming /bin/echo; in the parent,
// the pipe read until its end (the child's exit closes its end), then
// wait for the child. The Buildfile beside it builds it, with /lib/c's
// runtime:
//
//	cd /examples; build procs; ./procs
//	trace -f ./procs             the calls of both, fork's child too
#include "user.h"

char buf[256];

void
main(void)
{
	int fds[2], pid, n, status;
	char *argv[6];

	if(pipe(fds) < 0){
		print("procs: no pipe\n");
		exit(1);
	}
	pid = fork();
	if(pid == 0){
		close(1);
		dup(fds[1]);
		close(fds[0]);
		close(fds[1]);
		argv[0] = "echo";
		argv[1] = "hello,";
		argv[2] = "through";
		argv[3] = "a";
		argv[4] = "pipe";
		argv[5] = 0;
		exec("/bin/echo", argv);
		print("procs: no /bin/echo\n");
		exit(1);
	}
	print("procs %d: child %d forked\n", getpid(), pid);
	close(fds[1]);
	while((n = read(fds[0], buf, sizeof buf - 1)) > 0){
		buf[n] = 0;
		print("procs %d: read: %s", getpid(), buf);
	}
	print("procs %d: child %d ended\n", getpid(), wait(&status));
	exit(0);
}
