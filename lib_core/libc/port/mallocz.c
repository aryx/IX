/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* malloc, and zeros when asked */
void*
mallocz(ulong size, bool clear)
{
	void *p;

	p = malloc(size);
	if (p != nil && clear)
		memset(p, 0, size);
	return p;
}
