// Plan 9's, by principia and goken (libc's README.md; LICENSE).
// principia's: the caller's return address, which its caller saved at
// the top of its stack before calling (the argument is not looked
// at). Nothing reads the result yet.
TEXT getcallerpc+0(SB), $0
	MOVW	0(R13), R0
	RET
