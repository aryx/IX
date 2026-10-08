; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyMachine.ml)
;
; TinyGraphics.ml's rows: the three loops of bytes its draw is made of,
; in assembly (a screen is 307,200 of them), with entry.tm's convention
; (the arguments at 0(sp), 4(sp)..., ML's integers: n is 2n+1).

; row_copy(dst, src, n): n bytes, from the first
row_copy:
	ldw	r1, 0(sp)
	sari	r1, r1, 1
	ldw	r2, 4(sp)
	sari	r2, r2, 1
	ldw	r3, 8(sp)
	sari	r3, r3, 1
	add	r3, r1, r3
row_copy1:
	bgeu	r1, r3, row_copy2
	ldb	r4, 0(r2)
	stb	r4, 0(r1)
	addi	r1, r1, 1
	addi	r2, r2, 1
	j	row_copy1
row_copy2:
	li	r13, 1
	ret

; row_fill(dst, colour, n): n bytes of that colour
row_fill:
	ldw	r1, 0(sp)
	sari	r1, r1, 1
	ldw	r2, 4(sp)
	sari	r2, r2, 1
	ldw	r3, 8(sp)
	sari	r3, r3, 1
	add	r3, r1, r3
row_fill1:
	bgeu	r1, r3, row_fill2
	stb	r2, 0(r1)
	addi	r1, r1, 1
	j	row_fill1
row_fill2:
	li	r13, 1
	ret

; row_mask(dst, colour, mask, n): the colour where the mask's byte is
; not 0 (a character's row: the mask is the font's)
row_mask:
	ldw	r1, 0(sp)
	sari	r1, r1, 1
	ldw	r2, 4(sp)
	sari	r2, r2, 1
	ldw	r3, 8(sp)
	sari	r3, r3, 1
	ldw	r4, 12(sp)
	sari	r4, r4, 1
	add	r4, r1, r4
row_mask1:
	bgeu	r1, r4, row_mask3
	ldb	r5, 0(r3)
	beq	r5, zero, row_mask2
	stb	r2, 0(r1)
row_mask2:
	addi	r1, r1, 1
	addi	r3, r3, 1
	j	row_mask1
row_mask3:
	li	r13, 1
	ret
