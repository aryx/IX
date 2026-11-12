; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyMachine.ml)
;
; Linked last by an ML program: its end, where mlsys.c's stack of values
; starts when the program is past 384 KB (tiny-ml, 541 KB). In the
; data, which tiny-ld -n puts after the text: the end of both. (the
; kernel has its own, ../../TinyKernel/kend.s)
	.data
	.align	4
_end:
