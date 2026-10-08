/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* Linux's calls, a function each over _syscall6 (svc_arm.s,
 * svc_arm64.s): after goken's zsyscall_linux_arm.c and
 * zsyscall_linux_arm64.c, which a script of its generated, here one
 * file, without the calls nothing of ix asks (brk, dup, pipe, kill,
 * the signals, the clocks). A name with _sys is the kernel's call as
 * it is; os/linux/ and port/ make Plan 9's of it. arm64 has Linux's
 * newer calls only (openat and no open, clone and no fork...): the
 * header puts the older names over them. */
#include <u.h>
#include <libc.h>
#include "syscall_linux.h"

long write(int fd, void* buf, long n)
{
	return (long)_syscall6(SYS_write, (Arg)fd, (Arg)buf, (Arg)n, 0, 0, 0);
}

long read(int fd, void* buf, long n)
{
	return (long)_syscall6(SYS_read, (Arg)fd, (Arg)buf, (Arg)n, 0, 0, 0);
}

int close(int fd)
{
	return (int)_syscall6(SYS_close, (Arg)fd, 0, 0, 0, 0, 0);
}

#ifdef arm64
vlong lseek(int fd, vlong offset, int whence)
{
	return (vlong)_syscall6v(SYS_lseek, (Arg)fd, (Arg)offset, (Arg)whence, 0, 0, 0);
}
#else
long lseek(int fd, vlong offset, int whence)
{
	return (long)_syscall6(SYS_lseek, (Arg)fd, (Arg)offset, (Arg)whence, 0, 0, 0);
}

long _sysopen(void* path, int flags, int mode)
{
	return (long)_syscall6(SYS_open, (Arg)path, (Arg)flags, (Arg)mode, 0, 0, 0);
}

int _sysunlink(char* path)
{
	return (int)_syscall6(SYS_unlink, (Arg)path, 0, 0, 0, 0, 0);
}

int _sysrmdir(char* path)
{
	return (int)_syscall6(SYS_rmdir, (Arg)path, 0, 0, 0, 0, 0);
}

int _sysmkdir(char* path, int mode)
{
	return (int)_syscall6(SYS_mkdir, (Arg)path, (Arg)mode, 0, 0, 0, 0);
}

int access(char* path, int mode)
{
	return (int)_syscall6(SYS_access, (Arg)path, (Arg)mode, 0, 0, 0, 0);
}
#endif

long openat(int dirfd, void* path, int flags, int mode)
{
	return (long)_syscall6(SYS_openat, (Arg)dirfd, (Arg)path, (Arg)flags, (Arg)mode, 0, 0);
}

#ifdef arm64
int unlinkat(int dirfd, char* path, int flags)
{
	return (int)_syscall6(SYS_unlinkat, (Arg)dirfd, (Arg)path, (Arg)flags, 0, 0, 0);
}

int mkdirat(int dirfd, char* path, int mode)
{
	return (int)_syscall6(SYS_mkdirat, (Arg)dirfd, (Arg)path, (Arg)mode, 0, 0, 0);
}

int faccessat(int dirfd, char* path, int mode, int flags)
{
	return (int)_syscall6(SYS_faccessat, (Arg)dirfd, (Arg)path, (Arg)mode, (Arg)flags, 0, 0);
}
#endif

int chdir(char* path)
{
	return (int)_syscall6(SYS_chdir, (Arg)path, 0, 0, 0, 0, 0);
}

void exit(int code)
{
	_syscall6(SYS_exit, (Arg)code, 0, 0, 0, 0, 0);
}

int getpid(void)
{
	return (int)_syscall6(SYS_getpid, 0, 0, 0, 0, 0, 0);
}

long _sysgetcwd(char* buf, ulong size)
{
	return (long)_syscall6(SYS_getcwd, (Arg)buf, (Arg)size, 0, 0, 0, 0);
}

#ifdef arm64
int _sysfstat(int fd, void* buf)
{
	return (int)_syscall6(SYS_fstat, (Arg)fd, (Arg)buf, 0, 0, 0, 0);
}
#else
int _sysfstat(int fd, void* buf)
{
	return (int)_syscall6(SYS_fstat64, (Arg)fd, (Arg)buf, 0, 0, 0, 0);
}
#endif

int _sysfchmod(int fd, int mode)
{
	return (int)_syscall6(SYS_fchmod, (Arg)fd, (Arg)mode, 0, 0, 0, 0);
}

#ifdef arm64
int _sysftruncate(int fd, vlong length)
{
	return (int)_syscall6(SYS_ftruncate, (Arg)fd, (Arg)length, 0, 0, 0, 0);
}
#else
int _sysftruncate64(int fd, ulong lo, ulong hi)
{
	return (int)_syscall6(SYS_ftruncate64, (Arg)fd, (Arg)lo, (Arg)hi, 0, 0, 0);
}
#endif

long _sysgetdents64(int fd, void* buf, uint count)
{
	return (long)_syscall6(SYS_getdents64, (Arg)fd, (Arg)buf, (Arg)count, 0, 0, 0);
}

long _sysrenameat2(int olddirfd, void* oldpath, int newdirfd, void* newpath, uint flags)
{
	return (long)_syscall6(SYS_renameat2, (Arg)olddirfd, (Arg)oldpath, (Arg)newdirfd, (Arg)newpath, (Arg)flags, 0);
}

#ifdef arm64
int _sysrawclone(int flags, void* stack, void* ptid, void* ctid, void* tls)
{
	return (int)_syscall6(SYS_clone, (Arg)flags, (Arg)stack, (Arg)ptid, (Arg)ctid, (Arg)tls, 0);
}
#else
int _sysfork(void)
{
	return (int)_syscall6(SYS_fork, 0, 0, 0, 0, 0, 0);
}
#endif

int _sysexecve(void* path, void* argv, void* envp)
{
	return (int)_syscall6(SYS_execve, (Arg)path, (Arg)argv, (Arg)envp, 0, 0, 0);
}

int _syswait4(int pid, void* status, int options, void* rusage)
{
	return (int)_syscall6(SYS_wait4, (Arg)pid, (Arg)status, (Arg)options, (Arg)rusage, 0, 0);
}
