// mini-xv6 on the Pi 1, for mini-asm and mini-ld (plan_kernel_mini_ml.md,
// step 9): start.s in Plan 9's assembly, the same machine: the boot
// (the MMU on), the trap entries from user mode (a system call, an
// IRQ, an abort: the user's registers into the running process's trap
// frame, then the kernel on the process's kernel stack), the way back,
// the switch between kernel stacks, and the system's registers and
// instructions that machine.c asks for. start.s says the translation
// (xv6 arm-pi1's: the user below 1 GB, the kernel at KERNBASE, the
// devices at 0xFE000000, the vectors at 0xFFFF0000).
//
// What differs, the assembler's and the linker's (as pi4/l.s):
// - no alignment: the tables are below the image, at fixed physical
//   addresses: the kernel's (16 KB) at 0x4000, the table of no process
//   at 0x3000, the vectors' page at 0x2000, its second-level table at
//   0x1000;
// - the boot runs at the physical addresses, the image linked at
//   KERNBASE + 0x8000: until the MMU is on it names no data (the static
//   base is not set), only constants and the vectors' address, a
//   literal, less KERNBASE;
// - the image is the text and the data, loaded at 0x8000; the bss is
//   cleared once the MMU is on; the disk's image and the font are
//   data, written by the mkfile.
//
// The static base (R12) is the kernel's only in the kernel: an entry
// from user mode sets it again before it names anything.

#define KERNBASE	0x80000000
#define KPGDIR		$0x4000
#define EMPTY		$0x3000
#define VECPAGE		$0x2000
#define VECL2		$0x1000
// a section's entry: AP 01 (the kernel's, read and write), domain 0;
// the same, never executed: the devices'
// (a macro's line has no comment: it would be part of what replaces the name)
#define SECTION		$0x40e
#define DEVICE		$0x412
#define UNCACHED	$0x1412

#define NOP		MOVW R0, R0
#define WFI		WORD $0xe320f003
// vmsr fpexc, r0
#define VMSR_R0_FPEXC	WORD $0xeee80a10
// to a mode (the interrupts masked in it), from another
#define TO_IRQ	MOVW $0xd2, R1; MOVW R1, CPSR
#define TO_SVC	MOVW $0xd3, R1; MOVW R1, CPSR
#define TO_ABT	MOVW $0xd7, R1; MOVW R1, CPSR
#define TO_UND	MOVW $0xdb, R1; MOVW R1, CPSR

// the system's coprocessor (15): its registers, after the ARM's
#define SCTLR	C(1), C(0), 0
#define CPACR	C(1), C(0), 2
#define TTBR0	C(2), C(0), 0
#define TTBR1	C(2), C(0), 1
#define TTBCR	C(2), C(0), 2
#define DACR	C(3), C(0), 0
#define DFSR	C(5), C(0), 0
#define IFSR	C(5), C(0), 1
#define FAR	C(6), C(0), 0
#define IFAR	C(6), C(0), 2
#define TLBIALL	C(8), C(7), 0
// the caches' operations (start.s says each)
#define CACHEINV	C(7), C(7), 0
#define BTACINV	C(7), C(5), 6
#define DCLEAN	C(7), C(10), 1
#define IINV	C(7), C(5), 1
#define DRAIN	C(7), C(10), 4

// The boot, at the physical addresses: a leaf, no stack, no data.
TEXT _start+0(SB), $-4
	MOVW	VECL2, R0		// the four tables, empty
	MOVW	$0x8000, R1
	MOVW	$0, R2
zero:
	MOVW.P	R2, 4(R0)
	CMP	R1, R0
	BLO	zero
	MOVW	KPGDIR, R4
	MOVW	$0, R0			// the RAM at KERNBASE: entries 0x800.., MB i to i, 512 of them
	MOVW	SECTION, R3
	ADD	$0x2000, R4, R2
