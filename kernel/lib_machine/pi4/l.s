// mini-xv6 on the Pi 4, for mini-asm and mini-ld (plan_kernel_mini_ml.md,
// step 5): start.s in Plan 9's assembly, the same machine: the boot (to
// EL1, the MMU on), the exception entries from EL0 (a system call, an
// abort, an IRQ: the user's registers into the running process's trap
// frame, then the kernel on the process's kernel stack), the way back,
// the switch between kernel stacks, and the system's registers and
// instructions that machine.c asks for. start.s says the translation
// (xv6 arm64-pi4's: KERNBASE + the physical addresses, by TTBR1).
//
// What differs, the assembler's and the linker's:
// - no alignment: the vectors (a multiple of 2048) are the image's
//   first bytes, their first entry (never taken) the branch to the
//   start; the three tables (pages) are below the image, at fixed
//   addresses, 0x7d000 to 0x80000;
// - no address relative to the pc: an address is the linked one, a
//   literal; the boot, which runs at the physical addresses, takes
//   KERNBASE (R27) off each;
// - the image is the text and the data, loaded at 0x80000 (no ELF);
//   the disk's image and the font are data, written by the mkfile.

#define MPIDR_EL1	SPR(0x1800a0)
#define CurrentEL	SPR(0x184240)
#define SCR_EL3		SPR(0x1e1100)
#define ELR_EL3		SPR(0x1e4020)
#define SPSR_EL3	SPR(0x1e4000)
#define HCR_EL2		SPR(0x1c1100)
#define CPTR_EL2	SPR(0x1c1140)
#define FPEXC32_EL2	SPR(0x1c5300)
#define ELR_EL2		SPR(0x1c4020)
#define SPSR_EL2	SPR(0x1c4000)
#define CPACR_EL1	SPR(0x181040)
#define SCTLR_EL1	SPR(0x181000)
#define TTBR0_EL1	SPR(0x182000)
#define TTBR1_EL1	SPR(0x182020)
#define TCR_EL1		SPR(0x182040)
#define MAIR_EL1	SPR(0x18a200)
#define VBAR_EL1	SPR(0x18c000)
#define ELR_EL1		SPR(0x184020)
#define SPSR_EL1	SPR(0x184000)
#define SP_EL0		SPR(0x184100)
#define ESR_EL1		SPR(0x185200)
#define FAR_EL1		SPR(0x186000)
#define CNTFRQ_EL0	SPR(0x1be000)
#define CNTVCT_EL0	SPR(0x1be040)
#define CNTV_TVAL_EL0	SPR(0x1be300)
#define CNTV_CTL_EL0	SPR(0x1be320)

#define VMALLE1		$0x8700
#define IALLU		$0x7500

#define KERNEL_L1	$0x7d000
#define BOOT_L1		$0x7e000
#define EMPTY		$0x7f000

#define PAD7	WORD $0; WORD $0; WORD $0; WORD $0; WORD $0; WORD $0; WORD $0
#define PAD31	PAD7; WORD $0; PAD7; WORD $0; PAD7; WORD $0; PAD7
#define KERNEL	B kernel_exception+0(SB); PAD31

// the vectors: 16 entries of 128 bytes. The kernel's own exceptions
// (the first 8) stop the machine; EL0's go to the kernel, AArch64's
// (0x400) and AArch32's (0x600: mini-9pi's processes) by the same code
TEXT vectors+0(SB), $-8
	B	_start+0(SB)		// 0x000: never taken; the image's entry
	PAD31
	KERNEL
	KERNEL
	KERNEL
	KERNEL				// 0x200
	KERNEL
	KERNEL
	KERNEL
	B	el0_sync+0(SB)		// 0x400
	PAD31
	B	el0_irq+0(SB)		// 0x480
	PAD31
	KERNEL
	KERNEL
	B	el0_sync+0(SB)		// 0x600
	PAD31
	B	el0_irq+0(SB)		// 0x680
	PAD31
	KERNEL
	KERNEL

// The boot, at the physical addresses. Each piece is a leaf (no stack
// yet), entered by a branch or by ERET.
TEXT _start+0(SB), $0
	MRS	MPIDR_EL1, R1		// the board starts its four cores here: the others wait
	AND	$3, R1
	CBNZ	R1, park
	MOV	$0xffffff8000000000, R27
	MRS	CurrentEL, R0
	AND	$0xc, R0
	CMP	$12, R0
	BEQ	el3
	B	el2+0(SB)
