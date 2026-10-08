/* From Plan 9's libc.h, as goken split it (libc's README.md; LICENSE). */
//builtin: sizeof
// signof?
// typeof?

#define nelem(x)    (sizeof(x)/sizeof((x)[0]))

#define offsetof(s, m)  (ulong)(&(((s*)nil)->m))
