/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* exec: Plan 9's takes no environment, so execve is given the one
 * port/getenv.c's environ says. It only returns when it failed: -1,
 * as Plan 9's, not Linux's -errno. */

extern int _sysexecve(void *path, void *argv, void *envp);

int
exec(char *prog, char *argv[])
{
	_sysexecve(prog, argv, environ());
	return -1;
}
