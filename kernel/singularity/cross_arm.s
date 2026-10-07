// mini-singularity on the Pi 1: the crossing's registers and stacks
// (cross.c says which and why). No frame of the assembler's ($-4): the
// stacks are this file's. sip_cur is the running thread's two words:
// its kernel stack's place (0), its program's (4).

// sip_enter(entry): into a process, R0 the address it calls the kernel
// at, on its own stack; the link and the value stack's register kept
// on the kernel's
TEXT sip_enter+0(SB), $-4
	MOVW.W	R14, -4(R13)
	MOVW.W	R10, -4(R13)
	MOVW	sip_cur+0(SB), R2
	MOVW	R13, 0(R2)
	MOVW	4(R2), R13
	MOVW	R0, R1
	MOVW	$abi_entry+0(SB), R0
	BL	(R1)
	B	sip_leave+0(SB)

// sip_leave(): the program's stack left as it is, what the call has on
// the kernel's dropped; sip_enter returns
TEXT sip_leave+0(SB), $-4
	MOVW	sip_cur+0(SB), R2
	MOVW	0(R2), R13
	MOVW.P	4(R13), R10
	MOVW.P	4(R13), R14
	RET

// a process's call, R0 the address of its words: the caller's link,
// static base and value stack's register kept on its stack; the
// kernel's static base, and the thread's kernel stack from where
// sip_enter left it (the kernel's value stack's top is in ml_vsp,
// where its ML left it). R0 goes through, the words in and the answer
// out.
TEXT abi_entry+0(SB), $-4
	MOVW.W	R14, -4(R13)
	MOVW.W	R12, -4(R13)
	MOVW.W	R10, -4(R13)
	MOVW	$setR12(SB), R12
	MOVW	sip_cur+0(SB), R2
	MOVW	R13, 4(R2)
	MOVW	0(R2), R13
	SUB	$16, R13
	BL	abi_dispatch+0(SB)
	MOVW	sip_cur+0(SB), R2
	MOVW	4(R2), R13
	MOVW.P	4(R13), R10
	MOVW.P	4(R13), R12
	MOVW.P	4(R13), R14
	RET
