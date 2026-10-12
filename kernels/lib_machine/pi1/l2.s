// Claude Code
// Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
//
// mini-9pi on the Pi 2, for mini-asm and mini-ld: l.s, with what is
// the Pi 2's (a Cortex-A7 or A53; docs/plans/plan_pi2.md). start.s
// says each of these under its PI2, for GNU's assembler; the same
// machine here.

// the devices' first MB (0x3F000000), the RAM below them (1008 MB),
// and its second view, not cached, at 0x40000000 (entry 0x400)
#define IO_MB		$0x3f0
#define RAM_MB		$0x3f0
#define UNC_L1		$0x1000
#define BOARD_START	BL board_start+0(SB)

#include "l.s"

// Before anything, at the physical addresses (a leaf: it returns by
// the link, or by the exception's return). One core: the others
// (MPIDR's low bits) wait here for ever. The tables' bits meant as
// ARMv6's (SCTLR's TRE and AFE clear). And out of the hypervisor's
// mode, where the firmware starts a Pi 2's kernel: to SVC, the
// interrupts masked, at the caller's next instruction (the link made
// the exception's return address).
#define MPIDR	C(0), C(0), 5
// msr elr_hyp, lr; eret
#define MSR_LR_ELR_HYP	WORD $0xe12ef30e
#define ERET		WORD $0xe160006e
TEXT board_start+0(SB), $-4
	MRC	15, 0, R0, MPIDR
	AND	$3, R0
	CMP	$0, R0
	BEQ	first
park:
	WFI
	B	park
first:
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
// 0), or written to memory first. R0 CLIDR; R3 twice the level where
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
	CMP	$0, R9
	BNE	dcwrite
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
// everything written to memory and both caches emptied
TEXT cache_flush_all+0(SB), $4
	MOVW	$1, R9
	BL	dcache_all+0(SB)
	MOVW	$0, R0
	MCR	15, 0, R0, IINVALL
	MCR	15, 0, R0, BTACINV
	MCR	15, 0, R0, PREFETCH
	RET
