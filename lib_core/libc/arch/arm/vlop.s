// Plan 9's, by principia and goken (libc's README.md; LICENSE).
// vlong * vlong on arm: the compiler calls _mulv, as _addv and _subv
// (ix/vlrt.c), but this one needs the machine's multiplication of 32
// bits into 64. From principia's libc/arm/vlop.s, its _mulv only.

TEXT	_mulv(SB), 1, $0
	MOVW	4(FP),R8	/* l0 */
	MOVW	8(FP),R11	/* h0 */
	MOVW	12(FP),R4	/* l1 */
	MOVW	16(FP),R5	/* h1 */
	MULLU	R8,R4,(R6, R7)	/* l0*l1 */
	MUL	R8,R5,R5	/* l0*h1 */
	MUL	R11,R4,R4	/* h0*l1 */
	ADD	R4,R6
	ADD	R5,R6
	MOVW	R6,4(R0)
	MOVW	R7,0(R0)
	RET
