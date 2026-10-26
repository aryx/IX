; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyMachine.ml)
;
; Linked last: the image's end. The kernel's, where the files it
; carries start (the Makefile appends them; TinyKernel.ml's load reads
; them from here); an ML program's, where mlsys.c's stack of values
; starts when the program is past 384 KB (tiny-ml, 541 KB). In the
; data, which tiny-linker -n puts after the text: the end of both.
	.data
	.align	4
_end:
