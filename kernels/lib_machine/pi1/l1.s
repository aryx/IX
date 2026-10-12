// Claude Code
// Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
//
// mini-xv6 and mini-9pi on the Pi 1, for mini-asm and mini-ld: l.s,
// with what is the Pi 1's (l.s says what a board gives).

// the devices' first MB (0x20000000), the RAM's MBs, and where its
// second view, not cached, is in the kernel's table (entry 0xA00:
// 0xA0000000)
#define IO_MB		$0x200
#define RAM_MB		$512
#define UNC_L1		$0x2800
// (nothing before the start: the firmware starts the one core in SVC)
#define BOARD_START

#include "l.s"

// the processor's cycle counter, started and read (start.s)
TEXT cycles_start+0(SB), $0
	MOVW	$5, R0
	MCR	15, 0, R0, C(15), C(12), 0
	RET
TEXT cycles+0(SB), $0
	MRC	15, 0, R0, C(15), C(12), 1
	RET
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
TEXT cache_flush_all+0(SB), $0
	MOVW	$0, R0
	MCR	15, 0, R0, DRAIN
	MCR	15, 0, R0, PREFETCH
	MCR	15, 0, R0, DFLUSHALL
	MCR	15, 0, R0, IINVALL
	MCR	15, 0, R0, BTACINV
	MCR	15, 0, R0, DRAIN
	MCR	15, 0, R0, PREFETCH
	RET
