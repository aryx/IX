; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyMachine.ml)
;
; Picture.ml on tiny-machine, with no kernel: the machine starts here,
; and TinyKernel/runtime.c's kmain gives the ML program its memory.
; font_bits() is where the font is: TinyGraphics_test.sh puts its bytes
; after this file, at that label.

_entry:
	la	sp, stacktop
	call	kmain
spin:
	j	spin

font_bits:
	la	r13, font
	shli	r13, r13, 1
	ori	r13, r13, 1
	ret

	.align	4
	.space	16384
stacktop:
