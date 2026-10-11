; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyMachine.ml)
;
; The network: two packets sent on a wire that comes back (-net-loop
; 100), each received by the network's interrupt, whose cause and
; sources are printed ("4@": an interrupt, the fifth source, 16) with
; the packet's length as a letter (a is 1) and its bytes. Before the
; first comes back, "sent": the wire takes its time. Without a wire
; (-36(r0) reads 0), "no wire".

	ldw	r1, -36(r0)
	bne	r1, zero, wired
	la	r4, nowire
	li	r3, 8
	call	print
	stw	r0, -12(r0)
wired:
	la	r1, trap
	csrw	tvec, r1
	li	r1, 16			; the network's interrupt only
	csrw	ie, r1
	li	r11, 0			; the packets received
	la	r1, hello
	stw	r1, -48(r0)
	li	r1, 12
	stw	r1, -44(r0)
	li	r1, 1
	stw	r1, -40(r0)		; send
	la	r2, again
	stw	r2, -48(r0)
	li	r2, 6
	stw	r2, -44(r0)
	stw	r1, -40(r0)		; send
	la	r4, sent
	li	r3, 5
	call	print
	li	r1, 3			; supervisor, interrupts on
	csrw	status, r1
	li	r1, 2
wait:
	bne	r11, r1, wait
	stw	r0, -12(r0)

; r3 bytes at r4, to the console
print:
	ldb	r5, 0(r4)
	stb	r5, -16(r0)
	addi	r4, r4, 1
	addi	r3, r3, -1
	bne	r3, zero, print
	ret

; the interrupt: its cause and sources, the packet's length, the
; packet taken to the buffer and printed
trap:
	csrr	r5, cause
	addi	r5, r5, 48
	stb	r5, -16(r0)
	csrr	r5, tval
	addi	r5, r5, 48
	stb	r5, -16(r0)
	ldw	r3, -44(r0)		; the length of the packet that waits
	addi	r5, r3, 96
	stb	r5, -16(r0)
	li	r4, 0x10000		; the buffer
	stw	r4, -48(r0)
	stw	r3, -44(r0)
	li	r5, 2
	stw	r5, -40(r0)		; receive
tprint:
	ldb	r5, 0(r4)
	stb	r5, -16(r0)
	addi	r4, r4, 1
	addi	r3, r3, -1
	bne	r3, zero, tprint
	addi	r11, r11, 1
	eret

hello:
	.ascii	"hello, wire\n"
again:
	.ascii	"again\n"
sent:
	.ascii	"sent\n"
nowire:
	.ascii	"no wire\n"
