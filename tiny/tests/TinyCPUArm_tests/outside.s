// A word outside tiny-arm's subset (a floating point addition): the
// real CPU and mini-5i run it, tiny-arm stops on it and says where.
TEXT _start(SB), $-8
	FADDD	F0, F1
	MOV	$0, R0
	MOV	$93, R8			// exit
	SVC
