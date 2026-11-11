; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyMachine.ml)
;
; Picture.ml on tiny-machine, with no kernel: the machine starts here,
; and TinyKernel/runtime.c's kmain gives the ML program its memory.
; font_bits() is where the font is: TinyKernelGraphics_test.sh puts its bytes
; after this file, at that label, and font_end after them; font_size()
; how many.

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

font_size:
	la	r13, font_end
	la	r12, font
	sub	r13, r13, r12
	shli	r13, r13, 1
	ori	r13, r13, 1
	ret

	.align	4
	.space	16384
stacktop:
