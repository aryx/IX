/* From Plan 9's libc.h, as goken split it (libc's README.md; LICENSE). */
extern  char*   getenv(char*);
extern  int     putenv(char*, char*);

extern  char**  environ(void);	/* nil-terminated array of "NAME=value" */
