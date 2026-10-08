/* From Plan 9's libc.h, as goken split it (libc's README.md; LICENSE). */
/*
 * mem routines (provided by C stdlib <string.h>)
 */

extern  void*   memset(void*, int, ulong);
extern  void*   memcpy(void*, void*, ulong);
extern  void*   memmove(void*, void*, ulong);
extern  int     memcmp(void*, void*, ulong);
extern  void*   memchr(void*, int, ulong);
extern  void*   memccpy(void*, void*, int, ulong);
