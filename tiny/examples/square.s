; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyMachine.ml)
;
; square(n), hello.c's, by hand: tiny-cc passes the arguments on the
; stack, the first at 0(sp), and takes the answer from r13 (as
; libc/sys.s's calls do). No frame: a leaf, its return address kept
; in lr, which debug's bt reads as the first frame's.
square:
	ldw	r1, 0(sp)
	mul	r13, r1, r1
	ret
