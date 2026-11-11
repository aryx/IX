; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyMachine.ml)
;
; A program whose profile is known (TinyProfiler_test.sh): main calls
; spin 100 times; spin loops 10 times. A count goes to the last label at
; or before it, so: main 2 (li, nop); loop 100 * 3 + 2 (call, addi, bne,
; then li and sys); spin 100 (its li); spin1 100 * (10 * 2 + 1) (its
; loop, and the ret after it). ml.L1 is a label of the kind a compiler
; makes inside a function: its instructions are counted as spin1's.
main:
	li	r5, 100
	nop
loop:
	call	spin
	addi	r5, r5, -1
	bne	r5, zero, loop
	li	r1, 0
	sys	0
spin:
	li	r6, 10
spin1:
	addi	r6, r6, -1
ml.L1:
	bne	r6, zero, spin1
	ret
