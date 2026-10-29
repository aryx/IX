// Claude Code
// Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.

// gc.c's scan_copies with copy in it, on arm (gc.c's SCAN_ASM says
// why): the fields of the blocks from scan to next, each young or in
// the half collected copied after next (or its copy's address when
// copied already: a header 0), next chasing scan (Cheney's). The state
// is gc.c's struct Scan, its address in R0; next written back.
//
//   R0 scan          R4 the block's end    R7, R8, R14 temporaries
//   R1 next          R5 its field          8(R13) the Scan
//   R2 lo, R3 hi     R6 the field's value
//
// A field that is an int (its bit 0), or a block outside lo..hi and
// lo2..hi2 (static data, the old generation in a minor collection), is
// left; during a major collection (marking) a large block's is marked
// by gc.c's large_mark, the only call: every register is the callee's
// to change (Plan 9's convention), so R0-R5 saved around it; and 4(R13)
// is its argument's, where it stores R0 (5c's MOVW R0, a+0(FP)), so
// nothing of ours (it was the Scan's: mini-ml's Marshal bench lost a
// block's last fields)

TEXT	ml_scan(SB), $36
	MOVW	R0, 8(R13)
	MOVW	4(R0), R1
	MOVW	8(R0), R2
	MOVW	12(R0), R3
	MOVW	0(R0), R0
block:
	CMP	R1, R0
	BHS	done
	MOVW.P	4(R0), R7		/* its header */
	MOVW	R7>>10, R4
	ADD	R4<<2, R0, R4		/* its end */
	AND	$255, R7, R8
	CMP	$251, R8
	BHS	skip			/* no pointers: a tag from 251 */
	MOVW	R0, R5
field:
	CMP	R4, R5
	BHS	skip
	MOVW	(R5), R6
	AND.S	$1, R6, R8
	BNE	nextf			/* an int */
	CMP	R2, R6
	BLO	other
	CMP	R3, R6
	BHS	other
copy:
	MOVW	-4(R6), R7		/* the block's header */
	CMP	$0, R7
	BEQ	moved
	MOVW.P	R7, 4(R1)		/* the copy's, at next */
	MOVW	R1, (R5)		/* the field: the copy */
	MOVW	R7>>10, R7
	ADD	R7<<2, R1, R7		/* the copy's end */
	MOVW	R6, R8
words:
	CMP	R7, R1
	BHS	copied
	MOVW.P	4(R8), R14
	MOVW.P	R14, 4(R1)
	B	words
copied:
	MOVW	$0, R8
	MOVW	R8, -4(R6)		/* the block moved: header 0, */
	MOVW	(R5), R8
	MOVW	R8, (R6)		/* its first word where to */
	B	nextf
moved:
	MOVW	(R6), R8
	MOVW	R8, (R5)
nextf:
	ADD	$4, R5
	B	field
skip:
	MOVW	R4, R0
	B	block
done:
	MOVW	8(R13), R7
	MOVW	R1, 4(R7)
	RET

// a pointer outside lo..hi: in lo2..hi2 (a major's young), else a
// large block's in a major
other:
	MOVW	8(R13), R7
	MOVW	16(R7), R8
	CMP	R8, R6
	BLO	large
	MOVW	20(R7), R8
	CMP	R8, R6
	BLO	copy
large:
	MOVW	32(R7), R8
	CMP	$0, R8
	BEQ	nextf
	MOVW	24(R7), R8
	CMP	R8, R6
	BLO	nextf
	MOVW	28(R7), R8
	CMP	R8, R6
	BHS	nextf
	MOVW	R0, 12(R13)
	MOVW	R1, 16(R13)
	MOVW	R2, 20(R13)
	MOVW	R3, 24(R13)
	MOVW	R4, 28(R13)
	MOVW	R5, 32(R13)
	MOVW	R6, R0
	BL	large_mark(SB)
	MOVW	12(R13), R0
	MOVW	16(R13), R1
	MOVW	20(R13), R2
	MOVW	24(R13), R3
	MOVW	28(R13), R4
	MOVW	32(R13), R5
	B	nextf
