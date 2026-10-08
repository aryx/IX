/* From Plan 9's libc.h, as goken split it (libc's README.md; LICENSE). */
// ugly redefined by user code? see statusbar.c
extern  void    qsort(void*, long, long, int (*)(void*, void*));
