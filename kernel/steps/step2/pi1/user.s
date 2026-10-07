// mini-xv6, step 2, on the Pi 1 by ix's tools: the user program,
// ../user.s's in Plan 9's assembly. xv6 arm-pi1's convention: a call's
// number in r0, its arguments on the stack, swi 0x40. Linked in the
// kernel's image (no memory of its own yet), so its static base is the
// kernel's, set here: a user's registers start at 0.

TEXT user_main+0(SB), $-4
	MOVW	$setR12(SB), R12
	SUB	$16, R13
	MOVW	$1, R1			// write(1, hello, 22)
	MOVW	R1, 0(R13)
	MOVW	$hello+0(SB), R1
	MOVW	R1, 4(R13)
	MOVW	$22, R1
	MOVW	R1, 8(R13)
	MOVW	$16, R0			// SYS_write
	SWI	$0x40			// T_SYSCALL
	MOVW	$7, R1			// exit(7)
	MOVW	R1, 0(R13)
	MOVW	$2, R0			// SYS_exit
	SWI	$0x40
spin:
	B	spin

DATA	hello+0(SB)/8, $"hello, f"
DATA	hello+8(SB)/8, $"rom user"
DATA	hello+16(SB)/8, $" mode\n\z\z"
GLOBL	hello+0(SB), $24
GLOBL	ustack+0(SB), $4096
