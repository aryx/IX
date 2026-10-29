// int32 Ints::Gcd(int32, int32), 15 bytes of IL: 3 slots, 0 locals
	TEXT	Ints_Gcd(SB), 0, $16
	MOVW	R0, a0+0(FP)
	// IL_0000: br.s
	B	Ints_Gcd_7
Ints_Gcd_1:
	// IL_0002: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_0003: ldarg.1
	MOVW	a1+4(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_0004: rem
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	CMP	$0, R2
	BNE	2(PC)
	BL	jit_divide_by_zero(SB)
	MOD	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_0005: ldarg.1
	MOVW	a1+4(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_0006: starg.s
	MOVW	s1-8(SP), R1
	MOVW	R1, a0+0(FP)
	// IL_0008: starg.s
	MOVW	s0-4(SP), R1
	MOVW	R1, a1+4(FP)
Ints_Gcd_7:
	// IL_000a: ldarg.1
	MOVW	a1+4(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_000b: brtrue.s
	MOVW	s0-4(SP), R1
	CMP	$0, R1
	BNE	Ints_Gcd_1
	// IL_000d: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_000e: ret
	MOVW	s0-4(SP), R0
	RET
// int32 Ints::Pow(int32, int32), 20 bytes of IL: 3 slots, 2 locals
	TEXT	Ints_Pow(SB), 0, $24
	MOVW	R0, a0+0(FP)
	MOVW	$0, R1
	MOVW	R1, l0-16(SP)
	MOVW	R1, l1-20(SP)
	// IL_0000: ldc.i4.1
	MOVW	$1, R1
	MOVW	R1, s0-4(SP)
	// IL_0001: stloc.0
	MOVW	s0-4(SP), R1
	MOVW	R1, l0-16(SP)
	// IL_0002: ldc.i4.0
	MOVW	$0, R1
	MOVW	R1, s0-4(SP)
	// IL_0003: stloc.1
	MOVW	s0-4(SP), R1
	MOVW	R1, l1-20(SP)
	// IL_0004: br.s
	B	Ints_Pow_13
Ints_Pow_5:
	// IL_0006: ldloc.0
	MOVW	l0-16(SP), R1
	MOVW	R1, s0-4(SP)
	// IL_0007: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_0008: mul
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	MUL	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_0009: stloc.0
	MOVW	s0-4(SP), R1
	MOVW	R1, l0-16(SP)
	// IL_000a: ldloc.1
	MOVW	l1-20(SP), R1
	MOVW	R1, s0-4(SP)
	// IL_000b: ldc.i4.1
	MOVW	$1, R1
	MOVW	R1, s1-8(SP)
	// IL_000c: add
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	ADD	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_000d: stloc.1
	MOVW	s0-4(SP), R1
	MOVW	R1, l1-20(SP)
Ints_Pow_13:
	// IL_000e: ldloc.1
	MOVW	l1-20(SP), R1
	MOVW	R1, s0-4(SP)
	// IL_000f: ldarg.1
	MOVW	a1+4(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_0010: blt.s
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	CMP	R2, R1
	BLT	Ints_Pow_5
	// IL_0012: ldloc.0
	MOVW	l0-16(SP), R1
	MOVW	R1, s0-4(SP)
	// IL_0013: ret
	MOVW	s0-4(SP), R0
	RET
// int32 Ints::Bits(int32), 20 bytes of IL: 4 slots, 1 locals
	TEXT	Ints_Bits(SB), 0, $24
	MOVW	R0, a0+0(FP)
	MOVW	$0, R1
	MOVW	R1, l0-20(SP)
	// IL_0000: ldc.i4.0
	MOVW	$0, R1
	MOVW	R1, s0-4(SP)
	// IL_0001: stloc.0
	MOVW	s0-4(SP), R1
	MOVW	R1, l0-20(SP)
	// IL_0002: br.s
	B	Ints_Bits_13
Ints_Bits_3:
	// IL_0004: ldloc.0
	MOVW	l0-20(SP), R1
	MOVW	R1, s0-4(SP)
	// IL_0005: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_0006: ldc.i4.1
	MOVW	$1, R1
	MOVW	R1, s2-12(SP)
	// IL_0007: and
	MOVW	s1-8(SP), R1
	MOVW	s2-12(SP), R2
	AND	R2, R1
	MOVW	R1, s1-8(SP)
	// IL_0008: add
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	ADD	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_0009: stloc.0
	MOVW	s0-4(SP), R1
	MOVW	R1, l0-20(SP)
	// IL_000a: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_000b: ldc.i4.1
	MOVW	$1, R1
	MOVW	R1, s1-8(SP)
	// IL_000c: shr.un
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	AND	$31, R2
	SRL	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_000d: starg.s
	MOVW	s0-4(SP), R1
	MOVW	R1, a0+0(FP)
Ints_Bits_13:
	// IL_000f: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_0010: brtrue.s
	MOVW	s0-4(SP), R1
	CMP	$0, R1
	BNE	Ints_Bits_3
	// IL_0012: ldloc.0
	MOVW	l0-20(SP), R1
	MOVW	R1, s0-4(SP)
	// IL_0013: ret
	MOVW	s0-4(SP), R0
	RET
// int32 Ints::Mix(int32, int32, int32, int32), 20 bytes of IL: 4 slots, 0 locals
	TEXT	Ints_Mix(SB), 0, $20
	MOVW	R0, a0+0(FP)
	// IL_0000: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_0001: ldc.i4.3
	MOVW	$3, R1
	MOVW	R1, s1-8(SP)
	// IL_0002: shl
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	AND	$31, R2
	SLL	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_0003: ldarg.1
	MOVW	a1+4(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_0004: ldc.i4.1
	MOVW	$1, R1
	MOVW	R1, s2-12(SP)
	// IL_0005: shr
	MOVW	s1-8(SP), R1
	MOVW	s2-12(SP), R2
	AND	$31, R2
	SRA	R2, R1
	MOVW	R1, s1-8(SP)
	// IL_0006: sub
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	SUB	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_0007: ldarg.2
	MOVW	a2+8(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_0008: ldarg.3
	MOVW	a3+12(FP), R1
	MOVW	R1, s2-12(SP)
	// IL_0009: xor
	MOVW	s1-8(SP), R1
	MOVW	s2-12(SP), R2
	EOR	R2, R1
	MOVW	R1, s1-8(SP)
	// IL_000a: add
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	ADD	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_000b: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_000c: not
	MOVW	s1-8(SP), R1
	MVN	R1, R1
	MOVW	R1, s1-8(SP)
	// IL_000d: ldarg.1
	MOVW	a1+4(FP), R1
	MOVW	R1, s2-12(SP)
	// IL_000e: or
	MOVW	s1-8(SP), R1
	MOVW	s2-12(SP), R2
	ORR	R2, R1
	MOVW	R1, s1-8(SP)
	// IL_000f: sub
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	SUB	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_0010: ldarg.2
	MOVW	a2+8(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_0011: neg
	MOVW	s1-8(SP), R1
	RSB	$0, R1, R1
	MOVW	R1, s1-8(SP)
	// IL_0012: add
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	ADD	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_0013: ret
	MOVW	s0-4(SP), R0
	RET
// int32 Ints::Day(int32), 38 bytes of IL: 2 slots, 0 locals
	TEXT	Ints_Day(SB), 0, $12
	MOVW	R0, a0+0(FP)
	// IL_0000: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_0001: switch
	MOVW	s0-4(SP), R1
	CMP	$0, R1
	BEQ	Ints_Day_3
	CMP	$1, R1
	BEQ	Ints_Day_5
	CMP	$2, R1
	BEQ	Ints_Day_7
	CMP	$3, R1
	BEQ	Ints_Day_9
	// IL_0016: br.s
	B	Ints_Day_11
Ints_Day_3:
	// IL_0018: ldc.i4.s
	MOVW	$10, R1
	MOVW	R1, s0-4(SP)
	// IL_001a: ret
	MOVW	s0-4(SP), R0
	RET
Ints_Day_5:
	// IL_001b: ldc.i4.s
	MOVW	$11, R1
	MOVW	R1, s0-4(SP)
	// IL_001d: ret
	MOVW	s0-4(SP), R0
	RET
Ints_Day_7:
	// IL_001e: ldc.i4.s
	MOVW	$12, R1
	MOVW	R1, s0-4(SP)
	// IL_0020: ret
	MOVW	s0-4(SP), R0
	RET
Ints_Day_9:
	// IL_0021: ldc.i4.s
	MOVW	$13, R1
	MOVW	R1, s0-4(SP)
	// IL_0023: ret
	MOVW	s0-4(SP), R0
	RET
Ints_Day_11:
	// IL_0024: ldc.i4.m1
	MOVW	$-1, R1
	MOVW	R1, s0-4(SP)
	// IL_0025: ret
	MOVW	s0-4(SP), R0
	RET
// bool Ints::Below(uint32, uint32), 5 bytes of IL: 3 slots, 0 locals
	TEXT	Ints_Below(SB), 0, $16
	MOVW	R0, a0+0(FP)
	// IL_0000: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_0001: ldarg.1
	MOVW	a1+4(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_0002: clt.un
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	CMP	R2, R1
	MOVW	$0, R3
	MOVW.LO	$1, R3
	MOVW	R3, s0-4(SP)
	// IL_0004: ret
	MOVW	s0-4(SP), R0
	RET
// int32 Ints::Unsigned(int32, int32), 8 bytes of IL: 4 slots, 0 locals
	TEXT	Ints_Unsigned(SB), 0, $20
	MOVW	R0, a0+0(FP)
	// IL_0000: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_0001: ldarg.1
	MOVW	a1+4(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_0002: div.un
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	CMP	$0, R2
	BNE	2(PC)
	BL	jit_divide_by_zero(SB)
	DIVU	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_0003: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_0004: ldarg.1
	MOVW	a1+4(FP), R1
	MOVW	R1, s2-12(SP)
	// IL_0005: rem.un
	MOVW	s1-8(SP), R1
	MOVW	s2-12(SP), R2
	CMP	$0, R2
	BNE	2(PC)
	BL	jit_divide_by_zero(SB)
	MODU	R2, R1
	MOVW	R1, s1-8(SP)
	// IL_0006: add
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	ADD	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_0007: ret
	MOVW	s0-4(SP), R0
	RET
// int32 Ints::Narrow(int32), 12 bytes of IL: 3 slots, 0 locals
	TEXT	Ints_Narrow(SB), 0, $16
	MOVW	R0, a0+0(FP)
	// IL_0000: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_0001: conv.i1
	MOVW	s0-4(SP), R1
	SLL	$24, R1
	SRA	$24, R1
	MOVW	R1, s0-4(SP)
	// IL_0002: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_0003: conv.u1
	MOVW	s1-8(SP), R1
	AND	$255, R1
	MOVW	R1, s1-8(SP)
	// IL_0004: add
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	ADD	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_0005: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_0006: conv.i2
	MOVW	s1-8(SP), R1
	SLL	$16, R1
	SRA	$16, R1
	MOVW	R1, s1-8(SP)
	// IL_0007: add
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	ADD	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_0008: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_0009: conv.u2
	MOVW	s1-8(SP), R1
	SLL	$16, R1
	SRL	$16, R1
	MOVW	R1, s1-8(SP)
	// IL_000a: add
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	ADD	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_000b: ret
	MOVW	s0-4(SP), R0
	RET
// int32 Ints::Clamp(int32, int32, int32), 16 bytes of IL: 3 slots, 0 locals
	TEXT	Ints_Clamp(SB), 0, $16
	MOVW	R0, a0+0(FP)
	// IL_0000: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_0001: ldarg.1
	MOVW	a1+4(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_0002: bge.s
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	CMP	R2, R1
	BGE	Ints_Clamp_5
	// IL_0004: ldarg.1
	MOVW	a1+4(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_0005: starg.s
	MOVW	s0-4(SP), R1
	MOVW	R1, a0+0(FP)
Ints_Clamp_5:
	// IL_0007: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_0008: ldarg.2
	MOVW	a2+8(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_0009: ble.s
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	CMP	R2, R1
	BLE	Ints_Clamp_10
	// IL_000b: ldarg.2
	MOVW	a2+8(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_000c: starg.s
	MOVW	s0-4(SP), R1
	MOVW	R1, a0+0(FP)
Ints_Clamp_10:
	// IL_000e: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_000f: ret
	MOVW	s0-4(SP), R0
	RET
// int32 Ints::Collatz(int32), 31 bytes of IL: 3 slots, 1 locals
	TEXT	Ints_Collatz(SB), 0, $20
	MOVW	R0, a0+0(FP)
	MOVW	$0, R1
	MOVW	R1, l0-16(SP)
	// IL_0000: ldc.i4.0
	MOVW	$0, R1
	MOVW	R1, s0-4(SP)
	// IL_0001: stloc.0
	MOVW	s0-4(SP), R1
	MOVW	R1, l0-16(SP)
	// IL_0002: br.s
	B	Ints_Collatz_21
Ints_Collatz_3:
	// IL_0004: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_0005: ldc.i4.2
	MOVW	$2, R1
	MOVW	R1, s1-8(SP)
	// IL_0006: rem
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	CMP	$0, R2
	BNE	2(PC)
	BL	jit_divide_by_zero(SB)
	MOD	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_0007: brfalse.s
	MOVW	s0-4(SP), R1
	CMP	$0, R1
	BEQ	Ints_Collatz_13
	// IL_0009: ldc.i4.3
	MOVW	$3, R1
	MOVW	R1, s0-4(SP)
	// IL_000a: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_000b: mul
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	MUL	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_000c: ldc.i4.1
	MOVW	$1, R1
	MOVW	R1, s1-8(SP)
	// IL_000d: add
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	ADD	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_000e: br.s
	B	Ints_Collatz_16
Ints_Collatz_13:
	// IL_0010: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_0011: ldc.i4.2
	MOVW	$2, R1
	MOVW	R1, s1-8(SP)
	// IL_0012: div
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	CMP	$0, R2
	BNE	2(PC)
	BL	jit_divide_by_zero(SB)
	DIV	R2, R1
	MOVW	R1, s0-4(SP)
Ints_Collatz_16:
	// IL_0013: starg.s
	MOVW	s0-4(SP), R1
	MOVW	R1, a0+0(FP)
	// IL_0015: ldloc.0
	MOVW	l0-16(SP), R1
	MOVW	R1, s0-4(SP)
	// IL_0016: ldc.i4.1
	MOVW	$1, R1
	MOVW	R1, s1-8(SP)
	// IL_0017: add
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	ADD	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_0018: stloc.0
	MOVW	s0-4(SP), R1
	MOVW	R1, l0-16(SP)
Ints_Collatz_21:
	// IL_0019: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_001a: ldc.i4.1
	MOVW	$1, R1
	MOVW	R1, s1-8(SP)
	// IL_001b: bne.un.s
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	CMP	R2, R1
	BNE	Ints_Collatz_3
	// IL_001d: ldloc.0
	MOVW	l0-16(SP), R1
	MOVW	R1, s0-4(SP)
	// IL_001e: ret
	MOVW	s0-4(SP), R0
	RET
// int32 Ints::Ack(int32, int32), 38 bytes of IL: 5 slots, 0 locals
	TEXT	Ints_Ack(SB), 0, $28
	MOVW	R0, a0+0(FP)
	// IL_0000: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_0001: brfalse.s
	MOVW	s0-4(SP), R1
	CMP	$0, R1
	BEQ	Ints_Ack_20
	// IL_0003: ldarg.1
	MOVW	a1+4(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_0004: brfalse.s
	MOVW	s0-4(SP), R1
	CMP	$0, R1
	BEQ	Ints_Ack_14
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
	// IL_0009: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s1-8(SP)
	// IL_000a: ldarg.1
	MOVW	a1+4(FP), R1
	MOVW	R1, s2-12(SP)
	// IL_000b: ldc.i4.1
	MOVW	$1, R1
	MOVW	R1, s3-16(SP)
	// IL_000c: sub
	MOVW	s2-12(SP), R1
	MOVW	s3-16(SP), R2
	SUB	R2, R1
	MOVW	R1, s2-12(SP)
	// IL_000d: call
	MOVW	s2-12(SP), R1
	MOVW	R1, 8(R13)
	MOVW	s1-8(SP), R0
	BL	Ints_Ack(SB)
	MOVW	R0, s1-8(SP)
	// IL_0012: call
	MOVW	s1-8(SP), R1
	MOVW	R1, 8(R13)
	MOVW	s0-4(SP), R0
	BL	Ints_Ack(SB)
	MOVW	R0, s0-4(SP)
	// IL_0017: ret
	MOVW	s0-4(SP), R0
	RET
Ints_Ack_14:
	// IL_0018: ldarg.0
	MOVW	a0+0(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_0019: ldc.i4.1
	MOVW	$1, R1
	MOVW	R1, s1-8(SP)
	// IL_001a: sub
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	SUB	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_001b: ldc.i4.1
	MOVW	$1, R1
	MOVW	R1, s1-8(SP)
	// IL_001c: call
	MOVW	s1-8(SP), R1
	MOVW	R1, 8(R13)
	MOVW	s0-4(SP), R0
	BL	Ints_Ack(SB)
	MOVW	R0, s0-4(SP)
	// IL_0021: ret
	MOVW	s0-4(SP), R0
	RET
Ints_Ack_20:
	// IL_0022: ldarg.1
	MOVW	a1+4(FP), R1
	MOVW	R1, s0-4(SP)
	// IL_0023: ldc.i4.1
	MOVW	$1, R1
	MOVW	R1, s1-8(SP)
	// IL_0024: add
	MOVW	s0-4(SP), R1
	MOVW	s1-8(SP), R2
	ADD	R2, R1
	MOVW	R1, s0-4(SP)
	// IL_0025: ret
	MOVW	s0-4(SP), R0
	RET
// not compiled: void Ints::Main(): IL_002a: int32& on the stack
// not compiled: instance void Ints::.ctor(): an instance method: this is a reference
// ints.dll: 11 methods compiled, 2 not
