// mini-xv6, step 0, on the Pi 1 (plan_kernel_mini_ml.md, step 9):
// assembly on the bare board, by mini-asm and mini-ld. The image has
// no header and is loaded at 0x8000, where the board's firmware puts
// kernel.img and jumps; a line on the PL011, then the core waits.
// A leaf, without a frame ($-4): no stack yet, and 5l saves the link
// on it at the entry of anything else.

#define WFI	WORD $0xe320f003

TEXT _start+0(SB), $-4
	MOVW	$setR12(SB), R12
	MOVW	$0x20201000, R1		// the PL011: its data register, FR at 0x18
	MOVW	$msg+0(SB), R2
next:
	MOVBU	(R2), R3
	CMP	$0, R3
	BEQ	halt
full:
	MOVW	0x18(R1), R4		// FR's bit 5: the transmit FIFO full
	AND	$0x20, R4
	CMP	$0, R4
	BNE	full
	MOVW	R3, (R1)
	ADD	$1, R2
	B	next
halt:
	WFI
	B	halt

DATA	msg+0(SB)/8, $"mini-xv6"
DATA	msg+8(SB)/8, $": assemb"
DATA	msg+16(SB)/8, $"ly on th"
DATA	msg+24(SB)/8, $"e Pi 1\n\z"
GLOBL	msg+0(SB), $32
