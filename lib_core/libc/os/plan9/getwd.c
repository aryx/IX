/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* Plan 9's, by principia and goken (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* getwd, after principia's 9sys/getwd.c: the directory is opened and
 * the kernel asked for the path of the descriptor. */

char*
getwd(char *buf, int nbuf)
{
	int n;
	fdt fd;

	fd = open(".", OREAD);
	if(fd < 0)
		return nil;
	n = fd2path(fd, buf, nbuf);
	close(fd);
	if(n < 0)
		return nil;
	return buf;
}
