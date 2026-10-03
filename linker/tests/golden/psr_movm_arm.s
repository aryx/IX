// the status registers read and written (5l's cases 35 and 36), MOVM with its
// suffixes, the returns of an exception: what a kernel's trap code is made of
TEXT _start+0(SB), $-4
	MOVW	CPSR, R0
	MOVW	R0, CPSR
	MOVW	SPSR, R1
	MOVW	R1, SPSR
	MOVM.IA.S	[R13-R14], (R0)
	MOVM.IA.S	(R1), [R13-R14]
	MOVM.IA	(R0), [R0-R12]
	MOVM.IB	[R1-R12], (R0)
	MOVM.IA.W	(R0), [R2-R9]
	MOVM.IA.W	[R2-R9], (R1)
	MOVW.S	R14, R15
	SWI	$0x40
	MOVW.W	R0, -4(R13)
	MOVW.P	4(R13), R1
	MOVW	$0xd2, R1
	B	(R14)
	BL	(R3)
