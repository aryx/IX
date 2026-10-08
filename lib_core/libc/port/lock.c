/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* Not principia's, which are over atomic increments and the kernel's
 * semaphores: there is one thread of execution, and nothing to wait
 * for. */

void
lock(Lock *l)
{
}

void
unlock(Lock *l)
{
}

int
canlock(Lock *l)
{
	return 1;
}
