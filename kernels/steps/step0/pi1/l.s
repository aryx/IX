// mini-xv6, step 0, on the Pi 1: the start of a C program on the bare
// board (and of the OCaml ones of the next steps), by mini-asm. What C
// cannot say: the floating point allowed (the VFP: the C library's and
// the runtime's doubles), the bss cleared (the image has only the text
// and the data), a stack, the static base (R12: 5c's code reaches its
// data from it), then main. kernels/steps/step1/start.s's lines, in Plan 9's
// assembly; the firmware enters in SVC mode, the interrupts masked.
//
// _start is a leaf without a frame ($-4): there is no stack yet, and
// 5l's entry of anything else saves the link on it.

// (mini-asm has no coprocessor instruction for arm: their words)
#define MRC_CPACR_R0	WORD $0xee110f50	// mrc p15, 0, r0, c1, c0, 2
#define MCR_R0_CPACR	WORD $0xee010f50	// mcr p15, 0, r0, c1, c0, 2
#define VMSR_R0_FPEXC	WORD $0xeee80a10	// vmsr fpexc, r0
#define WFI		WORD $0xe320f003

TEXT _start+0(SB), $-4
	MOVW	$setR12(SB), R12
	MRC_CPACR_R0			// cp10 and cp11 (the VFP): full access
	ORR	$0xf00000, R0
	MCR_R0_CPACR
	MOVW	$0x40000000, R0		// FPEXC.EN
	VMSR_R0_FPEXC
	MOVW	$edata(SB), R1		// the bss, to its end (a word at a time: both are aligned)
	MOVW	$end(SB), R2
	MOVW	$0, R3
clear:
	CMP	R2, R1
	BHS	cleared
	MOVW	R3, (R1)
	ADD	$4, R1
	B	clear
cleared:
	MOVW	$kstack+1048576(SB), R13
	B	boot+0(SB)

// main(0, nil): no arguments (the runtime's main keeps them, for Sys.argv)
TEXT boot+0(SB), $16
	MOVW	$0, R0
	MOVW	R0, 8(R13)
	BL	main+0(SB)
	BL	halt+0(SB)

// the end: the core waits for an interrupt that does not come
TEXT halt+0(SB), $-4
	WFI
	B	-1(PC)

GLOBL	kstack+0(SB), $1048576
