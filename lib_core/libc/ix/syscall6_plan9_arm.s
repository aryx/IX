// Claude Code
// Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
//
// A system call of Plan 9's by its number, for mini-ml's runtime (its
// unix_syscall: lib_core/system's Unix on Plan 9), as
// syscall/os/linux/svc_arm.s's is Linux's: _syscall6(n, a1 ... a6).
// Plan 9's kernel takes the number in R0 and reads the arguments on the
// stack, from 4(SP); here they are one word too high (5c's call: n in
// R0, its slot at 4(R13), a1 at 8(R13)), so they are copied below.
// R13 by its name: the frame is ours, not the linker's.
TEXT _syscall6+0(SB), $0
	SUB	$24, R13
	MOVW	32(R13), R1
	MOVW	R1, 4(R13)
	MOVW	36(R13), R1
	MOVW	R1, 8(R13)
	MOVW	40(R13), R1
	MOVW	R1, 12(R13)
	MOVW	44(R13), R1
	MOVW	R1, 16(R13)
	MOVW	48(R13), R1
	MOVW	R1, 20(R13)
	MOVW	52(R13), R1
	MOVW	R1, 24(R13)
	SWI	$0
	ADD	$24, R13
	RET
