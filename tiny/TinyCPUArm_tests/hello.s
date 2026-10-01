// The smallest program for Linux on arm64 (TinyCPUArm_test.sh runs it
// on the real CPU, under mini-5i and under tiny-arm): a line written,
// then exit. A system call: its number in R8, its arguments from R0.
TEXT _start(SB), $-8
	MOV	$1, R0			// standard output
	MOV	$message<>(SB), R1
	MOV	$13, R2
	MOV	$64, R8			// write
	SVC
	MOV	$0, R0
	MOV	$93, R8			// exit
	SVC

DATA	message<>+0(SB)/13, $"Hello, world\n"
