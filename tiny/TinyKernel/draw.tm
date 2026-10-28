; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyMachine.ml)
;
; TinyKernelGraphics.ml's rows: the loops of bytes its draw is made of,
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
	addi	r5, r1, 16		; four words at a time while there are
	bltu	r3, r5, row_copy5
	ldw	r4, 0(r2)
	stw	r4, 0(r1)
	ldw	r4, 4(r2)
	stw	r4, 4(r1)
	ldw	r4, 8(r2)
	stw	r4, 8(r1)
	ldw	r4, 12(r2)
	stw	r4, 12(r1)
	addi	r1, r1, 16
	addi	r2, r2, 16
	j	row_copy2
row_copy5:				; then a word at a time
	addi	r5, r1, 4
	bltu	r3, r5, row_copy3
	ldw	r4, 0(r2)
	stw	r4, 0(r1)
	addi	r1, r1, 4
	addi	r2, r2, 4
	j	row_copy5
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
	addi	r5, r1, 16		; four words at a time while there are
	bltu	r3, r5, row_fill5
	stw	r4, 0(r1)
	stw	r4, 4(r1)
	stw	r4, 8(r1)
	stw	r4, 12(r1)
	addi	r1, r1, 16
	j	row_fill2
row_fill5:				; then a word at a time
	addi	r5, r1, 4
	bltu	r3, r5, row_fill3
	stw	r4, 0(r1)
	addi	r1, r1, 4
	j	row_fill5
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

; row_mix(dst, table, mask, n): where the mask's byte is not 0, the
; pixel mixed by its level: the table's byte at 256 times the level (the
; mask's two high bits: 85, 170 and 255 are 1, 2 and 3) and the pixel's
; colour (a colour's mixes, TinyKernelGraphics.ml's mix: a grey font)
row_mix:
	ldw	r1, 0(sp)
	sari	r1, r1, 1
	ldw	r2, 4(sp)
	sari	r2, r2, 1
	ldw	r3, 8(sp)
	sari	r3, r3, 1
	ldw	r4, 12(sp)
	sari	r4, r4, 1
	add	r4, r1, r4
row_mix1:
	bgeu	r1, r4, row_mix3
	ldb	r5, 0(r3)
	beq	r5, zero, row_mix2
	shri	r5, r5, 6
	shli	r5, r5, 8
	add	r5, r5, r2
	ldb	r6, 0(r1)
	add	r5, r5, r6
	ldb	r5, 0(r5)
	stb	r5, 0(r1)
row_mix2:
	addi	r1, r1, 1
	addi	r3, r3, 1
	j	row_mix1
row_mix3:
	li	r13, 1
	ret

