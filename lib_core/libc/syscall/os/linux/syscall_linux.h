/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* What zsyscall_linux.c needs, after goken's syscall_linux_arm.h and
 * syscall_linux_arm64.h: the calls' numbers and the way in the kernel
 * (svc_arm.s, svc_arm64.s). An argument is an Arg, a register: a vlong
 * on arm64, where the compiler's long is 4 bytes and a pointer through
 * it would lose its high half. */
#ifdef arm64
#include "numbers_arm64.h"
typedef vlong Arg;
/* the same, giving the kernel's 64 bits: for lseek */
extern vlong _syscall6v(long num, Arg a1, Arg a2, Arg a3, Arg a4, Arg a5, Arg a6);
#else
#include "numbers_arm.h"
typedef long Arg;
#endif
extern long _syscall6(long num, Arg a1, Arg a2, Arg a3, Arg a4, Arg a5, Arg a6);

#ifdef arm64
/* arm64 has Linux's "generic" calls: no open, unlink, rmdir, mkdir,
 * access nor fork, but the ones that take a directory's descriptor,
 * and clone. The older names, which os/linux/ and port/ call, over
 * them: AT_FDCWD says the path is from the current directory, as it
 * was; rmdir is unlinkat with a flag; fork is clone with the signal
 * the parent gets at the child's end and no stack given, so a copy of
 * the parent's. */
#define AT_FDCWD (-100)
#define AT_REMOVEDIR 0x200
#define SIGCHLD 17

extern long openat(int dirfd, void *path, int flags, int mode);
extern int unlinkat(int dirfd, char *path, int flags);
extern int mkdirat(int dirfd, char *path, int mode);
extern int faccessat(int dirfd, char *path, int mode, int flags);
extern int _sysrawclone(int flags, void *stack, void *ptid, void *ctid, void *tls);

long _sysopen(void *path, int flags, int mode)
{
	return openat(AT_FDCWD, path, flags, mode);
}

int _sysunlink(char *path)
{
	return unlinkat(AT_FDCWD, path, 0);
}

int _sysrmdir(char *path)
{
	return unlinkat(AT_FDCWD, path, AT_REMOVEDIR);
}

int _sysmkdir(char *path, int mode)
{
	return mkdirat(AT_FDCWD, path, mode);
}

int access(char *path, int mode)
{
	return faccessat(AT_FDCWD, path, mode, 0);
}

int _sysfork(void)
{
	return _sysrawclone(SIGCHLD, 0, 0, 0, 0);
}
#endif
