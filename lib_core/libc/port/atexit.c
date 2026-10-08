/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* Plan 9's, by principia and goken (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* atexit, after principia's: a table of (function, pid), the pid so
 * that a forked child does not run its parent's. exits is not here but
 * in port/exits.c, which calls atexitrun before it leaves; _exits does
 * not. */

#define NEXIT 33

typedef struct Onex Onex;
struct Onex {
	void (*f)(void);
	int pid;
};

static Lock onexlock;
Onex onex[NEXIT];

int
atexit(void (*f)(void))
{
	int i;

	lock(&onexlock);
	for (i = 0; i < NEXIT; i++)
		if (onex[i].f == nil) {
			onex[i].pid = getpid();
			onex[i].f = f;
			unlock(&onexlock);
			return 1;
		}
	unlock(&onexlock);
	return 0;
}

void
atexitrun(void)
{
	int i, pid;
	void (*f)(void);

	pid = getpid();
	for (i = NEXIT-1; i >= 0; i--)
		if ((f = onex[i].f) && pid == onex[i].pid) {
			onex[i].f = nil;
			(*f)();
		}
}
