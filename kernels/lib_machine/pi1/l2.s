// Claude Code
// Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
//
// mini-9pi on the Pi 2, for mini-asm and mini-ld: l.s, with what is
// the Pi 2's (a Cortex-A7 or A53; docs/plans/done/plan_pi2.md). start.s
// says each of these under its PI2, for GNU's assembler; the same
// machine here.

// the devices' first MB (0x3F000000), the RAM below them (1008 MB),
// and its second view, not cached, at 0x40000000 (entry 0x400)
#define IO_MB		$0x3f0
#define RAM_MB		$0x3f0
#define UNC_L1		$0x1000
#define BOARD_START	BL board_start+0(SB); BL board_cores+0(SB)
// the cores' controller (0x40000000: their mailboxes, their timers'
// routing) at 0xFF000000: the kernel's entry 0xFF0, a device's MB
#define BOARD_MAP	MOVW $0x40000412, R1; ADD $0x3000, R4, R2; MOVW R1, 0xfc0(R2)
// Several cores (start.s says each of these for GNU's assembler; the
// kernel's lock and who takes it: runtime.c). The trap frame is the
// one of the process this core runs, cur_tfs by the core's number
// (R11 is free here: the linker's, put aside by the entry or given
// back after); once the user is saved the core takes the kernel's
// lock, and gives it back before it returns to the user.
#define MPIDR	C(0), C(0), 5
#define CUR_TF		MRC 15, 0, R0, MPIDR; AND $3, R0; MOVW $cur_tfs+0(SB), R11; ADD R0<<2, R11; MOVW 0(R11), R0
#define ENTER		BL kernel_enter+0(SB)
#define LEAVE		BL kernel_leave+0(SB)

#include "l.s"

// Before anything, at the physical addresses (a leaf: it returns by
// the link, or by the exception's return), every core's. The tables'
// bits meant as ARMv6's (SCTLR's TRE and AFE clear). And out of the
// hypervisor's mode, where the firmware starts a Pi 2's kernel: to
// SVC, the interrupts masked, at the caller's next instruction (the
// link made the exception's return address).
// msr elr_hyp, lr; eret
#define MSR_LR_ELR_HYP	WORD $0xe12ef30e
#define ERET		WORD $0xe160006e
TEXT board_start+0(SB), $-4
	MRC	15, 0, R0, SCTLR
	BIC	$(3<<28), R0
	MCR	15, 0, R0, SCTLR
	MOVW	CPSR, R0
	AND	$0x1f, R0, R1
	CMP	$0x1a, R1
	BNE	insvc
	BIC	$0x1f, R0
	ORR	$0xd3, R0
	MOVW	R0, SPSR
	MSR_LR_ELR_HYP
	ERET
insvc:
	B	(R14)

// Then the first core goes on (the link), and another (R5 its number,
// MPIDR's low bits) never returns: the firmware keeps it in a loop of
// its own until the first writes this start to its mailbox
// (machine.c's cores_start); an emulator given the image as a Pi 1's
// is starts the four at once. It waits until the first core names it
// (core_go, in the image's data: the tables and the bss are the first
// core's to set up), says how far it came (core_stage: its caches are
// off, these go to memory), then turns its MMU on with the first
// core's table, where the first MB is still itself, and goes to the
// linked addresses.
// old: park: WFI; B park, the other cores stopped here for ever
#define WFE		WORD $0xe320f002
#define SEV		WORD $0xe320f004
TEXT board_cores+0(SB), $-4
	MRC	15, 0, R5, MPIDR
	AND	$3, R5
	CMP	$0, R5
	BNE	other
	B	(R14)
other:
	MOVW	$setR12(SB), R12
	MOVW	$core_stage+0(SB), R3
	SUB	$KERNBASE, R3
	ADD	R5<<2, R3
	MOVW	$1, R2
	MOVW	R2, (R3)
	MOVW	$core_go+0(SB), R1
	SUB	$KERNBASE, R1
named:
	MOVW	(R1), R2
	CMP	R5, R2
	BEQ	go
	WFE
	B	named
go:
	MOVW	$2, R2
	MOVW	R2, (R3)
	MOVW	KPGDIR, R4
	MOVW	$1, R0
	MCR	15, 0, R0, DACR
	MCR	15, 0, R4, TTBR0
	MCR	15, 0, R4, TTBR1
	MOVW	$0, R0
	MCR	15, 0, R0, TTBCR
	MCR	15, 0, R0, TLBIALL
	MRC	15, 0, R0, SCTLR
	ORR	$1, R0
	ORR	$(1<<13), R0
	ORR	$(1<<23), R0
	BIC	$(3<<28), R0
	MCR	15, 0, R0, SCTLR
	MOVW	$core_high+0(SB), R1
	B	(R1)

