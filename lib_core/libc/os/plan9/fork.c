/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* Plan 9's, by principia and goken (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* fork: no call of Plan 9's kernel but rfork, with a new process, a
 * copy of the descriptors, and what lets the parent wait for it
 * (principia's 9sys/fork.c). */

int
fork(void)
{
	return rfork(RFPROC|RFFDG|RFREND);
}
