// MRC and MCR: 5a makes them words (a coprocessor's register to and from an ARM register)
TEXT _start+0(SB), $-4
	MRC	15, 0, R0, C(1), C(0), 2
	MCR	15, 0, R0, C(1), C(0), 2
	MCR	15, 0, R4, C(2), C(0), 1
	MCR	15, 0, R0, C(8), C(7)
	MRC	15, 0, R1, C(6), C(0), 0
