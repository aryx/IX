/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* dirwstat by path, over dirfwstat by descriptor: Plan 9's (Linux has
 * its own, os/linux/dirwstat.c, for the renaming). The file is opened
 * ORDWR: one that cannot be written cannot have its mode changed this
 * way. */
int
dirwstat(char *name, Dir *d)
{
	fdt fd;
	int r;

	fd = open(name, ORDWR);
	if (fd < 0)
		return -1;
	r = dirfwstat(fd, d);
	close(fd);
	return r;
}
