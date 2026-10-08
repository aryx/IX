/* From Plan 9's libc.h, as goken split it (libc's README.md; LICENSE). */
#define	STATMAX	65535U	/* max length of machine-independent stat structure */

/* dirfstat and dirfwstat, by descriptor, are each system's (os/); the
 * two by path are over them (port/dirstat.c, dirwstat.c). Plan 9's
 * stat and fstat, which give bytes, are not declared: only its kernel
 * speaks that format (os/plan9/stat.c). */
extern	Dir*	dirfstat(fdt);
extern	Dir*	dirstat(char*);
extern	int	dirfwstat(int, Dir*);
extern	int	dirwstat(char*, Dir*);
