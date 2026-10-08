/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* getenv and environ for Linux: no system call, the kernel puts the
 * environment on the first stack, an array of "NAME=value" ended by a
 * nil, right after argv's own nil. _mainargv and _mainargc are the
 * start's (arch/'s rt0.s, port/mainargs.c). Plan 9's is
 * os/plan9/getenv.c. */

extern char **_mainargv;
extern intptr _mainargc;

/* an array made to grow (goken's putenv, not here); nil: the kernel's
 * block is the environment */
char **_environp;

/* after argc arguments and their nil: not by looking for the nil,
 * which a program may have moved (port/mainargs.c) */
char**
environ(void)
{
	if(_environp != nil)
		return _environp;
	if(_mainargv == nil)
		return nil;
	return _mainargv + _mainargc + 1;
}

/* A pointer into the environment, as POSIX's and not as Plan 9's,
 * which allocates: not to be freed, nor written. */
char*
getenv(char *name)
{
	char **e, *p, *q;

	if(name == nil || *name == '\0')
		return nil;
	e = environ();
	if(e == nil)
		return nil;
	for(; *e != nil; e++) {
		/* the name must end at the '=': "PATH" is not "PATHEXT=..." */
		p = *e;
		q = name;
		while(*q != '\0' && *p == *q) {
			p++;
			q++;
		}
		if(*q == '\0' && *p == '=')
			return p + 1;
	}
	return nil;
}
