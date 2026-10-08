; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyMachine.ml)
;
; TinyGraphics.ml's rows: the three loops of bytes its draw is made of,
; in assembly (a screen is 307,200 of them), with entry.tm's convention
; (the arguments at 0(sp), 4(sp)..., ML's integers: n is 2n+1).

; row_copy(dst, src, n): n bytes, from the first. A word at a time
; where both are at the same place in a word (the machine's words are
; at multiples of 4): the bytes up to a word's start, the words, the
; bytes left. (old: a byte at a time, the loop at row_copy3 alone: a
; window composed on the screen was 5 instructions a pixel)
row_copy:
	ldw	r1, 0(sp)
	sari	r1, r1, 1
	ldw	r2, 4(sp)
	sari	r2, r2, 1
	ldw	r3, 8(sp)
	sari	r3, r3, 1
	add	r3, r1, r3
	xor	r4, r1, r2
	andi	r4, r4, 3
	bne	r4, zero, row_copy3
row_copy1:
	andi	r4, r1, 3
	beq	r4, zero, row_copy2
	bgeu	r1, r3, row_copy4
	ldb	r4, 0(r2)
	stb	r4, 0(r1)
	addi	r1, r1, 1
	addi	r2, r2, 1
	j	row_copy1
row_copy2:
	addi	r5, r1, 4
	bltu	r3, r5, row_copy3
	ldw	r4, 0(r2)
	stw	r4, 0(r1)
	addi	r1, r1, 4
	addi	r2, r2, 4
	j	row_copy2
row_copy3:
	bgeu	r1, r3, row_copy4
	ldb	r4, 0(r2)
	stb	r4, 0(r1)
	addi	r1, r1, 1
	addi	r2, r2, 1
	j	row_copy3
row_copy4:
	li	r13, 1
	ret

; row_fill(dst, colour, n): n bytes of that colour; the same way, a
; word being the colour four times
row_fill:
	ldw	r1, 0(sp)
	sari	r1, r1, 1
	ldw	r2, 4(sp)
	sari	r2, r2, 1
	andi	r2, r2, 255
	ldw	r3, 8(sp)
	sari	r3, r3, 1
	add	r3, r1, r3
	shli	r4, r2, 8
	or	r4, r4, r2
	shli	r5, r4, 16
	or	r4, r4, r5
row_fill1:
	andi	r5, r1, 3
	beq	r5, zero, row_fill2
	bgeu	r1, r3, row_fill4
	stb	r2, 0(r1)
	addi	r1, r1, 1
	j	row_fill1
row_fill2:
	addi	r5, r1, 4
	bltu	r3, r5, row_fill3
	stw	r4, 0(r1)
	addi	r1, r1, 4
	j	row_fill2
row_fill3:
	bgeu	r1, r3, row_fill4
	stb	r2, 0(r1)
	addi	r1, r1, 1
	j	row_fill3
row_fill4:
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
