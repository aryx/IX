// Claude Code
// Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.

// square(n), hello.c's, by hand, for the ARM of 64 bits (mini-asm -m 7,
// Plan 9's 7a). cc passes the first argument in R0 and takes the answer
// from R0; an int is 32 bits, so the multiplication is the one of words
// (MULW). No frame ($0): a leaf, its return address kept in R30.
TEXT square(SB), $0
	MULW	R0, R0, R0
	RETURN
