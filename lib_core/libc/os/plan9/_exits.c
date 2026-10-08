/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* exits is the kernel's call (syscall/os/plan9/svc_arm.s), and it has
 * no other one to leave: _exits is the same. */
void
_exits(char *s)
{
	exits(s);
}
