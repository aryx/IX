/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* Plan 9's open and create (include/os/file.h's OREAD, OTRUNC...) over
 * Linux's open (_sysopen, syscall/os/linux/) and its O_ flags. */
#define O_TRUNC		0x200
#define O_CLOEXEC	0x80000
#ifdef mips
#define O_CREAT		0x100
#define O_EXCL		0x400
#else
#define O_CREAT		0x40
#define O_EXCL		0x80
#endif

extern long _sysopen(void *path, int flags, int mode);
extern int _sysmkdir(char *path, int mode);

/* Plan 9's mode as Linux's flags: open's and create's */
static int
openflags(int mode)
{
	int flags;

	switch (mode & 3) {
	case OWRITE:
		flags = 1; /* O_WRONLY */
		break;
	case ORDWR:
		flags = 2; /* O_RDWR */
		break;
	case OEXEC: /* no POSIX "exec-only" open mode; O_RDONLY is closest */
	case OREAD:
	default:
		flags = 0; /* O_RDONLY */
		break;
	}
	if (mode & OTRUNC)
		flags |= O_TRUNC;
	if (mode & OCEXEC)
		flags |= O_CLOEXEC;
	if (mode & OEXCL)
		flags |= O_EXCL;
	/* (ORCLOSE, remove on close: it would take an unlink, not done) */
	return flags;
}

fdt
open(char *path, int mode)
{
	return (fdt)_sysopen(path, openflags(mode), 0);
}

/* create: Plan 9's makes the file or truncates the one there, always,
 * and leaves it open in the mode asked (Linux's creat only writes).
 * The 9 bits of perm are POSIX's; DMDIR asks for a directory, which
 * open cannot make: mkdir, then open, for reading only as Plan 9
 * allows no other. */
int
create(char *path, int mode, ulong perm)
{
	if (perm & DMDIR) {
		if ((mode & ~OCEXEC) != OREAD)
			return -1;
		if (_sysmkdir(path, (int)(perm & 0777)) < 0)
			return -1;
		return (int)_sysopen(path, openflags(mode), 0);
	}
	return (int)_sysopen(path, openflags(mode)|O_CREAT|O_TRUNC,
		(int)(perm & 0777));
}