ram:
	ORR	R0<<20, R3, R1
	MOVW.P	R1, 4(R2)
	ADD	$1, R0
	CMP	$512, R0
	BLO	ram
	MOVW	$0, R0			// the RAM again at 0xA0000000, not cached: entries 0xA00..
	MOVW	UNCACHED, R3
	ADD	$0x2800, R4, R2
ram2:
	ORR	R0<<20, R3, R1
	MOVW.P	R1, 4(R2)
	ADD	$1, R0
	CMP	$512, R0
	BLO	ram2
	MOVW	$0, R0			// the devices at 0xFE000000: 16 MB from 0x20000000
	MOVW	DEVICE, R3
	ADD	$0x3f80, R4, R2		// entry 0xFE0
dev:
	ADD	$0x200, R0, R1
	ORR	R1<<20, R3, R1
	MOVW.P	R1, 4(R2)
	ADD	$1, R0
	CMP	$16, R0
	BLO	dev
	MOVW	SECTION, R1		// the first MB as itself too, while the MMU goes on here
	MOVW	R1, (R4)
	MOVW	$vectors+0(SB), R0	// the vectors, copied to their page
	SUB	$KERNBASE, R0
	MOVW	VECPAGE, R1
	ADD	$64, R1, R3
vec:
	MOVW.P	4(R0), R2
	MOVW.P	R2, 4(R1)
	CMP	R3, R1
	BLO	vec
	MOVW	VECL2, R6		// that page at 0xFFFF0000: a coarse table's entry 0xF0 (a small page, AP 01)
	MOVW	$0x201e, R1
	MOVW	R1, 0x3c0(R6)
	MOVW	$0x1001, R1		// the coarse table, the kernel's entry 0xFFF
	ADD	$0x3000, R4, R2
	MOVW	R1, 0xffc(R2)
	MOVW	$1, R0			// domain 0 a client (permissions checked); both tables the kernel's
	MCR	15, 0, R0, DACR
	MCR	15, 0, R4, TTBR0
	MCR	15, 0, R4, TTBR1
	MOVW	$0, R0
	MCR	15, 0, R0, TTBCR		// N = 0 for now
	MCR	15, 0, R0, TLBIALL
	MRC	15, 0, R0, SCTLR		// on: the MMU (M), ARMv6's format (XP), the high vectors (V)
	ORR	$1, R0
	ORR	$(1<<13), R0
	ORR	$(1<<23), R0
	MCR	15, 0, R0, SCTLR
	MOVW	$high+0(SB), R1		// to the linked addresses
	B	(R1)

// The MMU is on: a stack for each mode, then SVC's, the kernel's; the
// bss cleared; the first MB no longer mapped as itself (TTBCR first, N
// = 2: only below 1 GB through TTBR0; then TTBR0 the table of no
// process: start.s says why in that order); the VFP on.
TEXT high+0(SB), $-4
	MOVW	$setR12(SB), R12
	MOVW	$edata(SB), R1
	MOVW	$end(SB), R2
	MOVW	$0, R3
clear:
	CMP	R2, R1
	BHS	cleared
	MOVW.P	R3, 4(R1)
	B	clear
cleared:
	TO_IRQ
	MOVW	$irqstack+4096(SB), R13
	TO_UND
	MOVW	$undstack+4096(SB), R13
	TO_ABT
	MOVW	$abtstack+4096(SB), R13
	TO_SVC
	MOVW	$kstack+1048576(SB), R13
	MOVW	$2, R0
	MCR	15, 0, R0, TTBCR
	MOVW	EMPTY, R0
	MCR	15, 0, R0, TTBR0
	MOVW	$0, R0
	MCR	15, 0, R0, TLBIALL
	MRC	15, 0, R0, CPACR		// cp10 and cp11 (the VFP): full access
	ORR	$0xf00000, R0
	MCR	15, 0, R0, CPACR
	MOVW	$0x40000000, R0		// FPEXC.EN
	VMSR_R0_FPEXC
	B	boot+0(SB)

// main(0, nil): no arguments (the runtime's main keeps them, for Sys.argv)
TEXT boot+0(SB), $16
	MOVW	$0, R0
	MOVW	R0, 8(R13)
	BL	main+0(SB)
	BL	halt+0(SB)

