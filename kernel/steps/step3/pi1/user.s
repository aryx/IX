// mini-xv6, step 3, on the Pi 1 by ix's tools: the user program,
// ../user.s's in Plan 9's assembly, with xv6 arm-pi1's convention as
// step 2's. Three rounds of "process P, round R", a sleep after each,
// then exit(10 * P).

TEXT user_main+0(SB), $-4
	MOVW	$setR12(SB), R12	// the image is the kernel's: its static base
	BL	getpid<>+0(SB)
	MOVW	R0, R4			// P
	MOVW	$1, R5			// R
round:
	SUB	$24, R13		// the line copied to the stack, its two digits set
	MOVW	$line+0(SB), R0
	MOVW	R13, R7
copy:
	MOVBU	(R0), R3
	MOVB	R3, (R7)
	ADD	$1, R0
	ADD	$1, R7
	CMP	$0, R3
	BNE	copy
	ADD	$48, R4, R3
	MOVB	R3, 8(R13)
	ADD	$48, R5, R3
	MOVB	R3, 17(R13)
	MOVW	$1, R0
	MOVW	R13, R1
	MOVW	$19, R2
	BL	write<>+0(SB)
	ADD	$24, R13
	MOVW	$1, R0
	BL	sleep<>+0(SB)
	ADD	$1, R5
	CMP	$3, R5
	BLE	round
	MOVW	$10, R0
	MUL	R4, R0
	BL	exit<>+0(SB)
spin:
	B	spin

// a system call: its number in R0, its arguments on the stack (the
// names are this file's, <>: the kernel's C library has a write and an
// exit too, and the image is one)
TEXT call<>+0(SB), $-4
	SUB	$16, R13
	MOVW	R0, 0(R13)
	MOVW	R1, 4(R13)
	MOVW	R2, 8(R13)
	MOVW	R6, R0
	SWI	$0x40
	ADD	$16, R13
	RET

TEXT exit<>+0(SB), $-4
	MOVW	$2, R6
	B	call<>+0(SB)
TEXT getpid<>+0(SB), $-4
	MOVW	$11, R6
	B	call<>+0(SB)
TEXT sleep<>+0(SB), $-4
	MOVW	$13, R6
	B	call<>+0(SB)
TEXT write<>+0(SB), $-4
	MOVW	$16, R6
	B	call<>+0(SB)

DATA	line+0(SB)/8, $"process "
DATA	line+8(SB)/8, $"P, round"
DATA	line+16(SB)/4, $" R\n\z"
GLOBL	line+0(SB), $24
