// Claude Code
// Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.

// square(n), hello.c's, by hand, for the ARM of 32 bits (mini-asm -m 5,
// Plan 9's 5a). cc passes the first argument in R0 and takes the answer
// from R0. No frame ($0): a leaf, its return address kept in R14.
TEXT square(SB), $0
	MOVW	R0, R1
	MUL	R1, R0
	RET
