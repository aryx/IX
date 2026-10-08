/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* Plan 9's, by principia and goken (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* getenv, after principia's 9sys/getenv.c: the environment is a
 * directory, /env, a file for each variable. So the value is read and
 * allocated (the caller's; nothing frees it), and a name with a / is
 * refused. A value's zeros become spaces: a list's elements are
 * separated by them (rc's $path). */

char*
getenv(char *name)
{
	int r;
	fdt f;
	long s;
	char *ans;
	char *p, *ep, ename[100];

	if(strchr(name, '/') != nil)
		return nil;
	snprint(ename, sizeof ename, "/env/%s", name);
	/* snprint truncated the name: refuse rather than read a prefix */
	if(strcmp(ename+5, name) != 0)
		return nil;
	f = open(ename, OREAD);
	if(f < 0)
		return nil;
	s = seek(f, 0, 2);
	ans = malloc(s+1);
	if(ans != nil) {
		seek(f, 0, 0);
		r = read(f, ans, s);
		if(r >= 0) {
			ep = ans + s - 1;
			for(p = ans; p < ep; p++)
				if(*p == '\0')
					*p = ' ';
			ans[s] = '\0';
		}
	}
	close(f);
	return ans;
}
