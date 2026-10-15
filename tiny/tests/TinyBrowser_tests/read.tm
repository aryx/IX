; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
;
; int read(int fd, void *buf, int n) is tiny-cpu's sys 2.
; TinyCRuntime/start.tm does not have it, since its programs only write.
read:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	2
	mov	r13, r1
	ret

; void exit(int status), which the runtime calls
exit:
	ldw	r1, 0(sp)
	sys	0
