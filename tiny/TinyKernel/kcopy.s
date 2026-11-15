; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyMachine.ml)
;
; TinyKernel.ml's loops over memory, in assembly, with kentry.s's
; convention (the arguments at 0(sp), 4(sp)..., ML's integers: n is
; 2n+1): a partition copied at fork; a frame and the speaker's ring
; zeroed (no more a partition at exec: TinyKernel.ml's load_prog).

; k_copy(dst, src, n): n bytes, a multiple of 4, a word at a time (a
; partition copied at fork is a MB: the kernel's hottest loop).
;
; opti: eight words a turn while 32 bytes are left, then a word a turn,
; as Plan 9's memmove does its 32-byte chunks (principia's
; libc/arm/memmove.s, with ARM's MOVM of four registers): 2.5
; instructions a word instead of 6, the test, the two adds and the jump
; paid once for eight (plan_tiny_self_speed.md; k_copy was 17% of the
; kernel's instructions in self-quick's session).
;
; old: the word loop, k_copy1, alone.
k_copy:
	ldw	r1, 0(sp)
	sari	r1, r1, 1
	ldw	r2, 4(sp)
	sari	r2, r2, 1
	ldw	r3, 8(sp)
	sari	r3, r3, 1
	add	r3, r1, r3
	; (r5: the last place a chunk of 32 bytes starts at, plus 4; n and
	; the addresses are multiples of 4)
	addi	r5, r3, -28
k_copy8:
	bgeu	r1, r5, k_copy1
	ldw	r4, 0(r2)
	stw	r4, 0(r1)
	ldw	r4, 4(r2)
	stw	r4, 4(r1)
	ldw	r4, 8(r2)
	stw	r4, 8(r1)
	ldw	r4, 12(r2)
	stw	r4, 12(r1)
	ldw	r4, 16(r2)
	stw	r4, 16(r1)
	ldw	r4, 20(r2)
	stw	r4, 20(r1)
	ldw	r4, 24(r2)
	stw	r4, 24(r1)
	ldw	r4, 28(r2)
	stw	r4, 28(r1)
	addi	r1, r1, 32
	addi	r2, r2, 32
	j	k_copy8
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
