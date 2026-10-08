/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* Plan 9's, by principia and goken (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* the last c of s, by strchr */
char*
strrchr(char *s, int c)
{
	char *r;

	if(c == '\0')
		return strchr(s, '\0');

	r = 0;
	while(s = strchr(s, c))
		r = s++;
	return r;
}
