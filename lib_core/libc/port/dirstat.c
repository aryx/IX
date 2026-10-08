/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* dirstat by path, over dirfstat by descriptor (os/'s stat files). The
 * file is opened for reading: one that can be seen and not read is not
 * found, where stat(2) finds it. */
Dir*
dirstat(char *name)
{
	fdt fd;
	Dir *d;

	fd = open(name, OREAD);
	if (fd < 0)
		return nil;
	d = dirfstat(fd);
	close(fd);
	return d;
}
