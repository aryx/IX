// mini-xv6, step 0 (plan_kernel_mini_ml.md, step 1): assembly on the
// bare Pi 4, by mini-asm and mini-ld. The image has no header and is
// loaded at 0x80000, where the board's firmware (and QEMU's -kernel)
// puts kernel8.img and jumps; a line on the PL011, then the core waits.
// A leaf: no stack yet, so no call (7l saves the link on the stack).

#define MPIDR_EL1 SPR(0x1800a0)

TEXT _start+0(SB), $0
	MRS	MPIDR_EL1, R0		// the first core only: the board starts the four here
	AND	$3, R0
	CBNZ	R0, halt
	MOV	$setSB(SB), R28
	MOV	$0xFE201000, R1		// the PL011: its data register, FR at 0x18
	MOV	$msg+0(SB), R2
next:
	MOVBU	(R2), R3
	CBZ	R3, halt
full:
	MOVWU	0x18(R1), R4		// FR's bit 5: the transmit FIFO full
	AND	$0x20, R4
	CBNZ	R4, full
	MOVW	R3, (R1)
	ADD	$1, R2
	B	next
halt:
	WFI
	B	halt

DATA	msg+0(SB)/8, $"mini-xv6"
DATA	msg+8(SB)/8, $": assemb"
DATA	msg+16(SB)/8, $"ly on th"
DATA	msg+24(SB)/8, $"e Pi 4\n\z"
GLOBL	msg+0(SB), $32
