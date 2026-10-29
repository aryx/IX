// Claude Code
// Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.

// gc.c's scan_copies with copy in it, on arm64: scan_arm.s's, a word
// 8 bytes (gc.c's struct Scan's offsets twice arm's); its address in
// R0, next written back. The frame's lowest word above the link is
// large_mark's argument's, where it stores R0 (7c's): nothing of ours
// there.
//
//   R0 scan          R4 the block's end    R7, R8, R9 temporaries
//   R1 next          R5 its field          s-8(SP) the Scan
//   R2 lo, R3 hi     R6 the field's value

TEXT	ml_scan(SB), $72
	MOV	R0, s-8(SP)
	MOV	8(R0), R1
	MOV	16(R0), R2
	MOV	24(R0), R3
	MOV	0(R0), R0
block:
	CMP	R1, R0
	BHS	done
	MOV	(R0)8!, R7		/* its header */
	LSR	$10, R7, R4
	ADD	R4<<3, R0, R4		/* its end */
	AND	$255, R7, R8
	CMP	$251, R8
	BHS	skip			/* no pointers: a tag from 251 */
	MOV	R0, R5
field:
	CMP	R4, R5
	BHS	skip
	MOV	(R5), R6
	AND	$1, R6, R8
	CBNZ	R8, nextf		/* an int */
	CMP	R2, R6
	BLO	other
	CMP	R3, R6
	BHS	other
copy:
	MOV	-8(R6), R7		/* the block's header */
	CBZ	R7, moved
	MOV	R7, (R1)8!		/* the copy's, at next */
	MOV	R1, (R5)		/* the field: the copy */
	LSR	$10, R7, R7
	ADD	R7<<3, R1, R7		/* the copy's end */
	MOV	R6, R8
words:
	CMP	R7, R1
	BHS	copied
	MOV	(R8)8!, R9
	MOV	R9, (R1)8!
	B	words
copied:
	MOV	ZR, -8(R6)		/* the block moved: header 0, */
	MOV	(R5), R8
	MOV	R8, (R6)		/* its first word where to */
	B	nextf
moved:
	MOV	(R6), R8
	MOV	R8, (R5)
nextf:
	ADD	$8, R5
	B	field
skip:
	MOV	R4, R0
	B	block
done:
	MOV	s-8(SP), R7
	MOV	R1, 8(R7)
	RETURN

// a pointer outside lo..hi: in lo2..hi2 (a major's young), else a
// large block's in a major
other:
	MOV	s-8(SP), R7
	MOV	32(R7), R8
	CMP	R8, R6
	BLO	large
	MOV	40(R7), R8
	CMP	R8, R6
	BLO	copy
large:
	MOV	64(R7), R8
	CBZ	R8, nextf
	MOV	48(R7), R8
	CMP	R8, R6
	BLO	nextf
	MOV	56(R7), R8
	CMP	R8, R6
	BHS	nextf
	MOV	R0, r0-16(SP)
	MOV	R1, r1-24(SP)
	MOV	R2, r2-32(SP)
	MOV	R3, r3-40(SP)
	MOV	R4, r4-48(SP)
	MOV	R5, r5-56(SP)
	MOV	R6, R0
	BL	large_mark(SB)
	MOV	r0-16(SP), R0
	MOV	r1-24(SP), R1
	MOV	r2-32(SP), R2
	MOV	r3-40(SP), R3
	MOV	r4-48(SP), R4
	MOV	r5-56(SP), R5
	B	nextf
