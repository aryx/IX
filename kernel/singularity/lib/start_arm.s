// A process of mini-singularity on the Pi 1: its image's first bytes
// (the kernel calls there, R0 the address of the kernel's entry), and
// its call of the kernel. The static base is this program's own; the
// bss (its heap) cleared, each time it is started. The image's second
// word is where the bss ends: what the kernel reads to know the memory
// the program takes.
TEXT _sipstart+0(SB), $-4
	B	start
	WORD	$end+0(SB)
start:
	MOVW	$setR12(SB), R12
	MOVW	R0, R4
	MOVW	$edata(SB), R1
	MOVW	$end(SB), R2
	MOVW	$0, R3
clear:
	CMP	R2, R1
	BHS	cleared
	MOVW.P	R3, 4(R1)
	B	clear
cleared:
	MOVW	R4, sip_kernel+0(SB)
	SUB	$16, R13
	BL	sip_main+0(SB)
never:
	B	never

// sip_abi(words): the kernel returns to the caller, the registers of
// this program back (the kernel's cross_arm.s)
TEXT sip_abi+0(SB), $-4
	MOVW	sip_kernel+0(SB), R1
	B	(R1)
