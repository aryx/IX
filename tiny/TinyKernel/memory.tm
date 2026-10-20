; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyMachine.ml)
;
; TinyKernel.ml's loops over memory, in assembly, with entry.tm's
; convention (the arguments at 0(sp), 4(sp)..., ML's integers: n is
; 2n+1): a partition copied at fork, zeroed at exec. (old: in entry.tm,
; which keeps what needs the machine's own instructions: the traps,
; k_run, the registers of control)

; k_copy(dst, src, n): n bytes, a multiple of 4, a word at a time (a
; partition copied at fork is a MB: the kernel's hottest loop)
k_copy:
	ldw	r1, 0(sp)
	sari	r1, r1, 1
	ldw	r2, 4(sp)
	sari	r2, r2, 1
	ldw	r3, 8(sp)
	sari	r3, r3, 1
	add	r3, r1, r3
k_copy1:
	bgeu	r1, r3, k_copy2
	ldw	r4, 0(r2)
	stw	r4, 0(r1)
	addi	r1, r1, 4
	addi	r2, r2, 4
	j	k_copy1
k_copy2:
	li	r13, 1
	ret

; k_zero(a, n): n bytes, a multiple of 4
k_zero:
	ldw	r1, 0(sp)
	sari	r1, r1, 1
	ldw	r2, 4(sp)
	sari	r2, r2, 1
	add	r2, r1, r2
k_zero1:
	bgeu	r1, r2, k_zero2
	stw	zero, 0(r1)
	addi	r1, r1, 4
	j	k_zero1
k_zero2:
	li	r13, 1
	ret
