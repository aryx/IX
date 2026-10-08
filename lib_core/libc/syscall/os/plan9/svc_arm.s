// goken's, around Plan 9's libc (libc's README.md; LICENSE).
// Plan 9's calls on arm, a function each: the kernel reads the
// arguments on the stack, from 4 bytes above its top, which is where
// the compiler put them, all but the first, which comes in R0. So each
// stores R0 in its place, 0(FP), puts the call's number in R0 and
// traps. After the stubs principia's 9syscall/mkfile generates.
#include "sys.h"

// exits(char*): "" or nil for success, else what went wrong
TEXT exits(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$EXITS, R0
	SWI	$0
	RET

TEXT open(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$OPEN, R0
	SWI	$0
	RET

TEXT close(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$CLOSE, R0
	SWI	$0
	RET

TEXT create(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$CREATE, R0
	SWI	$0
	RET

TEXT remove(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$REMOVE, R0
	SWI	$0
	RET

TEXT chdir(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$CHDIR, R0
	SWI	$0
	RET

// dup(old, new): new is -1 for the lowest free one
TEXT dup(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$DUP, R0
	SWI	$0
	RET

// brk: the limit asked, 0 or -1 (port/sbrk.c is over it)
TEXT brk(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$BRK, R0
	SWI	$0
	RET

// fd2path: the path of a descriptor (os/plan9/getwd.c)
TEXT fd2path(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$FD2PATH, R0
	SWI	$0
	RET

// sleep and alarm: milliseconds
TEXT sleep(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$SLEEP, R0
	SWI	$0
	RET

TEXT alarm(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$ALARM, R0
	SWI	$0
	RET

TEXT pread(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$PREAD, R0
	SWI	$0
	RET

TEXT pwrite(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$PWRITE, R0
	SWI	$0
	RET

// fstat, fwstat: a Dir as bytes (os/plan9/stat.c unpacks them)
TEXT fstat(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$FSTAT, R0
	SWI	$0
	RET

TEXT fwstat(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$FWSTAT, R0
	SWI	$0
	RET

// seek gives a vlong: the compiler passes where to write it as the
// first argument, and the kernel writes the offset there itself; R0 is
// 0, or -1 for an error. So -1 is written there only for an error
// (principia's generator does the same), and the kernel's offset is
// left alone otherwise.
TEXT seek(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$SEEK, R0
	SWI	$0
	MOVW	$-1, R2
	CMP	R2, R0
	BNE	seekdone
	MOVW	0(FP), R1
	MOVW	R0, 0(R1)
	MOVW	R0, 4(R1)
seekdone:
	RET

TEXT rfork(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$RFORK, R0
	SWI	$0
	RET

TEXT exec(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$EXEC, R0
	SWI	$0
	RET

TEXT await(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$AWAIT, R0
	SWI	$0
	RET

TEXT pipe(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$PIPE, R0
	SWI	$0
	RET

TEXT notify(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$NOTIFY, R0
	SWI	$0
	RET

TEXT noted(SB), $0
	MOVW	R0, 0(FP)
	MOVW	$NOTED, R0
	SWI	$0
	RET
