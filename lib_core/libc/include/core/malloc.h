/* From Plan 9's libc.h, as goken split it (libc's README.md; LICENSE). */
// in <stdlib.h>

extern  void*   malloc(ulong);
extern  void    free(void*);

extern  void*   mallocz(ulong, bool);
extern  void*   realloc(void*, ulong);
extern  void*   calloc(ulong, ulong);

// internals (useful for debugging), Plan 9 specific
// alt: in debug.h or os/plan9/debug.h ?
extern  void    setmalloctag(void*, ulong);
extern  void    setrealloctag(void*, ulong);
extern  ulong   getmalloctag(void*);
extern  ulong   getrealloctag(void*);
extern  void*   malloctopoolblock(void*);
