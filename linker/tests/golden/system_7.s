// a kernel's instructions (plan_kernel_mini_ml.md): system registers by
// their bits (MRS, MSR), the barriers, SYS and its names, the hints, ERET
TEXT _start+0(SB), $0
	MRS	SPR(0x184000), R0
	MRS	SPR(0x1800a0), R1
	MSR	R0, SPR(0x182000)
	MSR	R5, SPR(0x1c1100)
	MSR	R2, SPR(0x1c4020)
	ISB	$15
	DSB	$15
	DMB	$11
	TLBI	$0x8700
	TLBI	R3, $0x8320
	IC	$0x7500
	SYS	$0x7500
	WFI
	WFE
	ERET
