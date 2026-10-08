// The stack as Linux leaves it for a program: the count of its
// arguments, then their addresses, then a zero. Each argument on its
// line, and the count as the exit status.
TEXT _start(SB), $-8
	MOV	(RSP), R9		// argc
	ADD	$8, RSP, R10		// argv
next:
	MOV	(R10), R1
	CBZ	R1, done
	MOV	R1, R2			// its length: to the zero that ends it
length:
	MOVBU	(R2), R3
	CBZ	R3, write
	ADD	$1, R2
	B	length
write:
	SUB	R1, R2
	MOV	$1, R0
	MOV	$64, R8			// write
	SVC
	MOV	$1, R0
	MOV	$newline<>(SB), R1
	MOV	$1, R2
	SVC
	ADD	$8, R10
	B	next
done:
	MOV	R9, R0
	MOV	$93, R8			// exit
	SVC

DATA	newline<>+0(SB)/1, $"\n"
