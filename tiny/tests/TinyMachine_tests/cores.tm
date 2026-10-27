; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyMachine.ml)
;
; Three cores (TinyMachine_test.sh runs it with -cores 3; cores.expected):
; each starts at 0 and goes by its core. Core 0 prints the cores
; register, then raises the interrupt of cores 1 and 2 (a store at
; -64(r0)) and waits for theirs. Each of the others, interrupted,
; counts to 1000 in a loop of its own and writes, in its row of rows:
; the senders it read at -64(r0) (1: core 0), its core, its count's
; thousands; then reaches the console, a device, and faults (3), the
; cause in its row too; then raises core 0's interrupt. Core 0, when
; both have (their bits, 2 and 4, seen), prints the rows and halts.

	csrr	r1, core
	bne	r1, zero, other
	la	r1, trap0
	csrw	tvec, r1
	li	r1, 32			; the cores' interrupt only
	csrw	ie, r1
	csrr	r5, cores
	addi	r5, r5, 48
	stb	r5, -16(r0)
	li	r5, 10
	stb	r5, -16(r0)
	li	r1, 1
	stw	r1, -64(r0)
	li	r1, 2
	stw	r1, -64(r0)
	li	r1, 3			; supervisor, interrupts on
	csrw	status, r1
wait0:
	wfi				; asleep until an interrupt (idle at the halt)
	j	wait0

; core 0's: the senders added to those seen; both: the rows
trap0:
	ldw	r2, -64(r0)
	la	r3, seen
	ldw	r4, 0(r3)
	or	r4, r4, r2
	stw	r4, 0(r3)
	li	r5, 6
	beq	r4, r5, done
	eret
done:
	la	r3, rows
	li	r6, 2			; two rows of four words
row:
	li	r7, 4
col:
	ldw	r5, 16(r3)
	addi	r5, r5, 48
	stb	r5, -16(r0)
	addi	r3, r3, 4
	addi	r7, r7, -1
	bne	r7, zero, col
	li	r5, 10
	stb	r5, -16(r0)
	addi	r6, r6, -1
	bne	r6, zero, row
	stw	r0, -12(r0)

; the other cores: interrupted by core 0, then their work
other:
	la	r1, tramp
	csrw	tvec, r1
	li	r1, 32
	csrw	ie, r1
	li	r1, 3
	csrw	status, r1
waitk:
	j	waitk
tramp:
	csrr	r1, core
	shli	r3, r1, 4		; its row: rows + 16 * core
	la	r2, rows
	add	r3, r3, r2
	ldw	r2, -64(r0)
	stw	r2, 0(r3)
	stw	r1, 4(r3)
	li	r4, 1000
	li	r5, 0
count:
	addi	r5, r5, 1
	bne	r5, r4, count
	li	r4, 1000
	div	r5, r5, r4
	stw	r5, 8(r3)
	la	r2, fault
	csrw	tvec, r2
	stb	r5, -16(r0)		; the console: core 0's, a fault
fault:
	csrr	r2, cause
	stw	r2, 12(r3)
	stw	r0, -64(r0)		; core 0's interrupt
stop:
	j	stop

	.align	4
seen:	.word	0
rows:	.space	48