; glyphs(dst, width, colour, font, s, n): the n characters of the string
; s (an ML string: its bytes from the address given), side by side from
; dst, the first one's top left pixel, in an image [width] pixels wide:
; each character 8 by 16, the colour where the font's mask is set (the
; mask is an image 1024 wide, character c at column 8c, a set pixel 255:
; font_mask in TinyKernelGraphics.ml); a byte beyond 127 is a ?. A
; character's row is 8 bytes, two words: each is merged with the colour
; where the mask's word is set (d ^ ((d ^ colour) & mask)), and a row
; with nothing set is skipped. So dst and width must be multiples of 4
; (TinyKernelGraphics.ml's text checks). One call for a whole text, where
; a draw a character (a rectangle clipped, then 16 rows of row_mask) was
; some 13,000 instructions a character.
glyphs:
	ldw	r1, 0(sp)
	sari	r1, r1, 1
	ldw	r2, 4(sp)
	sari	r2, r2, 1
	ldw	r3, 8(sp)
	sari	r3, r3, 1
	andi	r3, r3, 255		; the colour, four times in a word
	shli	r4, r3, 8
	or	r3, r3, r4
	shli	r4, r3, 16
	or	r3, r3, r4
	ldw	r4, 12(sp)
	sari	r4, r4, 1
	ldw	r5, 16(sp)
	ldw	r6, 20(sp)
	sari	r6, r6, 1
	add	r6, r5, r6		; the string's end
glyphs1:				; a character
	bgeu	r5, r6, glyphs7
	ldb	r7, 0(r5)
	sltiu	r8, r7, 128
	bne	r8, zero, glyphs2
	li	r7, 63
glyphs2:
	shli	r7, r7, 3
	add	r7, r4, r7		; its first row in the mask
	mov	r8, r1			; its first row on the image
	li	r9, 16			; rows left
glyphs3:				; a row: its two words
	ldw	r10, 0(r7)
	ldw	r11, 4(r7)
	or	r12, r10, r11
	beq	r12, zero, glyphs6
	beq	r10, zero, glyphs4
	ldw	r12, 0(r8)
	xor	r13, r12, r3
	and	r13, r13, r10
	xor	r12, r12, r13
	stw	r12, 0(r8)
glyphs4:
	beq	r11, zero, glyphs6
	ldw	r12, 4(r8)
	xor	r13, r12, r3
	and	r13, r13, r11
	xor	r12, r12, r13
	stw	r12, 4(r8)
glyphs6:
	add	r8, r8, r2
	addi	r7, r7, 1024
	addi	r9, r9, -1
	bne	r9, zero, glyphs3
	addi	r1, r1, 8
	addi	r5, r5, 1
	j	glyphs1
glyphs7:
	li	r13, 1
	ret

; glyphs_mixed(dst, width, table, font, s, n): glyphs' with a font of
; levels (grey.font), each pixel mixed as row_mix's by the colour's
; table: a row blank in the mask skipped, as glyphs does, else its 8
; bytes one at a time (dst and width need not then be multiples of 4,
; but TinyKernelGraphics.ml's text checks the same as for glyphs)
glyphs_mixed:
	ldw	r1, 0(sp)
	sari	r1, r1, 1
	ldw	r2, 4(sp)
	sari	r2, r2, 1
	ldw	r3, 8(sp)
	sari	r3, r3, 1
	ldw	r4, 12(sp)
	sari	r4, r4, 1
	ldw	r5, 16(sp)
	ldw	r6, 20(sp)
	sari	r6, r6, 1
	add	r6, r5, r6		; the string's end
glyphs_mixed1:				; a character
	bgeu	r5, r6, glyphs_mixed7
	ldb	r7, 0(r5)
	sltiu	r8, r7, 128
	bne	r8, zero, glyphs_mixed2
	li	r7, 63
glyphs_mixed2:
	shli	r7, r7, 3
	add	r7, r4, r7		; its first row in the mask
	mov	r8, r1			; its first row on the image
	li	r9, 16			; rows left
glyphs_mixed3:				; a row
	ldw	r10, 0(r7)
	ldw	r11, 4(r7)
	or	r12, r10, r11
	beq	r12, zero, glyphs_mixed6
	li	r10, 0			; its column
glyphs_mixed4:
	add	r11, r7, r10
	ldb	r12, 0(r11)
	beq	r12, zero, glyphs_mixed5
	shri	r12, r12, 6
	shli	r12, r12, 8
	add	r12, r12, r3
	add	r11, r8, r10
	ldb	r13, 0(r11)
	add	r12, r12, r13
	ldb	r12, 0(r12)
	stb	r12, 0(r11)
glyphs_mixed5:
	addi	r10, r10, 1
	sltiu	r12, r10, 8
	bne	r12, zero, glyphs_mixed4
glyphs_mixed6:
	add	r8, r8, r2
	addi	r7, r7, 1024
	addi	r9, r9, -1
	bne	r9, zero, glyphs_mixed3
	addi	r1, r1, 8
	addi	r5, r5, 1
	j	glyphs_mixed1
glyphs_mixed7:
	li	r13, 1
	ret

; mix_table(at, ink, palette): a colour's mixes (TinyKernelGraphics.ml's
; mix, host/TinyMemory.ml's the same in ML, which says how): 1,024
; bytes at at, byte 256 l + k the colour nearest to l thirds of the ink
; and the rest of colour k, the palette 3 bytes a colour (red, green,
; blue). The mix and the best so far below sp: -4 the best colour, -8
; its distance, -12 -16 -20 the mix's red, green, blue. 512 mixes of 16
; colours looked at, some 400,000 instructions (old: in tiny-ml's ML,
; 3.5 million)
mix_table:
	ldw	r1, 0(sp)
	sari	r1, r1, 1		; at
	ldw	r2, 4(sp)
	sari	r2, r2, 1		; the ink
	ldw	r3, 8(sp)
	sari	r3, r3, 1		; the palette
	li	r4, 0			; the byte: 256 l + k
mix_table1:
	shri	r5, r4, 8		; l
	andi	r6, r4, 255		; k
	bne	r5, zero, mix_table2
	add	r7, r1, r4		; row 0: k
	stb	r6, 0(r7)
	j	mix_table9
mix_table2:
	li	r7, 3
	bne	r5, r7, mix_table3
	add	r7, r1, r4		; row 3: the ink
	stb	r2, 0(r7)
	j	mix_table9
mix_table3:				; the mix: (l ink + (3 - l) k + 1) / 3
	li	r12, 3
	sub	r12, r12, r5		; 3 - l
	add	r10, r2, r2
	add	r10, r10, r2
	add	r10, r10, r3		; the ink's red
	add	r11, r6, r6
	add	r11, r11, r6
	add	r11, r11, r3		; k's
	li	r13, 3
	ldb	r7, 0(r10)
	mul	r7, r7, r5
	ldb	r8, 0(r11)
	mul	r8, r8, r12
	add	r7, r7, r8
	addi	r7, r7, 1
	div	r7, r7, r13
	stw	r7, -12(sp)
	ldb	r7, 1(r10)
	mul	r7, r7, r5
	ldb	r8, 1(r11)
	mul	r8, r8, r12
	add	r7, r7, r8
	addi	r7, r7, 1
	div	r7, r7, r13
	stw	r7, -16(sp)
	ldb	r7, 2(r10)
	mul	r7, r7, r5
	ldb	r8, 2(r11)
	mul	r8, r8, r12
	add	r7, r7, r8
	addi	r7, r7, 1
	div	r7, r7, r13
	stw	r7, -20(sp)
	li	r7, -1
	shri	r7, r7, 1
	stw	r7, -8(sp)		; no best yet
	li	r5, 0			; q = 4 den + v
mix_table4:				; the colour of q nearest the mix: in r6
	shri	r10, r5, 2		; den
	bne	r10, zero, mix_table5
	li	r11, 17			; a grey, 17 q
	mul	r6, r5, r11
	j	mix_table6
mix_table5:
	li	r11, 17
	mul	r11, r5, r11		; top, 17 q
	shri	r12, r11, 1		; half of it, to round
	ldw	r6, -12(sp)		; red: (x den + top / 2) / top, den at most
	mul	r6, r6, r10
	add	r6, r6, r12
	div	r6, r6, r11
	slt	r13, r10, r6
	beq	r13, zero, mix_table51
	mov	r6, r10
mix_table51:
	ldw	r7, -16(sp)		; green
	mul	r7, r7, r10
	add	r7, r7, r12
	div	r7, r7, r11
	slt	r13, r10, r7
	beq	r13, zero, mix_table52
	mov	r7, r10
mix_table52:
	ldw	r8, -20(sp)		; blue
	mul	r8, r8, r10
	add	r8, r8, r12
	div	r8, r8, r11
	slt	r13, r10, r8
	beq	r13, zero, mix_table53
	mov	r8, r10
mix_table53:				; red 64 + v 16 + ((green 4 + blue + v - red) & 15)
	andi	r9, r5, 3
	shli	r7, r7, 2
	add	r7, r7, r8
	add	r7, r7, r9
	sub	r7, r7, r6
	andi	r7, r7, 15
	shli	r9, r9, 4
	add	r7, r7, r9
	shli	r6, r6, 6
	add	r6, r6, r7
mix_table6:				; its distance to the mix
	add	r7, r6, r6
	add	r7, r7, r6
	add	r7, r7, r3
	ldb	r8, 0(r7)
	ldw	r9, -12(sp)
	sub	r8, r8, r9
	mul	r8, r8, r8
	ldb	r9, 1(r7)
	ldw	r10, -16(sp)
	sub	r9, r9, r10
	mul	r9, r9, r9
	add	r8, r8, r9
	ldb	r9, 2(r7)
	ldw	r10, -20(sp)
	sub	r9, r9, r10
	mul	r9, r9, r9
	add	r8, r8, r9
	ldw	r9, -8(sp)
	bge	r8, r9, mix_table7	; the first of the least kept
	stw	r8, -8(sp)
	stw	r6, -4(sp)
mix_table7:
	addi	r5, r5, 1
	sltiu	r9, r5, 16
	bne	r9, zero, mix_table4
	ldw	r6, -4(sp)
	add	r7, r1, r4
	stb	r6, 0(r7)
mix_table9:
	addi	r4, r4, 1
	sltiu	r5, r4, 1024
	bne	r5, zero, mix_table1
	li	r13, 1
	ret
