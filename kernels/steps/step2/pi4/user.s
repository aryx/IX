// mini-xv6, step 2, on the Pi 4: the user program, ../user.s's in
// Plan 9's assembly for arm64. xv6 arm-pi1's convention kept (so that
// Main.ml is the Pi 1's): the call's number in the first register, its
// arguments on the stack, 32 bits each.

TEXT user_main+0(SB), $-8
	SUB	$16, RSP
	MOVW	$1, R1			// write(1, hello, 22)
	MOVW	R1, 0(RSP)
	MOV	$hello+0(SB), R1
	MOVW	R1, 4(RSP)
	MOVW	$22, R1
	MOVW	R1, 8(RSP)
	MOV	$16, R0			// SYS_write
	SVC	$0
	MOVW	$7, R1			// exit(7)
	MOVW	R1, 0(RSP)
	MOV	$2, R0			// SYS_exit
	SVC	$0
spin:
	B	spin

DATA	hello+0(SB)/8, $"hello, f"
DATA	hello+8(SB)/8, $"rom user"
DATA	hello+16(SB)/8, $" mode\n\z\z"
GLOBL	hello+0(SB), $24
GLOBL	ustack+0(SB), $4096
