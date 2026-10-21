; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyMachine.ml)
;
; TinyKernel.ml's system calls for C: the arguments from tiny-c's places
; to r1-r3, sys n, the answer from r1 (write is start.tm's, sys 1; the
; numbers are TinyKernel.ml's syscall's).

exit:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	0
	mov	r13, r1
	ret

read:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	2
	mov	r13, r1
	ret

fork:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	3
	mov	r13, r1
	ret

exec:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	4
	mov	r13, r1
	ret

wait:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	5
	mov	r13, r1
	ret

getpid:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	6
	mov	r13, r1
	ret

open:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	7
	mov	r13, r1
	ret

close:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	8
	mov	r13, r1
	ret

pipe:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	9
	mov	r13, r1
	ret

dup:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	10
	mov	r13, r1
	ret

mkdir:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	11
	mov	r13, r1
	ret

unlink:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	12
	mov	r13, r1
	ret

chdir:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	13
	mov	r13, r1
	ret

kill:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	14
	mov	r13, r1
	ret

ready:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	15
	mov	r13, r1
	ret

ticks:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	16
	mov	r13, r1
	ret

box:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	17
	mov	r13, r1
	ret

dial:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	18
	mov	r13, r1
	ret

listen:
	ldw	r1, 0(sp)
	sys	19
	mov	r13, r1
	ret

getcwd:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	20
	mov	r13, r1
	ret

link:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	21
	mov	r13, r1
	ret

rawcons:
	ldw	r1, 0(sp)
	sys	22
	mov	r13, r1
	ret

trace:
	ldw	r1, 0(sp)
	sys	23
	mov	r13, r1
	ret

seek:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	ldw	r3, 8(sp)
	sys	24
	mov	r13, r1
	ret

time:
	sys	25
	mov	r13, r1
	ret

seed:
	sys	27
	mov	r13, r1
	ret

stat:
	ldw	r1, 0(sp)
	ldw	r2, 4(sp)
	sys	26
	mov	r13, r1
	ret
