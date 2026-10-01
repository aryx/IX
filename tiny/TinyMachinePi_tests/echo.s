// The PL011's input, by its interrupt (TinyMachinePi_test.sh runs it
// under tiny-pi, mini-qemu and QEMU's raspi4b, echo.input on the UART,
// the output the same): each character received is echoed, a letter
// in upper case, a \r (Enter, from a terminal) as a newline; ^D ends
// it. Loaded at 0x80000, entered at EL2, interrupts masked. The kernel
// waits (WFI) between interrupts.
TEXT _start(SB), $-8
	// down to EL1 (tick.s says how)
	MOV	$0x80000000, R0
	MSR	R0, HCR_EL2
	MOV	$0x3c5, R0
	MSR	R0, SPSR_EL2
	MOV	$kernel(SB), R0
	MSR	R0, ELR_EL2
	ERET

TEXT kernel(SB), $-8
	MOV	$0x80000, R0
	MOV	R0, RSP
	MOV	$0x60000, R0
	MSR	R0, VBAR_EL1
	MOV	$irq(SB), R1
	MOV	$0x60280, R2		// from EL1: an interrupt
	BL	vector(SB)
	MOV	$hello<>(SB), R0
	BL	puts(SB)
	// the UART's receive interrupt (IMSC: RXIM and RTIM), then its
	// line, 153, at the controller: enabled (ISENABLER4's bit 25), sent
	// to this CPU (ITARGETSR's byte 153)
	MOV	$0xfe201000, R0
	MOV	$0x50, R1
	MOVW	R1, 0x38(R0)
	MOV	$0xff841000, R0
	MOV	$1, R1
	MOVW	R1, (R0)		// GICD_CTLR
	MOVB	R1, 0x899(R0)		// GICD_ITARGETSR + 153
	MOV	$0x2000000, R1
	MOVW	R1, 0x110(R0)		// GICD_ISENABLER4
	MOV	$0xff842000, R0
	MOV	$0xff, R1
	MOVW	R1, 4(R0)		// GICC_PMR
	MOV	$1, R1
	MOVW	R1, (R0)		// GICC_CTLR
	MOV	$0, R1
	MSR	R1, DAIF		// interrupts in
	// done checked before each wait: its interrupt may have come already
wait:
	MOVW	done<>(SB), R0
	CBNZ	R0, finish
	WFI
	B	wait
finish:
	MOV	$0x3c0, R1
	MSR	R1, DAIF
	MOV	$bye<>(SB), R0
	BL	puts(SB)
halt:
	WFI				// interrupts masked: never taken
	B	halt

// the UART's interrupt: every character waiting, until FR says the
// receive FIFO empty (which lowers the line)
TEXT irq(SB), $-8
	SUB	$48, RSP
	MOV	R0, 0(RSP)
	MOV	R1, 8(RSP)
	MOV	R2, 16(RSP)
	MOV	R3, 24(RSP)
	MOV	R30, 32(RSP)
	MOV	$0xff842000, R0
	MOVWU	0xc(R0), R0		// GICC_IAR
	MOV	R0, 40(RSP)
	MOV	$0xfe201000, R2
more:
	MOVWU	0x18(R2), R3
	TST	$0x10, R3		// FR: RXFE
	BNE	out
	MOVWU	(R2), R1		// DR: the character in
	AND	$0xff, R1
	CMP	$4, R1			// ^D
	BEQ	end
	CMP	$13, R1			// \r: a newline
	BNE	letter
	MOV	$10, R1
letter:
	SUB	$97, R1, R3		// a letter: 'a' to 'z' in upper case
	CMP	$26, R3
	BHS	put
	SUB	$32, R1
put:
	MOVWU	0x18(R2), R3
	TST	$0x20, R3
	BNE	put
	MOVW	R1, (R2)
	B	more
end:
	MOV	$1, R1
	MOVW	R1, done<>(SB)
	B	more
out:
	MOV	40(RSP), R1
	MOV	$0xff842000, R0
	MOVW	R1, 0x10(R0)		// GICC_EOIR
	MOV	0(RSP), R0
	MOV	8(RSP), R1
	MOV	16(RSP), R2
	MOV	24(RSP), R3
	MOV	32(RSP), R30
	ADD	$48, RSP
	ERET

// vector: a branch to the handler at R1 written at the vector at R2
TEXT vector(SB), $-8
	SUB	R2, R1
	LSR	$2, R1
	AND	$0x3ffffff, R1
	MOV	$0x14000000, R3		// B, and its offset in words
	ORR	R3, R1
	MOVW	R1, (R2)
	RETURN

// puts: the string at R0 to the PL011 (R0-R3 used)
TEXT puts(SB), $-8
	MOV	$0xfe201000, R2
puts_next:
	MOVBU	(R0), R1
	CBZ	R1, puts_done
puts_wait:
	MOVWU	0x18(R2), R3
	TST	$0x20, R3
	BNE	puts_wait
	MOVW	R1, (R2)
	ADD	$1, R0
	B	puts_next
puts_done:
	RETURN

DATA	done<>+0(SB)/4, $0
DATA	hello<>+0(SB)/23, $"echo: type, ^D to end\n"
DATA	bye<>+0(SB)/21, $"echo: done, halting\n"
