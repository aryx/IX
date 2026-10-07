// mini-singularity on the Pi 4: the crossing's registers and stacks
// (cross.c says which and why). No frame of the assembler's ($-8): the
// stacks are this file's, a multiple of 16, the first two words left
// to the callee. sip_cur is the running thread's two words: its kernel
// stack's place (0), its program's (8).

// sip_enter(entry): into a process, R0 the address it calls the kernel
// at, on its own stack; the link and the value stack's register kept
// on the kernel's
TEXT sip_enter+0(SB), $-8
	SUB	$32, RSP, RSP
	MOV	R30, 16(RSP)
	MOV	R26, 24(RSP)
	MOV	sip_cur+0(SB), R2
	MOV	RSP, R1
	MOV	R1, 0(R2)
	MOV	8(R2), R1
	MOV	R1, RSP
	MOV	R0, R1
	MOV	$abi_entry+0(SB), R0
	BL	(R1)
	B	sip_leave+0(SB)

// sip_leave(): the program's stack left as it is, what the call has on
// the kernel's dropped; sip_enter returns
TEXT sip_leave+0(SB), $-8
	MOV	sip_cur+0(SB), R2
	MOV	0(R2), R1
	MOV	R1, RSP
	MOV	16(RSP), R30
	MOV	24(RSP), R26
	ADD	$32, RSP, RSP
	RET	(R30)

// a process's call, R0 the address of its words: the caller's link,
// static base and value stack's register kept on its stack; the
// kernel's static base, and the thread's kernel stack from where
// sip_enter left it (the kernel's value stack's top is in ml_vsp,
// where its ML left it). R0 goes through, the words in and the answer
// out.
TEXT abi_entry+0(SB), $-8
	SUB	$32, RSP, RSP
	MOV	R30, 0(RSP)
	MOV	R28, 8(RSP)
	MOV	R26, 16(RSP)
	MOV	$setSB(SB), R28
	MOV	sip_cur+0(SB), R2
	MOV	RSP, R1
	MOV	R1, 8(R2)
	MOV	0(R2), R1
	SUB	$32, R1
	MOV	R1, RSP
	BL	abi_dispatch+0(SB)
	MOV	sip_cur+0(SB), R2
	MOV	8(R2), R1
	MOV	R1, RSP
	MOV	16(RSP), R26
	MOV	8(RSP), R28
	MOV	0(RSP), R30
	ADD	$32, RSP, RSP
	RET	(R30)

// the generic timer's count and its frequency (cross.c's sip_time)
#define CNTFRQ_EL0	SPR(0x1be000)
#define CNTVCT_EL0	SPR(0x1be040)
TEXT cntvct+0(SB), $-8
	MRS	CNTVCT_EL0, R0
	RET	(R30)
TEXT cntfrq+0(SB), $-8
	MRS	CNTFRQ_EL0, R0
	RET	(R30)
