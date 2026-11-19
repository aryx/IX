/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */

/* procs: what a shell does for echo ... | its reader, by hand, with
 * Plan 9's calls. A pipe; fork, a copy of this process; in the child,
 * its standard output made the pipe's writing end (dup, which on Plan 9
 * names the descriptor to take), then exec, the child becoming
 * /bin/echo; in the parent, the pipe read until its end (the child's
 * exit closes its end), then await, which gives the child's last words
 * as a text: its pid, its three times and what it said to exits. For
 * mini-9pi only: lib_core's C library has no pipe and no dup on Linux
 * (Procsml.ml is the same program in ML, for both). The mkfile beside
 * it builds it:
 *
 *	cd /src/examples; mk; ../_mk/5-plan9/examples/procs
 */
#include <u.h>
#include <libc.h>

void
say(char *fmt, int a, char *s)
{
	char line[256];

	write(1, line, snprint(line, sizeof line, fmt, getpid(), a, s));
}

void
main(void)
{
	int fds[2], pid, n;
	char buf[256];
	char *argv[6];

	if(pipe(fds) < 0)
		exits("no pipe");
	pid = fork();
	if(pid == 0){
		dup(fds[1], 1);
		close(fds[0]);
		close(fds[1]);
		argv[0] = "echo";
		argv[1] = "hello,";
		argv[2] = "through";
		argv[3] = "a";
		argv[4] = "pipe";
		argv[5] = nil;
		exec("/bin/echo", argv);
		exits("no /bin/echo");
	}
	say("procs %d: child %d forked%s\n", pid, "");
	close(fds[1]);
	while((n = read(fds[0], buf, sizeof buf - 1)) > 0){
		buf[n] = 0;
		say("procs %d: read %d bytes: %s", n, buf);
	}
	n = await(buf, sizeof buf - 1);
	if(n < 0)
		exits("no child");
	buf[n] = 0;
	say("procs %d: child %d ended%s\n", atoi(buf), "");
	exits(nil);
}
