// Standard input, up to 256 bytes of it, written back reversed: read,
// a loop over memory, write. The status is the number of bytes.
TEXT _start(SB), $-8
	MOV	$0, R0			// standard input
	MOV	$in<>(SB), R1
	MOV	$256, R2
	MOV	$63, R8			// read
	SVC
	MOV	R0, R9			// the bytes read
	MOV	$in<>(SB), R1
	ADD	R9, R1			// past the last one
	MOV	$out<>(SB), R2
	MOV	R9, R3
next:
	CBZ	R3, write
	SUB	$1, R1
	MOVBU	(R1), R4
	MOVB	R4, (R2)
	ADD	$1, R2
	SUB	$1, R3
	B	next
write:
	MOV	$1, R0
	MOV	$out<>(SB), R1
	MOV	R9, R2
	MOV	$64, R8			// write
	SVC
	MOV	R9, R0
	MOV	$93, R8			// exit
	SVC

GLOBL	in<>(SB), $256
GLOBL	out<>(SB), $256
