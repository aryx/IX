/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* getwd over Linux's getcwd, which gives the length written or
 * -errno, where Plan 9's gives the buffer or nil (a buffer too small
 * is nil too). */

extern long _sysgetcwd(char *buf, ulong size);

char*
getwd(char *buf, int nbuf)
{
	if(nbuf <= 0)
		return nil;
	if(_sysgetcwd(buf, (ulong)nbuf) < 0)
		return nil;
	return buf;
}
