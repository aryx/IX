// A process of mini-singularity on the Pi 4: its image's first bytes
// (the kernel calls there, R0 the address of the kernel's entry), and
// its call of the kernel. The static base is this program's own; the
// bss (its heap) cleared, each time it is started. The image's second
// word is where the bss ends: what the kernel reads to know the memory
// the program takes.
TEXT _sipstart+0(SB), $-8
	B	start
	WORD	$0
	DWORD	$end+0(SB)
start:
	MOV	$setSB(SB), R28
	MOV	R0, R4
	MOV	$edata(SB), R1
	MOV	$end(SB), R2
clear:
	CMP	R2, R1
	BHS	cleared
	MOV	ZR, (R1)
	ADD	$8, R1
	B	clear
cleared:
	MOV	R4, sip_kernel+0(SB)
	SUB	$32, RSP, RSP
	BL	sip_main+0(SB)
never:
	B	never

// sip_abi(words): the kernel returns to the caller, the registers of
// this program back (the kernel's cross_arm64.s)
TEXT sip_abi+0(SB), $-8
	MOV	sip_kernel+0(SB), R1
	B	(R1)
