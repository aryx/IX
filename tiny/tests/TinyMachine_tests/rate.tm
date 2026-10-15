; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyMachine.ml)
;
; The rate register: the machine's speed in millions of instructions
; per second, printed as two digits. TinyMachine_test.sh runs it with
; -rate 16 and compares with rate.expected; without -rate it would
; print 08, the default.

	csrr	r1, rate
	li	r2, 1000000
	div	r1, r1, r2		; the millions
	li	r2, 10
	div	r3, r1, r2		; the tens
	rem	r4, r1, r2		; the units
	addi	r3, r3, 48
	stb	r3, -16(r0)
	addi	r4, r4, 48
	stb	r4, -16(r0)
	li	r5, 10
	stb	r5, -16(r0)
	stw	r0, -12(r0)		; halt
