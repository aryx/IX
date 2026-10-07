// mini-xv6, step 2, on the Pi 4 (plan_kernel_mini_ml.md, step 4): what
// ../start.s is for the Pi 1, in Plan 9's assembly: the exception
// vectors, the entry of a system call from user mode (the user's
// registers into the trap frame, then C's trap, which calls the
// kernel's OCaml), the way back. The start itself is step 0's.
// The trap frame (x0-x30, the user's sp, pc and status) is where
// machine.c's cur_tf says: step 3's, one per process, uses this file.
//
// The vectors: 16 entries of 128 bytes, at an address that is a
// multiple of 2048. The assembler has no alignment, so the table is
// the image's first bytes (0x80000): this file is the first linked.
// Its first entry (an exception at EL1 on EL0's stack: never, EL1 runs
// on its own) is then where the board jumps: the branch to the start.

#define VBAR_EL1	SPR(0x18c000)
#define ELR_EL1		SPR(0x184020)
#define SPSR_EL1	SPR(0x184000)
#define SP_EL0		SPR(0x184100)
#define ESR_EL1		SPR(0x185200)
#define TPIDR_EL1	SPR(0x18d080)

#define PAD7	WORD $0; WORD $0; WORD $0; WORD $0; WORD $0; WORD $0; WORD $0
#define PAD31	PAD7; WORD $0; PAD7; WORD $0; PAD7; WORD $0; PAD7
#define NONE	B fault_entry+0(SB); PAD31

TEXT vectors+0(SB), $-8
	B	_start+0(SB)		// 0x000: (EL1, EL0's stack) the image's entry
	PAD31
	NONE
	NONE
	NONE
	B	fault_entry+0(SB)	// 0x200: EL1, a synchronous exception: the kernel's own fault
	PAD31
	NONE
	NONE
	NONE
	B	from_user+0(SB)	// 0x400: from EL0 (AArch64), synchronous: a system call, or a fault
	PAD31
	NONE				// 0x480: an interrupt (none yet: they are masked)
	NONE
	NONE
	NONE				// 0x600: from EL0 in AArch32
	NONE
	NONE
	NONE

#include "../../step0/l.s"

TEXT vectors_install+0(SB), $0
	MOV	$vectors+0(SB), R0
	MSR	R0, VBAR_EL1
	ISB	$15
	RETURN

// From user mode. The stack is EL1's, where the kernel left it when it
// entered user mode: below the frames of the OCaml that did, so the
// collector's view of the stacks stays whole. Every register is the
// user's: the first goes aside in a system register, to hold the
// frame's address. No frame of the linker's ($-8): nothing returns.
TEXT from_user+0(SB), $-8
	MSR	R0, TPIDR_EL1
	MOV	$cur_tf+0(SB), R0
	MOV	(R0), R0
	MOV	R1, 8(R0)
	MOV	R2, 16(R0)
	MOV	R3, 24(R0)
	MOV	R4, 32(R0)
	MOV	R5, 40(R0)
	MOV	R6, 48(R0)
	MOV	R7, 56(R0)
	MOV	R8, 64(R0)
	MOV	R9, 72(R0)
	MOV	R10, 80(R0)
	MOV	R11, 88(R0)
	MOV	R12, 96(R0)
	MOV	R13, 104(R0)
	MOV	R14, 112(R0)
	MOV	R15, 120(R0)
	MOV	R16, 128(R0)
	MOV	R17, 136(R0)
	MOV	R18, 144(R0)
	MOV	R19, 152(R0)
	MOV	R20, 160(R0)
	MOV	R21, 168(R0)
	MOV	R22, 176(R0)
	MOV	R23, 184(R0)
	MOV	R24, 192(R0)
	MOV	R25, 200(R0)
	MOV	R26, 208(R0)
	MOV	R27, 216(R0)
	MOV	R28, 224(R0)
	MOV	R29, 232(R0)
	MOV	R30, 240(R0)
	MRS	TPIDR_EL1, R1
	MOV	R1, 0(R0)
	MRS	SP_EL0, R1
	MOV	R1, 248(R0)
	MRS	ELR_EL1, R1
	MOV	R1, 256(R0)
	MRS	SPSR_EL1, R1
	MOV	R1, 264(R0)
	MOV	$setSB(SB), R28		// the kernel's static base
	MRS	ESR_EL1, R0
	BL	trap+0(SB)
	B	user_return+0(SB)

// to user mode, from the trap frame (the first time too: user_enter)
TEXT user_return+0(SB), $-8
	MOV	$cur_tf+0(SB), R0
	MOV	(R0), R0
	MOV	248(R0), R1
	MSR	R1, SP_EL0
	MOV	256(R0), R1
	MSR	R1, ELR_EL1
	MOV	264(R0), R1
	MSR	R1, SPSR_EL1
	MOV	8(R0), R1
	MOV	16(R0), R2
	MOV	24(R0), R3
	MOV	32(R0), R4
	MOV	40(R0), R5
	MOV	48(R0), R6
	MOV	56(R0), R7
	MOV	64(R0), R8
	MOV	72(R0), R9
	MOV	80(R0), R10
	MOV	88(R0), R11
	MOV	96(R0), R12
	MOV	104(R0), R13
	MOV	112(R0), R14
	MOV	120(R0), R15
	MOV	128(R0), R16
	MOV	136(R0), R17
	MOV	144(R0), R18
	MOV	152(R0), R19
	MOV	160(R0), R20
	MOV	168(R0), R21
	MOV	176(R0), R22
	MOV	184(R0), R23
	MOV	192(R0), R24
	MOV	200(R0), R25
	MOV	208(R0), R26
	MOV	216(R0), R27
	MOV	224(R0), R28
	MOV	232(R0), R29
	MOV	240(R0), R30
	MOV	0(R0), R0
	ERET

// the kernel's own fault, or an exception no one expects: said, the end
TEXT fault_entry+0(SB), $32
	MOV	$setSB(SB), R28
	MRS	ELR_EL1, R1
	MOV	R1, 16(RSP)
	MRS	ESR_EL1, R0
	BL	kfault+0(SB)
	BL	halt+0(SB)