// Another core at the linked addresses: its own stacks (corestacks:
// 128 KB a core, the three modes' 16 KB each at the bottom, SVC's the
// rest), then as the first core in high (l.s), and machine.c's
// core_main, which does not return.
TEXT core_high+0(SB), $-4
	MOVW	$setR12(SB), R12
	MOVW	$core_stage+0(SB), R3
	ADD	R5<<2, R3
	MOVW	$3, R2
	MOVW	R2, (R3)
	SUB	$1, R5, R1
	MOVW	$corestacks+0(SB), R0
	ADD	R1<<17, R0
	ADD	$0x4000, R0, R2
	ADD	$0x8000, R0, R3
	ADD	$0xc000, R0, R6
	ADD	$0x20000, R0, R7
	TO_IRQ
	MOVW	R2, R13
	TO_UND
	MOVW	R3, R13
	TO_ABT
	MOVW	R6, R13
	TO_SVC
	MOVW	R7, R13
	MOVW	$2, R0
	MCR	15, 0, R0, TTBCR
	MOVW	EMPTY, R0
	MCR	15, 0, R0, TTBR0
	MOVW	$0, R0
	MCR	15, 0, R0, TLBIALL
	MRC	15, 0, R0, CPACR
	ORR	$0xf00000, R0
	MCR	15, 0, R0, CPACR
	MOVW	$0x40000000, R0
	VMSR_R0_FPEXC
	B	core_boot+0(SB)
TEXT core_boot+0(SB), $8
	MOVW	R5, R0
	BL	core_main+0(SB)
	BL	halt+0(SB)
// the cores waiting in the start are told to look at core_go again
TEXT core_wake+0(SB), $0
	SEV
	RET

// The kernel's lock: a word, 1 when a core has it, taken by ARMv6K's
// pair, a load that marks the word and a store that fails if another
// core wrote it since (their words given: the assembler has not the
// pair). One try, 1 when taken; taken by another, a yield first (an
// emulator that runs the cores in turns gives the turn on). The first
// core has it from the start. start.s says more.
// ldrex r0, [r1]; strex r0, r2, [r1]; clrex; yield
#define LDREX_R1_R0	WORD $0xe1910f9f
#define STREX_R2_R1_R0	WORD $0xe1810f92
#define CLREX		WORD $0xf57ff01f
#define YIELD		WORD $0xe320f001
#define BARRIER	C(7), C(10), 5
TEXT klock_try+0(SB), $0
	MOVW	$klock+0(SB), R1
	MOVW	$1, R2
again:
	LDREX_R1_R0
	CMP	$0, R0
	BEQ	free
	CLREX
	YIELD
	MOVW	$0, R0
	RET
free:
	STREX_R2_R1_R0
	CMP	$0, R0
	BNE	again
	MCR	15, 0, R0, BARRIER
	MOVW	$1, R0
	RET
TEXT klock_give+0(SB), $0
	MOVW	$klock+0(SB), R1
	MOVW	$0, R0
	MCR	15, 0, R0, BARRIER
	MOVW	R0, (R1)
	MCR	15, 0, R0, DRAIN
	RET
DATA	klock+0(SB)/4, $1
GLOBL	klock+0(SB), $4
// (in the data, not the bss the first core clears: the others write
// theirs meanwhile)
DATA	core_stage+0(SB)/4, $0
GLOBL	core_stage+0(SB), $64
GLOBL	corestacks+0(SB), $393216

// This core's number, and its own timer's registers (ARMv7's generic
// timer, the virtual one: machine.c's core_timer), for the C
#define CNTFRQ		C(14), C(0), 0
#define CNTV_TVAL	C(14), C(3), 0
#define CNTV_CTL	C(14), C(3), 1
TEXT core+0(SB), $0
	MRC	15, 0, R0, MPIDR
	AND	$3, R0
	RET
TEXT timer_rate+0(SB), $0
	MRC	15, 0, R0, CNTFRQ
	RET
TEXT timer_set+0(SB), $0
	MCR	15, 0, R0, CNTV_TVAL
	RET
TEXT timer_control+0(SB), $0
	MCR	15, 0, R0, CNTV_CTL
	RET
TEXT timer_state+0(SB), $0
	MRC	15, 0, R0, CNTV_CTL
	RET

// ARMv7's performance monitor: the cycle counter enabled (PMCNTENSET's
// bit 31), counting from 0 (PMCR's E and C); read (PMCCNTR)
TEXT cycles_start+0(SB), $0
	MOVW	$0x80000000, R0
	MCR	15, 0, R0, C(9), C(12), 1
	MOVW	$5, R0
	MCR	15, 0, R0, C(9), C(12), 0
	RET
