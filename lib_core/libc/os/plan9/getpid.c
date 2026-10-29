/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* Plan 9's, by principia and goken (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* getpid, after principia's 9sys/getpid.c: the kernel's #c/pid, the
 * number in text. */

int
getpid(void)
{
	char b[20];
	fdt f;

	memset(b, 0, sizeof(b));
	f = open("#c/pid", OREAD);
	if(f >= 0){
		read(f, b, sizeof(b) - 1);
		close(f);
	}
	return atol(b);
}
