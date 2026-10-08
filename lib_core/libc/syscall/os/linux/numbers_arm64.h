/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
/* Linux's calls on arm64, their numbers: the "generic" table
 * (asm-generic/unistd.h), the ones zsyscall_linux.c asks. */
#define SYS_getcwd	17
#define SYS_mkdirat	34
#define SYS_unlinkat	35
#define SYS_ftruncate	46
#define SYS_faccessat	48
#define SYS_chdir	49
#define SYS_fchmod	52
#define SYS_openat	56
#define SYS_close	57
#define SYS_getdents64	61
#define SYS_lseek	62
#define SYS_read	63
#define SYS_write	64
#define SYS_fstat	80
#define SYS_exit	93
#define SYS_getpid	172
#define SYS_clone	220
#define SYS_execve	221
#define SYS_wait4	260
#define SYS_renameat2	276
