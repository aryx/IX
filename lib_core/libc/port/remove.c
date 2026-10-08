/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* remove: Plan 9's takes a file or an empty directory, where POSIX has
 * unlink for one and rmdir for the other. rmdir is tried whenever
 * unlink failed, without a look at why: the error for a directory is
 * not the same number on every system. */

extern int _sysunlink(char *path);
extern int _sysrmdir(char *path);

/* a failure is -1, as Plan 9's (rm and mv compare with it), not
 * Linux's -errno */
int
remove(char *path)
{
	if (_sysunlink(path) >= 0)
		return 0;
	if (_sysrmdir(path) >= 0)
		return 0;
	return -1;
}