TEXT halt+0(SB), $-4
	WFI
	B	-1(PC)

// the vectors, at 0xFFFF0000: eight "ldr pc, [pc, #24]", then their addresses
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
	WORD	$irq_entry+0(SB)
	WORD	$_start+0(SB)

// From user mode: the user's registers into the trap frame (the
// running process's, cur_tf). Every register is the user's: three go
// aside on the mode's stack, for the static base, the linker's own
// register (R11: it holds a constant or an offset too large for an
// instruction, as cur_tf's may be) and the frame's address. A system call returns to the next instruction (the link);
// an abort's link is 8 after the faulting instruction (data) or 4
// (prefetch): kept as it is, machine.c's user_abort takes it back.
// Then the user's floats, D0-D7 and the FPSCR (start.s says why): the
// assembler has not these instructions, their words are given.
// vmrs r1, fpscr; vmsr fpscr, r1; vstmia r1, {d0-d7}; vldmia r1, {d0-d7}
#define VMRS_FPSCR_R1	WORD $0xeef11a10
#define VMSR_R1_FPSCR	WORD $0xeee11a10
#define VSTMIA_R1_D0_D7	WORD $0xec810b10
#define VLDMIA_R1_D0_D7	WORD $0xec910b10
#define SAVE_USER	MOVW.W R12, -4(R13); MOVW.W R11, -4(R13); MOVW.W R0, -4(R13); MOVW $setR12(SB), R12; MOVW cur_tf+0(SB), R0; MOVM.IB [R1-R10], (R0); ADD $52, R0, R1; MOVM.IA.S [R13-R14], (R1); NOP; MOVW.P 4(R13), R1; MOVW R1, 0(R0); MOVW.P 4(R13), R1; MOVW R1, 44(R0); MOVW.P 4(R13), R1; MOVW R1, 48(R0); MOVW R14, 60(R0); MOVW SPSR, R1; MOVW R1, 64(R0); VMRS_FPSCR_R1; MOVW R1, 68(R0); ADD $72, R0, R1; VSTMIA_R1_D0_D7
// the mode the exception came from, compared with the user's (R0 put back; the flags stay)
#define FROM_USER	MOVW.W R0, -4(R13); MOVW SPSR, R0; AND $0x1f, R0; CMP $0x10, R0; MOVW.P 4(R13), R0

// in SVC mode: the stack is the process's kernel stack, where the
// kernel left it when it entered user mode
TEXT svc_entry+0(SB), $-4
	SAVE_USER
	BL	trap+0(SB)
	B	user_return+0(SB)

// to user mode, from the trap frame
TEXT user_return+0(SB), $-4
	MOVW	cur_tf+0(SB), R0
	MOVW	68(R0), R1
	VMSR_R1_FPSCR
	ADD	$72, R0, R1
	VLDMIA_R1_D0_D7
	MOVW	64(R0), R1
	MOVW	R1, SPSR
	MOVW	60(R0), R14
	ADD	$52, R0, R1
	MOVM.IA.S	(R1), [R13-R14]
	NOP
	MOVM.IA	(R0), [R0-R12]
	MOVW.S	R14, R15

// an IRQ: from user mode (the only mode with the interrupts on); the
// link 4 after the instruction to resume
TEXT irq_entry+0(SB), $-4
	SUB	$4, R14
	SAVE_USER
	TO_SVC
	BL	irq+0(SB)
	B	user_return+0(SB)

// an abort or an undefined instruction: from user mode, the process's
// (the user saved, then to SVC mode and the process's kernel stack:
// user_abort(which)); from the kernel, a kernel's fault: the machine stops
TEXT data_entry+0(SB), $-4
	FROM_USER
	BNE	kernel_data
	SAVE_USER
	TO_SVC
	MOVW	$3, R0
	BL	user_abort+0(SB)
	B	user_return+0(SB)
kernel_data:
	MOVW	$3, R0
	B	fault+0(SB)
