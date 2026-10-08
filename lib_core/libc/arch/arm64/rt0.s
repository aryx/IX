// goken's, around Plan 9's libc (libc's README.md; LICENSE).
// Where a Linux arm64 process starts: the static base, main(argc,
// argv), then exit(0) if main comes back. The kernel leaves argc at
// the top of the stack and argv after it; here they are 16 bytes
// further, the assembler having made room for the link register (a
// TEXT that calls), and main's argv goes at 16 of the new stack for
// the same reason: both offsets were found by trying.
TEXT _main+0(SB), $0
	MOV	$setSB(SB), R28
	MOV	16(RSP), R0	// argc
	ADD	$24, RSP, R1	// argv
	MOV	R1, _mainargv+0(SB)	// see port/mainargs.c
	MOV	R0, _mainargc+0(SB)	// see port/mainargs.c's own _mainargc comment
	SUB	$32, RSP, RSP
	MOV	R1, 16(RSP)
	BL	main+0(SB)
	MOV	$0, R0
	BL	exit+0(SB)
loop:
	B	loop
