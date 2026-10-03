// mini-xv6, step 2, on the Pi 1 by ix's tools (plan_kernel_mini_ml.md,
// step 9): what ../start.s is for the Makefile's build, in Plan 9's
// assembly: the exception vectors, the entry of a system call from
// user mode (the user's registers into the trap frame, then C's trap,
// which calls the kernel's OCaml), the way back. The start itself is
// step 0's, and the image's first bytes: the board jumps there.
// The trap frame (17 words: r0-r12, the user's sp and lr, the pc to go
// back to, the user's status) is where machine.c's cur_tf says: step
// 3's, one per process, uses this file.
//
// The static base (R12) is the kernel's only in the kernel: a user's
// program has its own value there. An entry sets it again, from the
// constants after the code, before it names anything.

#include "../../step0/pi1/l.s"

#define NOP	MOVW R0, R0

// the vectors, copied to 0: eight "ldr pc, [pc, #24]", then their addresses
TEXT vectors+0(SB), $-4
	WORD	$0xe59ff018		// 0x00 reset
	WORD	$0xe59ff018		// 0x04 undefined
	WORD	$0xe59ff018		// 0x08 svc
	WORD	$0xe59ff018		// 0x0c prefetch abort
	WORD	$0xe59ff018		// 0x10 data abort
	WORD	$0xe59ff018		// 0x14 (unused)
	WORD	$0xe59ff018		// 0x18 IRQ
	WORD	$0xe59ff018		// 0x1c FIQ
	WORD	$_start+0(SB)
	WORD	$undefined_entry+0(SB)
	WORD	$svc_entry+0(SB)
	WORD	$prefetch_entry+0(SB)
	WORD	$data_entry+0(SB)
	WORD	$_start+0(SB)
	WORD	$_start+0(SB)
	WORD	$_start+0(SB)

// the vectors at 0, and a stack for the modes of a fault (undefined:
// 0x1b, abort: 0x17; the interrupts masked in each: 0xc0), from SVC's
TEXT vectors_install+0(SB), $-4
	MOVW	$vectors+0(SB), R0
	MOVW	$0, R1
copy:
	MOVW.P	4(R0), R2
	MOVW.P	R2, 4(R1)
	CMP	$64, R1
	BLO	copy
	MOVW	CPSR, R2
	MOVW	$0xdb, R3
	MOVW	R3, CPSR
	MOVW	$undstack+4096(SB), R13
	MOVW	$0xd7, R3
	MOVW	R3, CPSR
	MOVW	$abtstack+4096(SB), R13
	MOVW	R2, CPSR
	RET

// A system call: in SVC mode, the link the user's next instruction,
// SPSR its status, the stack the kernel's, where the kernel left it
// when it entered user mode: below the frames of the OCaml that did,
// so the collector's view of the stacks stays whole. Every register is
// the user's: two go aside on that stack, for the static base and the
// frame's address. No frame of the linker's ($-4): nothing returns.
TEXT svc_entry+0(SB), $-4
	MOVW.W	R12, -4(R13)
	MOVW.W	R0, -4(R13)
	MOVW	$setR12(SB), R12
	MOVW	cur_tf+0(SB), R0
	MOVM.IB	[R1-R11], (R0)		// words 1 to 11
	ADD	$52, R0, R1
	MOVM.IA.S	[R13-R14], (R1)	// 13, 14: the user's sp and lr
	NOP				// (no banked register in the next instruction)
	MOVW.P	4(R13), R1
	MOVW	R1, 0(R0)		// 0: the user's r0
	MOVW.P	4(R13), R1
	MOVW	R1, 48(R0)		// 12
	MOVW	R14, 60(R0)		// 15: where to go back
	MOVW	SPSR, R1
	MOVW	R1, 64(R0)		// 16: the user's status
	BL	trap+0(SB)
	B	user_return+0(SB)

// to user mode, from the trap frame (the first time too: user_enter)
TEXT user_return+0(SB), $-4
	MOVW	cur_tf+0(SB), R0
	MOVW	64(R0), R1
	MOVW	R1, SPSR
	MOVW	60(R0), R14
	ADD	$52, R0, R1
	MOVM.IA.S	(R1), [R13-R14]
	NOP
	MOVM.IA	(R0), [R0-R12]
	MOVW.S	R14, R15

// the faults: named, the machine halted (the steps after this one kill
// the process instead)
TEXT undefined_entry+0(SB), $-4
	MOVW	$setR12(SB), R12
	MOVW	$1, R0
	B	fault+0(SB)
TEXT prefetch_entry+0(SB), $-4
	MOVW	$setR12(SB), R12
	MOVW	$2, R0
	B	fault+0(SB)
TEXT data_entry+0(SB), $-4
	MOVW	$setR12(SB), R12
	MOVW	$3, R0
	B	fault+0(SB)
// kfault(which, the link: where)
TEXT fault+0(SB), $12
	MOVW	R14, 8(R13)
	BL	kfault+0(SB)
	BL	halt+0(SB)

GLOBL	undstack+0(SB), $4096
GLOBL	abtstack+0(SB), $4096
