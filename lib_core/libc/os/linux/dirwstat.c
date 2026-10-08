/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* dirwstat for Linux: port/dirwstat.c's, and a name in the Dir renames
 * the file, in its directory (mv asks it with the other fields left
 * alone). dirfwstat cannot: it has a descriptor, and Linux renames by
 * path. */

#define AT_FDCWD (-100)

extern long _sysrenameat2(int olddirfd, void *oldpath, int newdirfd, void *newpath, uint flags);

int
dirwstat(char *name, Dir *d)
{
	fdt fd;
	int r;
	char newpath[1024], *dir, *slash;

	if (d->name != nil && d->name[0] != '\0') {
		strncpy(newpath, name, sizeof newpath);
		newpath[sizeof(newpath)-1] = '\0';
		slash = strrchr(newpath, '/');
		if (slash != nil)
			dir = slash+1;
		else
			dir = newpath;
		if (dir - newpath + strlen(d->name) + 1 > sizeof newpath)
			return -1;
		strcpy(dir, d->name);

		if (_sysrenameat2(AT_FDCWD, name, AT_FDCWD, newpath, 0) < 0)
			return -1;
		name = newpath;
	}

	fd = open(name, ORDWR);
	if (fd < 0)
		return -1;
	r = dirfwstat(fd, d);
	close(fd);
	return r;
}
