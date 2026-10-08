// The smallest bare-metal program for the Pi 4 (TinyMachinePi_test.sh
// runs it under tiny-pi, mini-qemu and QEMU's raspi4b): loaded at
// 0x80000 and entered there at EL2, interrupts masked, as the firmware
// starts kernel8.img. It writes a line to the PL011 and halts: a WFI
// with interrupts masked and none coming never wakes.
TEXT _start(SB), $-8
	MOV	$message<>(SB), R0
	MOV	$0xfe201000, R2		// the PL011
next:
	MOVBU	(R0), R1
	CBZ	R1, halt
wait:
	MOVWU	0x18(R2), R3		// FR: while the transmit FIFO is full
	TST	$0x20, R3
	BNE	wait
	MOVW	R1, (R2)		// DR: the character out
	ADD	$1, R0
	B	next
halt:
	WFI
	B	halt

DATA	message<>+0(SB)/11, $"hello, Pi\n"
