/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* seek: Plan 9's name for lseek, the same otherwise (0, 1, 2 for the
 * start, the position, the end). Not for Plan 9, where seek is the
 * kernel's call. */

/* lseek gives a vlong where a register holds one (_syscall6v), a long
 * elsewhere */
#ifdef arm64
extern vlong lseek(int fd, vlong offset, int whence);
#else
extern long lseek(int fd, vlong offset, int whence);
#endif

vlong
seek(fdt fd, vlong offset, int whence)
{
	return (vlong)lseek(fd, offset, whence);
}