el3:					// EL3 (QEMU's, for an ELF) to EL2: non-secure, AArch64 below
	MOV	$0x4b1, R0
	MSR	R0, SCR_EL3
	MOV	$el2+0(SB), R1
	SUB	R27, R1
	MSR	R1, ELR_EL3
	MOV	$0x3c9, R2
	MSR	R2, SPSR_EL3
	ERET
park:
	WFE
	B	park

// EL2 (the firmware's) to EL1: AArch64, the floating point not
// trapped, EL1's own stack pointer, the interrupts masked
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
	// and an AArch32 process's (start.s): FPEXC's EN
	MOV	$0x40000000, R0
	MSR	R0, FPEXC32_EL2
	MOV	$el1+0(SB), R1
	SUB	R27, R1
	MSR	R1, ELR_EL2
	MOV	$0x3c5, R2
	MSR	R2, SPSR_EL2
	ERET

TEXT el1+0(SB), $0
	MOV	$0x300000, R0		// the floating point (the runtime computes with doubles)
	MSR	R0, CPACR_EL1
	ISB	$15
	MOV	$edata(SB), R1		// the bss cleared (the image has only the text and the data)
	SUB	R27, R1
	MOV	$end(SB), R2
	SUB	R27, R2
clear:
	CMP	R2, R1
	BHS	cleared
	MOV	ZR, (R1)
	ADD	$8, R1
	B	clear
cleared:
	MOV	KERNEL_L1, R1		// the three tables cleared
	MOV	$0x80000, R2
tables:
	MOV	ZR, (R1)
	ADD	$8, R1
	CMP	R2, R1
	BLO	tables
	MOV	KERNEL_L1, R0		// the kernel's: the RAM (2GB), 1GB blocks (AttrIndx 2,
	MOV	$0x709, R1		// inner shareable, AF); the devices (the fourth GB:
	MOV	R1, 0(R0)		// AttrIndx 0, AF, UXN, PXN)
	MOV	$0x40000709, R1
	MOV	R1, 8(R0)
	MOV	$0x00600000c0000401, R1
	MOV	R1, 24(R0)
	MOV	BOOT_L1, R0		// the boot's: the first GB as itself
	MOV	$0x709, R1
	MOV	R1, 0(R0)
	MOV	$0xff4400, R0
	MSR	R0, MAIR_EL1
	MOV	$0x10B5193519, R0
	MSR	R0, TCR_EL1
	MOV	BOOT_L1, R0
	MSR	R0, TTBR0_EL1
	MOV	KERNEL_L1, R0
	MSR	R0, TTBR1_EL1
	ISB	$15
	TLBI	VMALLE1
	DSB	$15
	ISB	$15
	MRS	SCTLR_EL1, R0		// the MMU and the caches on; no alignment checks
	MOV	$0x1005, R1
	ORR	R1, R0
	MOV	$-3, R1
	AND	R1, R0
	MSR	R0, SCTLR_EL1
	ISB	$15
	MOV	$high+0(SB), R0
	B	(R0)

// at the linked addresses: the static base (R28: 7c's code reaches its
// data from it), the stack, the vectors, TTBR0 the empty table, then
// the board, then the runtime's main, which starts OCaml
TEXT high+0(SB), $0
	MOV	$setSB(SB), R28
	MOV	$kstack+1048576(SB), R1
	MOV	R1, RSP
	MOV	$vectors+0(SB), R0
	MSR	R0, VBAR_EL1
	MOV	EMPTY, R0
	MSR	R0, TTBR0_EL1
	ISB	$15
	TLBI	VMALLE1
	DSB	$15
	ISB	$15
	B	boot+0(SB)

// main(0, nil): no arguments (the runtime's main keeps them, for Sys.argv)
TEXT boot+0(SB), $32
	BL	board_init+0(SB)
	MOV	$0, R0
	MOV	ZR, 16(RSP)
	BL	main+0(SB)
	BL	halt+0(SB)

// the end: the core waits for an interrupt that does not come
TEXT halt+0(SB), $0
	WFI
	B	-1(PC)

