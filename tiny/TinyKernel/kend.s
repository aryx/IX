; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyMachine.ml)
;
; Linked last: the kernel's end, where the files it carries start (the
; Buildfile's boot.img appends them; TinyKernel.ml's load reads them
; from here). (an ML program has its own,
; ../TinyLibSystem/tinykernel/end.s)
	.data
	.align	4
_end:
