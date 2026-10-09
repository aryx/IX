// TinyLib's C library, its assembly: lib_core/libc/arch/arm64/rt0.s and
// syscall/os/linux/svc_arm64.s (goken's, around Plan 9's libc: its
// README.md, LICENSE), in one file.

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
	MOV	R1, _mainargv+0(SB)	// libc.c's getenv: the environment is after them
	MOV	R0, _mainargc+0(SB)
	SUB	$32, RSP, RSP
	MOV	R1, 16(RSP)
	BL	main+0(SB)
	MOV	$0, R0
	BL	exit+0(SB)
loop:
	B	loop

// The way into Linux's kernel on arm64: the number in R8, six
// arguments in R0 to R5. Only the first argument of a C call comes in
// a register (R0, the number); the others are on the stack, from
// 8(FP).
TEXT _syscall6+0(SB), $0
	MOV	R0, R8
	MOV	a1+8(FP), R0
	MOV	a2+16(FP), R1
	MOV	a3+24(FP), R2
	MOV	a4+32(FP), R3
	MOV	a5+40(FP), R4
	MOV	a6+48(FP), R5
	SVC	$0
	RETURN
