// 9front's (sys/src/libc/arm64 at e4873f075; libc's README.md; LICENSE).
// memmove by pairs of words (LDP, STP), 16 bytes a turn, then bytes;
// arm64 loads and stores a word at any address, so no alignment work.
// port/memmove.c is the C one, a byte at a time (mkfile's LIBC_MEM7).
// One change: n read as 32 bits (MOVWU, 9front's MOV): a ulong is 32
// bits for 7c and mini-cc, whose callers write only its word of the slot.

TEXT memcpy(SB), 1, $-4
TEXT memmove(SB), $0
	MOV	from+8(FP), R1
	MOVWU	n+16(FP), R2

	CMP	R0, R1
	BEQ	_done
	BLT	_backward

_forward:
	MOV	R0, R7
	ADD	R0, R2, R3
	BIC	$15, R2, R4
	CBZ	R4, _floop1
	ADD	R0, R4, R4

_floop16:
	MOVP	(R1)16!, R5, R6
	MOVP	R5, R6, (R7)16!
	CMP	R4, R7
	BNE	_floop16

_floop1:
	CMP	R3, R7
	BEQ	_done
	MOVBU	(R1)1!, R5
	MOVBU	R5, (R7)1!
	B	_floop1

_done:
	RETURN

_backward:
	ADD	R2, R1, R1
	ADD	R2, R0, R3
	BIC	$15, R2, R4
	CBZ	R4, _bloop1
	SUB	R4, R3, R4

_bloop16:
	MOVP	-16(R1)!, R5, R6
	MOVP	R5, R6, -16(R3)!
	CMP	R4, R3
	BNE	_bloop16

_bloop1:
	CMP	R0, R3
	BEQ	_done
	MOVBU	-1(R1)!, R5
	MOVBU	R5, -1(R3)!
	B	_bloop1
