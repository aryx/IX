// goken's, around Plan 9's libc (libc's README.md; LICENSE).
// Where a Linux arm process starts (and a Plan 9 one): the static
// base in R12, main(argc, argv), then exit(0) if main comes back. The
// kernel leaves argc at 0(R13) and argv from 4(R13); here they are 4
// further, the assembler pushing the link register first in a TEXT
// that calls. main wants argc in R0 and argv on the stack, at 8(R13)
// once room is made below (found with a debugger, not derived). R13 by
// its name, so that the linker does not rewrite the offsets.
TEXT _main+0(SB), $0
	MOVW	$setR12(SB), R12
	MOVW	4(R13), R0	// argc
	ADD	$8, R13, R1	// argv
	MOVW	R1, _mainargv+0(SB)	// see port/mainargs.c
	MOVW	R0, _mainargc+0(SB)	// see port/mainargs.c's own _mainargc comment
	SUB	$12, R13
	MOVW	R1, 8(R13)
	BL	main+0(SB)
	MOVW	$0, R0
	BL	exit+0(SB)
loop:
	B	loop
