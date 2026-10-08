// TinyMachinePi's kernel, a page: the exception levels, the two
// exceptions a program makes, a timer's interrupts, on a Pi 4
// (TinyMachinePi_test.sh runs it under tiny-pi, mini-qemu and QEMU's
// raspi4b, the output the same). Loaded at 0x80000 and entered there
// at EL2, interrupts masked, as the firmware starts kernel8.img. Its
// console: the PL011.
TEXT _start(SB), $-8
	// down to EL1, the kernel's level: AArch64 there (HCR_EL2's RW),
	// on its own stack pointer, interrupts masked (SPSR_EL2), at kernel
	MOV	$0x80000000, R0
	MSR	R0, HCR_EL2
	MOV	$0x3c5, R0
	MSR	R0, SPSR_EL2
	MOV	$kernel(SB), R0
	MSR	R0, ELR_EL2
	ERET

TEXT kernel(SB), $-8
	MOV	$0x80000, R0		// the stack: below the image
	MOV	R0, RSP
	// the vectors, sixteen of 128 bytes at 0x60000: a branch at the
	// two this kernel takes
	MOV	$0x60000, R0
	MSR	R0, VBAR_EL1
	MOV	$sync(SB), R1
	MOV	$0x60400, R2		// from EL0: a system call, an undefined instruction
	BL	vector(SB)
	MOV	$irq(SB), R1
	MOV	$0x60280, R2		// from EL1: an interrupt
	BL	vector(SB)
	MOV	$hello<>(SB), R0
	BL	puts(SB)
	// to user mode: its stack, then an exception return into it (EL0,
	// interrupts still masked)
	MOV	$0x70000, R0
	MSR	R0, SP_EL0
	MOV	$0x3c0, R0
	MSR	R0, SPSR_EL1
	MOV	$user(SB), R0
	MSR	R0, ELR_EL1
	ERET

// the program: system calls, and an undefined instruction between them
TEXT user(SB), $-8
	MOV	$from_user<>(SB), R0
	SVC	$0			// 0: print the string at R0
	WORD	$0			// undefined: the kernel skips it
	MOV	$back<>(SB), R0
	SVC	$0
	SVC	$1			// 1: done; the kernel takes over
never:
	B	never

// an exception from the program. ESR_EL1 says which: its top six bits
// 0x15 for an svc, whose number is the low sixteen
TEXT sync(SB), $-8
	SUB	$48, RSP
	MOV	R0, 0(RSP)
	MOV	R1, 8(RSP)
	MOV	R2, 16(RSP)
	MOV	R3, 24(RSP)
	MOV	R30, 32(RSP)
	MRS	ESR_EL1, R1
	LSR	$26, R1, R2
	CMP	$0x15, R2
	BNE	other
	AND	$0xffff, R1
	CMP	$1, R1
	BEQ	ticks
	BL	puts(SB)
	B	resume
other:
	// an undefined instruction: said, and skipped (ELR_EL1 is on it)
	MOV	$undefined<>(SB), R0
	BL	puts(SB)
	MRS	ELR_EL1, R0
	ADD	$4, R0
	MSR	R0, ELR_EL1
resume:
	MOV	0(RSP), R0
	MOV	8(RSP), R1
	MOV	16(RSP), R2
	MOV	24(RSP), R3
	MOV	32(RSP), R30
	ADD	$48, RSP
	ERET				// back to the program: its state from SPSR_EL1

// svc 1: the virtual timer every 10ms, five times, then halt
ticks:
	MOV	$started<>(SB), R0
	BL	puts(SB)
	// the interrupt controller (a GIC-400): its distributor on, the
	// timer's line (27) enabled; this CPU's interface on, every
	// priority let through
	MOV	$0xff841000, R0
	MOV	$1, R1
	MOVW	R1, (R0)		// GICD_CTLR
	MOV	$0x8000000, R1
	MOVW	R1, 0x100(R0)		// GICD_ISENABLER0, bit 27
	MOV	$0xff842000, R0
	MOV	$0xff, R1
	MOVW	R1, 4(R0)		// GICC_PMR
	MOV	$1, R1
	MOVW	R1, (R0)		// GICC_CTLR
	BL	later(SB)
	MOV	$1, R1
	MSR	R1, CNTV_CTL_EL0	// the timer on
	MOV	$0, R1
	MSR	R1, DAIF		// interrupts in
wait:
	WFI
	MOVW	count<>(SB), R0
	CMP	$5, R0
	BLT	wait
	MOV	$0x3c0, R1
	MSR	R1, DAIF		// and out
	MOV	$done<>(SB), R0
	BL	puts(SB)
halt:
	WFI				// interrupts masked: never taken
	B	halt

// later: the timer's next interrupt 10ms from now, a hundredth of the
// counter's frequency (which lowers its line)
TEXT later(SB), $-8
	MRS	CNTFRQ_EL0, R1
	MOV	$100, R2
	UDIV	R2, R1
	MSR	R1, CNTV_TVAL_EL0
	RETURN

// the timer's interrupt: acknowledged at the controller (IAR says
// which), the next one 10ms on, the count up and said, ended (EOIR);
// back to the interrupted instruction
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
	BL	later(SB)
	MOVW	count<>(SB), R1
	ADD	$1, R1
	MOVW	R1, count<>(SB)
	ADD	$48, R1
	MOVB	R1, tick<>+13(SB)	// the digit
	MOV	$tick<>(SB), R0
	BL	puts(SB)
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

DATA	count<>+0(SB)/4, $0
DATA	hello<>+0(SB)/33, $"TinyMachinePi: a kernel, at EL1\n"
DATA	from_user<>+0(SB)/29, $"user: hello, from user mode\n"
DATA	back<>+0(SB)/28, $"user: back from the kernel\n"
DATA	undefined<>+0(SB)/43, $"kernel: an undefined instruction, skipped\n"
DATA	started<>+0(SB)/31, $"kernel: the timer, every 10ms\n"
DATA	tick<>+0(SB)/16, $"kernel: tick 0\n"
DATA	done<>+0(SB)/23, $"kernel: done, halting\n"
