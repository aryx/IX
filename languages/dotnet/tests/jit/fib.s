// int32 Fib::Rec(int32), 24 bytes of IL: 4 slots, 0 locals
	TEXT	Fib_Rec(SB), 0, $20
	MOVW	R0, a0+0(FP)
	// IL_0000: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_0001: ldc.i4.2
	MOVW	$2, R1
	MOVW	R1, s1-8(SP)
	// IL_0002: bge.s
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	CMP	R2, R1
	BGE	Fib_Rec_5
	// IL_0004: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_0005: ret
	MOVW	s0-4(SP), R0
	RET
Fib_Rec_5:
	// IL_0006: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_0007: ldc.i4.1
	MOVW	$1, R1
	MOVW	R1, s1-8(SP)
	// IL_0008: sub
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	SUB	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_0009: call
	MOVW	s0-4(SP), R0
	BL	Fib_Rec(SB)
	MOVW	R0, s0-4(SP)
	// IL_000e: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_000f: ldc.i4.2
	MOVW	$2, R1
	MOVW	R1, s2-12(SP)
	// IL_0010: sub
	MOVW	s1-8(SP), R1
	MOVW	s2-12(SP), R2
	SUB	R2, R1
	MOVW	R1, s1-8(SP)
	// IL_0011: call
	MOVW	s1-8(SP), R0
	BL	Fib_Rec(SB)
	MOVW	R0, s1-8(SP)
	// IL_0016: add
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	ADD	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_0017: ret
	MOVW	s0-4(SP), R0
	RET
// int32 Fib::Loop(int32), 24 bytes of IL: 3 slots, 3 locals
	TEXT	Fib_Loop(SB), 0, $28
	MOVW	R0, a0+0(FP)
	MOVW	$0, R1
	MOVW	R1, l0-16(SP)
	MOVW	R1, l1-20(SP)
	MOVW	R1, l2-24(SP)
	// IL_0000: ldc.i4.0
	MOVW	$0, R1
	MOVW	R1, s0-4(SP)
	// IL_0001: stloc.0
	MOVW	s0-4(SP), R1
	MOVW	R1, l0-16(SP)
	// IL_0002: ldc.i4.1
	MOVW	$1, R1
	MOVW	R1, s0-4(SP)
	// IL_0003: stloc.1
	MOVW	s0-4(SP), R1
	MOVW	R1, l1-20(SP)
	// IL_0004: ldc.i4.0
	MOVW	$0, R1
	MOVW	R1, s0-4(SP)
	// IL_0005: stloc.2
	MOVW	s0-4(SP), R1
	MOVW	R1, l2-24(SP)
	// IL_0006: br.s
	B	Fib_Loop_17
Fib_Loop_7:
	// IL_0008: ldloc.0
	MOVW	l0-16(SP), R1
	MOVW	R1, s0-4(SP)
	// IL_0009: ldloc.1
	MOVW	l1-20(SP), R1
	MOVW	R1, s1-8(SP)
	// IL_000a: add
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	ADD	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_000b: ldloc.1
	MOVW	l1-20(SP), R1
	MOVW	R1, s1-8(SP)
	// IL_000c: stloc.0
	MOVW	s1-8(SP), R1
	MOVW	R1, l0-16(SP)
	// IL_000d: stloc.1
	MOVW	s0-4(SP), R1
	MOVW	R1, l1-20(SP)
	// IL_000e: ldloc.2
	MOVW	l2-24(SP), R1
	MOVW	R1, s0-4(SP)
	// IL_000f: ldc.i4.1
	MOVW	$1, R1
	MOVW	R1, s1-8(SP)
	// IL_0010: add
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	ADD	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_0011: stloc.2
	MOVW	s0-4(SP), R1
	MOVW	R1, l2-24(SP)
Fib_Loop_17:
	// IL_0012: ldloc.2
	MOVW	l2-24(SP), R1
	MOVW	R1, s0-4(SP)
	// IL_0013: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_0014: blt.s
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	CMP	R2, R1
	BLT	Fib_Loop_7
	// IL_0016: ldloc.0
	MOVW	l0-16(SP), R1
	MOVW	R1, s0-4(SP)
	// IL_0017: ret
	MOVW	s0-4(SP), R0
	RET
// not compiled: void Fib::Main(): IL_0007: a call into the library
// not compiled: instance void Fib::.ctor(): an instance method: this is a reference
// fib.dll: 2 methods compiled, 2 not
