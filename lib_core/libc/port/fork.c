/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* fork: Plan 9's and POSIX's are the same, but for a failure, which
 * is -1 here where the kernel's call says -errno (a switch on -1 must
 * find it). */

extern int _sysfork(void);

int
fork(void)
{
	int pid;

	pid = _sysfork();
	if(pid < 0)
		return -1;
	return pid;
}
