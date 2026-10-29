// a fault three calls deep (debuggers/tests/walk.sh): _main calls f,
// f (a frame of its own) calls g, a leaf, which reads address 0

TEXT _main(SB), $8
	MOVW	$1, R1
	BL	f(SB)
	RET

TEXT f(SB), $16
	MOVW	$2, R1
	MOVW	R1, 8(R13)
	BL	g(SB)
	RET

TEXT g(SB), $-4
	MOVW	$0, R2
	MOVW	0(R2), R3
	RET
