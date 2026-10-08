; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyMachine.ml)
;
; The screen and the mouse: the screen made grey, a blue rectangle on
; it; then, by their interrupts, a square of 16 pixels where the mouse
; is each time it changed (white, or red with a button down) and an m
; written, and the keys typed written back; the input's end halts.
; TinyMachine_test.sh gives it screen.events (-events) and compares the
; console with screen.expected, the screen at the halt (-screen) with
; screen.cksum.

	la	r1, trap
	csrw	tvec, r1
	li	r1, 0xf00000		; the screen: 640 by 480 bytes
	li	r2, 307200
	li	r3, 0xaa		; grey
grey:
	stb	r3, 0(r1)
	addi	r1, r1, 1
	addi	r2, r2, -1
	bne	r2, r0, grey
	li	r4, 100			; rows 100 to 199, columns 200 to 399
row:
	li	r5, 640
	mul	r1, r4, r5
	li	r5, 0xf000c8		; the screen's column 200
	add	r1, r1, r5
	li	r2, 200
	li	r3, 0x36		; blue
column:
	stb	r3, 0(r1)
	addi	r1, r1, 1
	addi	r2, r2, -1
	bne	r2, r0, column
	addi	r4, r4, 1
	li	r5, 200
	bne	r4, r5, row
	li	r1, 10			; the mouse's interrupt and the console's
	csrw	ie, r1
	li	r1, 3			; supervisor, interrupts on
	csrw	status, r1
wait:
	j	wait

trap:
	csrr	r7, tval		; the sources
	andi	r1, r7, 8
	beq	r1, r0, keys
	ldw	r1, -4(r0)		; the mouse, read: its interrupt is over
	andi	r2, r1, 0xfff		; x
	shri	r3, r1, 12
	andi	r3, r3, 0xfff		; y
	shri	r4, r1, 24		; the buttons
	li	r5, 255			; white
	beq	r4, r0, square
	li	r5, 0xf0		; red
square:
	li	r6, 640
	mul	r3, r3, r6
	add	r3, r3, r2
	li	r6, 0xf00000
	add	r3, r3, r6
	li	r8, 16
square_row:
	li	r9, 16
square_column:
	stb	r5, 0(r3)
	addi	r3, r3, 1
	addi	r9, r9, -1
	bne	r9, r0, square_column
	addi	r3, r3, 624
	addi	r8, r8, -1
	bne	r8, r0, square_row
	li	r5, 109			; m
	stb	r5, -16(r0)
keys:
	andi	r1, r7, 2
	beq	r1, r0, back
key:
	ldw	r3, -8(r0)
	li	r4, -1			; none now
	beq	r3, r4, back
	li	r4, -2			; the end
	beq	r3, r4, end
	stb	r3, -16(r0)
	j	key
back:
	eret
end:
	stw	r0, -12(r0)
