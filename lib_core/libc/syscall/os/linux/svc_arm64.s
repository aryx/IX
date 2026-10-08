// goken's, around Plan 9's libc (libc's README.md; LICENSE).
// The way into Linux's kernel on arm64: the number in R8, six
// arguments in R0 to R5. Only the first argument of a C call comes in
// a register (R0, the number); the others are on the stack, from
// 8(FP).
TEXT _syscall6+0(SB), $0
	MOV	R0, R8
	MOV	a1+8(FP), R0
	MOV	a2+16(FP), R1
	MOV	a3+24(FP), R2
	MOV	a4+32(FP), R3
	MOV	a5+40(FP), R4
	MOV	a6+48(FP), R5
	SVC	$0
	RETURN

// the same under another name, declared as giving a vlong: for lseek
TEXT _syscall6v+0(SB), $0
	MOV	R0, R8
	MOV	a1+8(FP), R0
	MOV	a2+16(FP), R1
	MOV	a3+24(FP), R2
	MOV	a4+32(FP), R3
	MOV	a5+40(FP), R4
	MOV	a6+48(FP), R5
	SVC	$0
	RETURN
