/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* Plan 9's, by principia and goken (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

int
strncmp(char *s1, char *s2, long n)
{
	unsigned c1, c2;

	while(n > 0) {
		c1 = *s1++;
		c2 = *s2++;
		n--;
		if(c1 != c2) {
			if(c1 > c2)
				return 1;
			return -1;
		}
		if(c1 == 0)
			break;
	}
	return 0;
}