TEXT cycles+0(SB), $0
	MRC	15, 0, R0, C(9), C(13), 0
	RET

// Every data or unified cache, a line at a time by its level, set and
// way (start.s's dcache_all: the ARM manual's walk): invalidated (R9 =
// 0), or written to memory first (1), or the first level's only,
// invalidated (2: a core that starts). R0 CLIDR; R3 twice the level where
// the caches end; R6 twice the level; R2 log2 of a line's bytes; R4
// the ways less 1, R5 where a way's number goes; R7 the sets less 1;
// R8 the way; R1 the word given. (No register is kept across a call
// by this C; R10 to R12 are ML's and the linker's, not touched.)
#define CLIDR	C(0), C(0), 1
#define CSSELR	C(0), C(0), 0
#define CCSIDR	C(0), C(0), 0
#define DCISW	C(7), C(6), 2
#define DCCISW	C(7), C(14), 2
// clz r5, r4
#define CLZ_R4_R5	WORD $0xe16f5f14
TEXT dcache_all+0(SB), $-4
	MRC	15, 1, R0, CLIDR
	MOVW	R0>>23, R3
	AND	$0xe, R3
	CMP	$0, R3
	BEQ	dcdone
	CMP	$2, R9
	BNE	dcall
	MOVW	$2, R3
dcall:
	MOVW	$0, R6
dclevel:
	ADD	R6>>1, R6, R2
	MOVW	R0>>R2, R1
	AND	$7, R1
	CMP	$2, R1
	BLT	dcnext
	MCR	15, 2, R6, CSSELR
	MCR	15, 0, R1, PREFETCH
	MRC	15, 1, R1, CCSIDR
	AND	$7, R1, R2
	ADD	$4, R2
	MOVW	R1>>3, R4
	MOVW	$0x3ff, R8
	AND	R8, R4
	CLZ_R4_R5
	MOVW	R1>>13, R7
	MOVW	$0x7fff, R8
	AND	R8, R7
dcset:
	MOVW	R4, R8
dcway:
	ORR	R8<<R5, R6, R1
	ORR	R7<<R2, R1
	CMP	$1, R9
	BEQ	dcwrite
	MCR	15, 0, R1, DCISW
	B	dcdid
dcwrite:
	MCR	15, 0, R1, DCCISW
dcdid:
	SUB.S	$1, R8
	BGE	dcway
	SUB.S	$1, R7
	BGE	dcset
dcnext:
	ADD	$2, R6
	CMP	R6, R3
	BGT	dclevel
dcdone:
	MOVW	$0, R0
	MCR	15, 2, R0, CSSELR
	MCR	15, 0, R0, DRAIN
	MCR	15, 0, R0, PREFETCH
	B	(R14)

// the caches on: a Cortex-A7's SMP bit first (ACTLR's bit 6), every
// data cache and the instructions' emptied, the branch predictor's;
// then the data cache (C), the instructions' (I), the prediction (Z)
#define ACTLR	C(1), C(0), 1
TEXT caches_enable+0(SB), $4
	MRC	15, 0, R0, ACTLR
	ORR	$(1<<6), R0
	MCR	15, 0, R0, ACTLR
	MOVW	$0, R9
	BL	dcache_all+0(SB)
	MOVW	$0, R0
	MCR	15, 0, R0, IINVALL
	MCR	15, 0, R0, BTACINV
	MCR	15, 0, R0, PREFETCH
	MRC	15, 0, R0, SCTLR
	ORR	$(1<<2), R0
	ORR	$(1<<11), R0
	ORR	$(1<<12), R0
	MCR	15, 0, R0, SCTLR
	MCR	15, 0, R0, PREFETCH
	RET
// another core's: its own first level only (the second is every
// core's, and holds what the running ones wrote)
TEXT caches_enable_core+0(SB), $4
	MRC	15, 0, R0, ACTLR
	ORR	$(1<<6), R0
	MCR	15, 0, R0, ACTLR
	MOVW	$2, R9
	BL	dcache_all+0(SB)
	MOVW	$0, R0
	MCR	15, 0, R0, IINVALL
	MCR	15, 0, R0, BTACINV
	MCR	15, 0, R0, PREFETCH
	MRC	15, 0, R0, SCTLR
	ORR	$(1<<2), R0
	ORR	$(1<<11), R0
	ORR	$(1<<12), R0
	MCR	15, 0, R0, SCTLR
	MCR	15, 0, R0, PREFETCH
	RET
// everything written to memory and both caches emptied
TEXT cache_flush_all+0(SB), $4
	MOVW	$1, R9
	BL	dcache_all+0(SB)
	MOVW	$0, R0
	MCR	15, 0, R0, IINVALL
	MCR	15, 0, R0, BTACINV
	MCR	15, 0, R0, PREFETCH
	RET
