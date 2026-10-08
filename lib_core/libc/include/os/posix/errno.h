/* From Plan 9's libc.h, as goken split it (libc's README.md; LICENSE). */
/* POSIX's errno: goken's fmt/ sets it (ix/fmt.c does not) */
#ifndef _OS_POSIX_ERRNO_H_
#define _OS_POSIX_ERRNO_H_ 1

extern int errno;

#define ERANGE 34

// needed by fmt/errfmt.c (the %r format verb)
extern char* strerror(int);

#endif