// From EL0. The stack is EL1's, where the kernel left it when it
// entered user mode (the process's). Every register is the user's:
// two words of the stack hold its first and its link, while the frame
// (the running process's, cur_tf: x0-x30, sp_el0, elr_el1, spsr_el1)
// is found and filled. No frame of the linker's ($-8): nothing returns
// by it.
TEXT save_user<>+0(SB), $-8
	MOV	R0, 0(RSP)
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
	MOV	0(RSP), R1
	MOV	R1, 0(R0)
	MOV	8(RSP), R1
	MOV	R1, 240(R0)
	ADD	$16, RSP
	MRS	SP_EL0, R1
	MOV	R1, 248(R0)
	MRS	ELR_EL1, R1
	MOV	R1, 256(R0)
	MRS	SPSR_EL1, R1
	MOV	R1, 264(R0)
	MOV	$setSB(SB), R28		// the kernel's static base
	RET	(R30)

// a synchronous exception: a system call (ESR's class 0x15, svc; 0x11
// an AArch32 process's), else the process's fault
TEXT el0_sync+0(SB), $-8
	SUB	$16, RSP
	MOV	R30, 8(RSP)
	BL	save_user<>+0(SB)
	MRS	ESR_EL1, R0
	LSR	$26, R0, R1
	CMP	$0x11, R1
	BEQ	call
	CMP	$0x15, R1
	BEQ	call
	BL	user_abort64+0(SB)
	B	user_return+0(SB)
call:
	BL	trap+0(SB)
	B	user_return+0(SB)

TEXT el0_irq+0(SB), $-8
	SUB	$16, RSP
	MOV	R30, 8(RSP)
	BL	save_user<>+0(SB)
	BL	pi4_irq+0(SB)
	B	user_return+0(SB)

// back to EL0, from the running process's trap frame (it may be another
// process's than the one that trapped: a switch in between)
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

// kfault64(esr, elr, far), then the end
TEXT kernel_exception+0(SB), $48
	MOV	$setSB(SB), R28
	MRS	ELR_EL1, R1
	MOV	R1, 16(RSP)
	MRS	FAR_EL1, R1
	MOV	R1, 24(RSP)
	MRS	ESR_EL1, R0
	BL	kfault64+0(SB)
	BL	halt+0(SB)

// swtch(from, to): runtime.c's context has the places of gcc's
// callee-saved registers (x19-x29 at 0, sp at 88, lr at 96). Here what
// a switch must keep is the stack pointer, the link (where swtch
// returns: where the other called it, or, the first time, runtime.c's
// trampoline) and R26, the value stack's top in ML's code, which goes
// through the C that called here untouched (x26's place: 56). Nothing
// else: 7c's C keeps no register across a call, and ML's spills its own.
TEXT swtch+0(SB), $0
	MOV	to+8(FP), R1
	MOV	RSP, R2
	MOV	R2, 88(R0)
	MOV	R30, 96(R0)
	MOV	R26, 56(R0)
	MOV	88(R1), R2
	MOV	R2, RSP
	MOV	96(R1), R30
	MOV	56(R1), R26
	RETURN

// the system's registers and instructions, for machine.c
// the user's translation table, the TLB and the instruction cache emptied
TEXT set_ttbr0+0(SB), $0
	MSR	R0, TTBR0_EL1
	ISB	$15
	TLBI	VMALLE1
	IC	IALLU
	DSB	$15
	ISB	$15
	RETURN
TEXT timer_frequency+0(SB), $0
	MRS	CNTFRQ_EL0, R0
	RETURN
TEXT timer_count+0(SB), $0
	MRS	CNTVCT_EL0, R0
	RETURN
// the virtual timer's next interrupt, in ticks; the timer on
TEXT timer_set+0(SB), $0
	MSR	R0, CNTV_TVAL_EL0
	MOV	$1, R1
	MSR	R1, CNTV_CTL_EL0
	ISB	$15
	RETURN
TEXT timer_control+0(SB), $0
	MRS	CNTV_CTL_EL0, R0
	RETURN
TEXT wait_for_interrupt+0(SB), $0
	WFI
	RETURN
TEXT fault_address+0(SB), $0
	MRS	FAR_EL1, R0
	RETURN
TEXT empty_table+0(SB), $0
	MOV	EMPTY, R0
	RETURN

GLOBL	kstack+0(SB), $1048576
