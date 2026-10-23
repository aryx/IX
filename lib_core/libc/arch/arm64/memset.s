// 9front's (sys/src/libc/arm64 at e4873f075; libc's README.md; LICENSE).
// memset by pairs of words, 16 bytes a turn, the byte made a word by
// shifts; port/memset.c is the C one (mkfile's LIBC_MEM7).
// One change: n read as 32 bits (MOVWU, 9front's MOV): a ulong is 32
// bits for 7c and mini-cc, whose callers write only its word of the slot.

TEXT memset(SB), $0
	MOVBU	c+8(FP), R1
	MOVWU	n+16(FP), R2

	MOV	R0, R5
	ADD	R0, R2, R3
	BIC	$15, R2, R4
	CBZ	R4, _loop1
	ADD	R0, R4, R4

	ORR	R1<<8, R1
	ORR	R1<<16, R1
	ORR	R1<<32, R1

_loop16:
	MOVP	R1, R1, (R5)16!
	CMP	R4, R5
	BNE	_loop16

_loop1:
	CMP	R3, R5
	BEQ	_done

	MOVBU	R1, (R5)1!
	B	_loop1

_done:
	RETURN
