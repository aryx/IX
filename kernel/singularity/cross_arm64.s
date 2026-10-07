// mini-singularity on the Pi 4: the crossing's registers (cross.c says
// which and why). No frame of the assembler's ($-8): the stack is this
// file's, a multiple of 16, its first two words left to the callee.

// sip_enter(entry): into a process, R0 the address it calls the kernel
// at; the link and the value stack's register kept, and where, for
// sip_leave
TEXT sip_enter+0(SB), $-8
	SUB	$32, RSP, RSP
	MOV	R30, 16(RSP)
	MOV	R26, 24(RSP)
	MOV	RSP, R1
	MOV	R1, sip_sp+0(SB)
	MOV	R0, R1
	MOV	$abi_entry+0(SB), R0
	BL	(R1)
	B	sip_leave+0(SB)

// sip_leave(): what the process has on the stack dropped; sip_enter returns
TEXT sip_leave+0(SB), $-8
	MOV	sip_sp+0(SB), R1
	MOV	R1, RSP
	MOV	16(RSP), R30
	MOV	24(RSP), R26
	ADD	$32, RSP, RSP
	RET	(R30)

// a process's call, R0 the address of its words: the caller's static
// base and value stack's register kept, the kernel's static base set
// (its value stack's top is in ml_vsp, where its ML left it)
TEXT abi_entry+0(SB), $-8
	SUB	$48, RSP, RSP
	MOV	R30, 16(RSP)
	MOV	R28, 24(RSP)
	MOV	R26, 32(RSP)
	MOV	$setSB(SB), R28
	BL	abi_dispatch+0(SB)
	MOV	32(RSP), R26
	MOV	24(RSP), R28
	MOV	16(RSP), R30
	ADD	$48, RSP, RSP
	RET	(R30)

GLOBL	sip_sp+0(SB), $8