TEXT prefetch_entry+0(SB), $-4
	FROM_USER
	BNE	kernel_prefetch
	SAVE_USER
	TO_SVC
	MOVW	$2, R0
	BL	user_abort+0(SB)
	B	user_return+0(SB)
kernel_prefetch:
	MOVW	$2, R0
	B	fault+0(SB)
TEXT undefined_entry+0(SB), $-4
	FROM_USER
	BNE	kernel_undefined
	SAVE_USER
	TO_SVC
	MOVW	$1, R0
	BL	user_abort+0(SB)
	B	user_return+0(SB)
kernel_undefined:
	MOVW	$1, R0
	B	fault+0(SB)
// kfault(which, the link: where), then the end
TEXT fault+0(SB), $12
	MOVW	R14, 8(R13)
	BL	kfault+0(SB)
	BL	halt+0(SB)

// swtch(from, to): runtime.c's context has the places of gcc's
// callee-saved registers (r4-r11 at 0, sp at 32, lr at 36). Here what
// a switch must keep is the stack pointer, the link (where swtch
// returns: where the other called it, or, the first time, runtime.c's
// trampoline) and R10, the value stack's top in ML's code, which goes
// through the C that called here untouched (r10's place: 24). Nothing
// else: 5c's C keeps no register across a call, and ML's spills its own.
TEXT swtch+0(SB), $0
	MOVW	to+4(FP), R1
	MOVW	R13, 32(R0)
	MOVW	R14, 36(R0)
	MOVW	R10, 24(R0)
	MOVW	32(R1), R13
	MOVW	36(R1), R14
	MOVW	24(R1), R10
	RET

// the system's registers and instructions, for machine.c
// the user's translation table, the TLB emptied
TEXT set_ttbr0+0(SB), $0
	MCR	15, 0, R0, TTBR0
	MOVW	$0, R0
	MCR	15, 0, R0, TLBIALL
	RET
TEXT wait_for_interrupt+0(SB), $0
	WFI
	RET
// the caches on, a range's lines written to memory, the same and out of
// the instructions' cache, the write buffer emptied (start.s)
TEXT caches_enable+0(SB), $0
	MOVW	$0, R0
	MCR	15, 0, R0, CACHEINV
	MCR	15, 0, R0, BTACINV
	MRC	15, 0, R0, SCTLR
	ORR	$(1<<2), R0
	ORR	$(1<<11), R0
	ORR	$(1<<12), R0
	MCR	15, 0, R0, SCTLR
	RET
TEXT cache_clean_range+0(SB), $0
	MOVW	to+4(FP), R1
	BIC	$31, R0
clean:
	MCR	15, 0, R0, DCLEAN
	ADD	$32, R0
	CMP	R1, R0
	BLO	clean
	RET
TEXT cache_sync_range+0(SB), $0
	MOVW	to+4(FP), R1
	BIC	$31, R0
sync:
	MCR	15, 0, R0, DCLEAN
	MCR	15, 0, R0, IINV
	ADD	$32, R0
	CMP	R1, R0
	BLO	sync
	RET
TEXT cache_drain+0(SB), $0
	MOVW	$0, R0
	MCR	15, 0, R0, DRAIN
	RET
// the fault's address and status: a data abort's (0), or an instruction's
TEXT fault_address+0(SB), $0
	CMP	$0, R0
	BNE	ifar
	MRC	15, 0, R0, FAR
	RET
ifar:
	MRC	15, 0, R0, IFAR
	RET
TEXT fault_status+0(SB), $0
	CMP	$0, R0
	BNE	ifsr
	MRC	15, 0, R0, DFSR
	RET
ifsr:
	MRC	15, 0, R0, IFSR
	RET
TEXT empty_table+0(SB), $0
	MOVW	EMPTY, R0
	RET

GLOBL	kstack+0(SB), $1048576
GLOBL	irqstack+0(SB), $4096
GLOBL	undstack+0(SB), $4096
GLOBL	abtstack+0(SB), $4096
