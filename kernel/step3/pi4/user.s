// mini-xv6, step 3, on the Pi 4: the user program, ../user.s's in
// Plan 9's assembly for arm64, with xv6 arm-pi1's convention as step
// 2's. Three rounds of "process P, round R", a sleep after each, then
// exit(10 * P).

TEXT user_main+0(SB), $-8
	BL	getpid<>+0(SB)
	MOV	R0, R4			// P
	MOV	$1, R5			// R
round:
	SUB	$32, RSP		// the line copied to the stack, its two digits set
	MOV	$line+0(SB), R0
	MOV	RSP, R7
copy:
	MOVBU	(R0), R3
	MOVB	R3, (R7)
	ADD	$1, R0
	ADD	$1, R7
	CBNZ	R3, copy
	ADD	$48, R4, R3
	MOVB	R3, 8(RSP)
	ADD	$48, R5, R3
	MOVB	R3, 17(RSP)
	MOV	$1, R0
	MOV	RSP, R1
	MOV	$19, R2
	BL	write<>+0(SB)
	ADD	$32, RSP
	MOV	$1, R0
	BL	sleep<>+0(SB)
	ADD	$1, R5
	CMP	$3, R5
	BLE	round
	MOV	$10, R0
	MUL	R4, R0
	BL	exit<>+0(SB)
spin:
	B	spin

// a system call: its number in R0, its arguments on the stack, 32 bits
// each (the names are this file's, <>: the kernel's C library has a
// write and an exit too, and the image is one)
TEXT call<>+0(SB), $-8
	SUB	$16, RSP
	MOVW	R0, 0(RSP)
	MOVW	R1, 4(RSP)
	MOVW	R2, 8(RSP)
	MOV	R6, R0
	SVC	$0
	ADD	$16, RSP
	RET	(R30)

TEXT exit<>+0(SB), $-8
	MOV	$2, R6
	B	call<>+0(SB)
TEXT getpid<>+0(SB), $-8
	MOV	$11, R6
	B	call<>+0(SB)
TEXT sleep<>+0(SB), $-8
	MOV	$13, R6
	B	call<>+0(SB)
TEXT write<>+0(SB), $-8
	MOV	$16, R6
	B	call<>+0(SB)

DATA	line+0(SB)/8, $"process "
DATA	line+8(SB)/8, $"P, round"
DATA	line+16(SB)/4, $" R\n\z"
GLOBL	line+0(SB), $24
