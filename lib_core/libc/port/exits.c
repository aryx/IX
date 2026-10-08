/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* exits and _exits, Plan 9's, a string where POSIX has a number: over
 * exit(int), 0 for nil or "". exits runs atexit's functions first
 * (port/atexit.c), _exits does not. Not for Plan 9, where exits is the
 * kernel's call (syscall/os/plan9/svc_arm.s). */

extern void atexitrun(void);

void
exits(char *s)
{
	atexitrun();
	if(s == nil || s[0] == '\0')
		exit(0);
	exit(1);
}

void
_exits(char *s)
{
	if(s == nil || s[0] == '\0')
		exit(0);
	exit(1);
}
