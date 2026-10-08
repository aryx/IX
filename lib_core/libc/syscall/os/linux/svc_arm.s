// goken's, around Plan 9's libc (libc's README.md; LICENSE).
// The way into Linux's kernel on arm: the number in R7, six arguments
// in R0 to R5. Only the first argument of a C call comes in a
// register (R0, the number); the others are on the stack, from 4(FP).
// The kernel's result is left in R0, C's too.
TEXT _syscall6+0(SB), $0
	MOVW	R0, R7           // r7 = syscall number (num arrives in R0)
	MOVW	a1+4(FP), R0     // r0 (overwrites num, no longer needed)
	MOVW	a2+8(FP), R1     // r1
	MOVW	a3+12(FP), R2    // r2
	MOVW	a4+16(FP), R3    // r3
	MOVW	a5+20(FP), R4    // r4
	MOVW	a6+24(FP), R5    // r5
	SWI	$0
	RET
