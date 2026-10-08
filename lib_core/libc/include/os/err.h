/* From Plan 9's libc.h, as goken split it (libc's README.md; LICENSE). */
// print human-readable error message for UNIX global errno (errno is an int)
extern  void    perror(char*);

// will internally call exits(). TODO? declare hook _sysfatal() here?
extern  void    sysfatal(char*, ...);

#pragma varargck    argpos  sysfatal    1

// This function is bidirectional and can be used to both read and set the
// error string depending how it's called.
extern	int	errstr(char*, uint);

// read but does not clear the error
extern	void	rerrstr(char*, uint);
// set the per-process error string.
extern	void	werrstr(char*, ...);

#pragma	varargck	argpos	werrstr	1

#define	ERRMAX	128	/* max length of error string */ // for errstr()
