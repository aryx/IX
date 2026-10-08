/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
/* Linux's calls on arm (EABI), their numbers: the older table
 * (arch/arm/tools/syscall.tbl), the ones zsyscall_linux.c asks. */
#define SYS_exit	1
#define SYS_fork	2
#define SYS_read	3
#define SYS_write	4
#define SYS_open	5
#define SYS_close	6
#define SYS_unlink	10
#define SYS_execve	11
#define SYS_chdir	12
#define SYS_lseek	19
#define SYS_getpid	20
#define SYS_access	33
#define SYS_mkdir	39
#define SYS_rmdir	40
#define SYS_fchmod	94
#define SYS_wait4	114
#define SYS_getcwd	183
#define SYS_ftruncate64	194
#define SYS_fstat64	197
#define SYS_getdents64	217
#define SYS_openat	322
#define SYS_renameat2	382
