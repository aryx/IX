/* From Plan 9's libc.h, as goken split it (libc's README.md; LICENSE). */
// Poor's man exceptions using setjmp()/longjmp().

/* The compiler keeps no register across a call: a jmp_buf is the two
 * words that coming back a second time takes. An array of one, so that
 * its name is a pointer (setjmp(buf), no &). */
typedef struct Jmpbuf Jmpbuf;
struct Jmpbuf {
	uintptr	sp;	/* stack pointer to rewind to */
	uintptr	pc;	/* return address to jump back to */
};
typedef Jmpbuf jmp_buf[1];

extern  int     setjmp(jmp_buf);
extern  void    longjmp(jmp_buf, int);

