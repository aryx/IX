/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */

/* make self-quick's C program (mkfile): linked over lib_core's C
 * library alone (write and exits: it has no print) */
#include <u.h>
#include <libc.h>

void
main(void)
{
	write(1, "hello from C\n", 13);
	exits(nil);
}
