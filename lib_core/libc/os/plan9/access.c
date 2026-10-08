/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* Plan 9's, by principia and goken (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* access: no call of Plan 9's kernel, a function over open, after
 * principia's 9sys/access.c and its table. Not as it: AEXIST is a
 * dirstat there, an open for reading here, so a file that is there and
 * cannot be read is said not to exist. */
int
access(char *name, int mode)
{
	fdt fd;
	static char omode[] = {
		0,		/* AEXIST -- see the gap noted above */
		OEXEC,		/* AEXEC */
		OWRITE,		/* AWRITE */
		ORDWR,		/* AWRITE|AEXEC */
		OREAD,		/* AREAD */
		OEXEC,		/* AREAD|AEXEC -- only approximate */
		ORDWR,		/* AREAD|AWRITE */
		ORDWR		/* AREAD|AWRITE|AEXEC -- only approximate */
	};

	fd = open(name, omode[mode&7]);
	if (fd >= 0) {
		close(fd);
		return 0;
	}
	return -1;
}
