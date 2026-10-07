// mini-singularity on the Pi 1: the crossing's registers (cross.c says
// which and why). No frame of the assembler's ($-4): the stack is this
// file's.

// sip_enter(entry): into a process, R0 the address it calls the kernel
// at; the link and the value stack's register kept, and where, for
// sip_leave
TEXT sip_enter+0(SB), $-4
	MOVW.W	R14, -4(R13)
	MOVW.W	R10, -4(R13)
	MOVW	R13, sip_sp+0(SB)
	MOVW	R0, R1
	MOVW	$abi_entry+0(SB), R0
	SUB	$16, R13
	BL	(R1)
	B	sip_leave+0(SB)

// sip_leave(): what the process has on the stack dropped; sip_enter returns
TEXT sip_leave+0(SB), $-4
	MOVW	sip_sp+0(SB), R13
	MOVW.P	4(R13), R10
	MOVW.P	4(R13), R14
	RET

// a process's call, R0 the address of its words: the caller's static
// base and value stack's register kept, the kernel's static base set
// (its value stack's top is in ml_vsp, where its ML left it)
TEXT abi_entry+0(SB), $-4
	MOVW.W	R14, -4(R13)
	MOVW.W	R12, -4(R13)
	MOVW.W	R10, -4(R13)
	MOVW	$setR12(SB), R12
	SUB	$16, R13
	BL	abi_dispatch+0(SB)
	ADD	$16, R13
	MOVW.P	4(R13), R10
	MOVW.P	4(R13), R12
	MOVW.P	4(R13), R14
	RET

GLOBL	sip_sp+0(SB), $4
