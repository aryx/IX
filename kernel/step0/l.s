// mini-xv6, step 0: the start of a C program on the bare Pi 4 (and of
// the OCaml ones of the next steps), by mini-asm. What C cannot say:
// the first core alone, down to EL1 with the floating point allowed,
// the bss cleared (the image has only the text and the data), a stack,
// the static base (R28: 7c's code reaches its data from it), then main.
// kernel/lib/pi4/start.s's first lines, in Plan 9's assembly.
//
// Each piece is a leaf (no call: there is no stack yet, and 7l's entry
// of a function that calls saves the link on it), entered by a branch
// or by ERET, whose address is the next piece's name.

#define MPIDR_EL1	SPR(0x1800a0)
#define CurrentEL	SPR(0x184240)
#define SCR_EL3		SPR(0x1e1100)
#define ELR_EL3		SPR(0x1e4020)
#define SPSR_EL3	SPR(0x1e4000)
#define HCR_EL2		SPR(0x1c1100)
#define CPTR_EL2	SPR(0x1c1140)
#define ELR_EL2		SPR(0x1c4020)
#define SPSR_EL2	SPR(0x1c4000)
#define CPACR_EL1	SPR(0x181040)

TEXT _start+0(SB), $0
	MRS	MPIDR_EL1, R1		// the board starts its four cores here
	AND	$3, R1
	CBNZ	R1, park
	MRS	CurrentEL, R0
	AND	$0xc, R0
	CMP	$12, R0
	BEQ	el3
	B	el2+0(SB)
el3:					// EL3 to EL2: non-secure, AArch64 below
	MOV	$0x4b1, R0
	MSR	R0, SCR_EL3
	MOV	$el2+0(SB), R1
	MSR	R1, ELR_EL3
	MOV	$0x3c9, R2
	MSR	R2, SPSR_EL3
	ERET
park:
	WFE
	B	park

// EL2 (the firmware's, and QEMU's for an image) to EL1: AArch64, the
// floating point not trapped, EL1's own stack pointer, the interrupts masked
TEXT el2+0(SB), $0
	MRS	CurrentEL, R0
	AND	$0xc, R0
	CMP	$8, R0
	BEQ	at2
	B	el1+0(SB)
at2:
	MOV	$0x80000002, R0
	MSR	R0, HCR_EL2
	MOV	$0x33ff, R0
	MSR	R0, CPTR_EL2
	MOV	$el1+0(SB), R1
	MSR	R1, ELR_EL2
	MOV	$0x3c5, R2
	MSR	R2, SPSR_EL2
	ERET

TEXT el1+0(SB), $0
	MOV	$0x300000, R0		// the floating point: the runtime's doubles
	MSR	R0, CPACR_EL1
	ISB	$15
	MOV	$setSB(SB), R28
	MOV	$edata(SB), R1		// the bss, to its end (8 bytes at a time: both are aligned)
	MOV	$end(SB), R2
clear:
	CMP	R2, R1
	BHS	cleared
	MOV	ZR, (R1)
	ADD	$8, R1
	B	clear
cleared:
	MOV	$kstack+1048576(SB), R1
	MOV	R1, RSP
	B	boot+0(SB)

// main(0, nil): no arguments (the runtime's main keeps them, for Sys.argv)
TEXT boot+0(SB), $32
	MOV	$0, R0
	MOV	ZR, 16(RSP)
	BL	main+0(SB)
	BL	halt+0(SB)

// the end: the core waits for an interrupt that does not come
TEXT halt+0(SB), $0
	WFI
	B	-1(PC)

GLOBL	kstack+0(SB), $1048576
