; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyMachine.ml)
;
; TinyKernel.ml's assembly: what ML cannot say. Linked first (the
; machine starts at 0). The functions follow tiny-c -tm's convention
; (the arguments at 0(sp), 4(sp)..., the result in r13, every register
; but sp the callee's), so the ML code calls them as externals, and
; the values they take and give are ML's: an integer n is 2n+1.
;
; The kernel is a loop, and k_run is how it runs a process: it saves
; the kernel's sp and link, loads the process's registers from its
; frame, and erets; the process's next trap comes back here, saves its
; registers in the frame, and returns from k_run, the trap's cause its
; result. So the kernel calls a process as a function that returns at
; its next trap (a hypervisor's KVM_RUN): no trap handler of ML, no
; kernel stack per process.

_entry:
	la	sp, kstacktop
	call	kmain			; runtime.c: the heap, then the ML toplevel
spin:
	j	spin

; int k_run(int frame): the process of that frame run (its window set
; by k_window) until its next trap; the trap's cause. frame 0: the
; kernel waits for an interrupt instead, with them on (nothing to run)
k_run:
	ldw	r1, 0(sp)
	sari	r1, r1, 1
	la	r2, ksave
	stw	sp, 0(r2)
	stw	lr, 4(r2)
	beq	r1, zero, k_idle
	csrw	scratch, r1		; while in user mode, its frame
	ldw	r2, 64(r1)
	csrw	epc, r2
	li	r2, 25			; supervisor; after eret user, interrupts on, relocating
	csrw	status, r2
	ldw	r2, 8(r1)
	ldw	r3, 12(r1)
	ldw	r4, 16(r1)
	ldw	r5, 20(r1)
	ldw	r6, 24(r1)
	ldw	r7, 28(r1)
	ldw	r8, 32(r1)
	ldw	r9, 36(r1)
	ldw	r10, 40(r1)
	ldw	r11, 44(r1)
	ldw	r12, 48(r1)
	ldw	r13, 52(r1)
	ldw	r14, 56(r1)
	ldw	r15, 60(r1)
	ldw	r1, 4(r1)
	eret
k_idle:
	csrw	scratch, zero
	li	r1, 3			; supervisor, interrupts on
	csrw	status, r1
k_idle1:
	j	k_idle1

; Every trap. From user mode scratch is the process's frame (r1 swapped
; with it frees a register), from the idle loop 0; either way back to
; k_run's caller, interrupts off, with the cause.
trapvec:
	csrrw	r1, scratch, r1
	beq	r1, zero, k_back
	stw	r2, 8(r1)
	stw	r3, 12(r1)
	stw	r4, 16(r1)
	stw	r5, 20(r1)
	stw	r6, 24(r1)
	stw	r7, 28(r1)
	stw	r8, 32(r1)
	stw	r9, 36(r1)
	stw	r10, 40(r1)
	stw	r11, 44(r1)
	stw	r12, 48(r1)
	stw	r13, 52(r1)
	stw	r14, 56(r1)
	stw	r15, 60(r1)
	csrr	r2, scratch
	stw	r2, 4(r1)
	csrr	r2, epc
	stw	r2, 64(r1)
k_back:
	csrw	scratch, zero
	li	r1, 1			; supervisor, interrupts off
	csrw	status, r1
	la	r2, ksave
	ldw	sp, 0(r2)
	ldw	lr, 4(r2)
	csrr	r13, cause
	shli	r13, r13, 1
	ori	r13, r13, 1
	ret

; the trap's value (a system call's number, a fault's address, the
; interrupts' sources)
k_tval:
	csrr	r13, tval
	shli	r13, r13, 1
	ori	r13, r13, 1
	ret

; the traps to trapvec, the timer's, the console's and the mouse's
; interrupts on
k_init:
	la	r1, trapvec
	csrw	tvec, r1
	li	r1, 11			; the timer, the console, the mouse
	csrw	ie, r1
	li	r13, 1
	ret

; the timer's next interrupt, n instructions from now (in 32 bits: the
; time outgrows ML's 31)
k_timer:
	ldw	r1, 0(sp)
	sari	r1, r1, 1
	csrr	r2, time
	add	r2, r2, r1
	csrw	timecmp, r2
	li	r13, 1
	ret

; the machine's time, its instructions so far: the low 30 bits (an ML
; integer; the kernel counts its ticks by how much it moved)
k_clock:
	csrr	r13, time
	shli	r13, r13, 2
	shri	r13, r13, 1
	ori	r13, r13, 1
	ret

; the window of the next process: from base, size bytes
k_window:
	ldw	r1, 0(sp)
	sari	r1, r1, 1
	ldw	r2, 4(sp)
	sari	r2, r2, 1
	csrw	base, r1
	csrw	bound, r2
	li	r13, 1
	ret

; k_copy(dst, src, n): n bytes, a multiple of 4, a word at a time (a
; partition copied at fork is a MB: the kernel's hottest loop)
k_copy:
	ldw	r1, 0(sp)
	sari	r1, r1, 1
	ldw	r2, 4(sp)
	sari	r2, r2, 1
	ldw	r3, 8(sp)
	sari	r3, r3, 1
	add	r3, r1, r3
k_copy1:
	bgeu	r1, r3, k_copy2
	ldw	r4, 0(r2)
	stw	r4, 0(r1)
	addi	r1, r1, 4
	addi	r2, r2, 4
	j	k_copy1
k_copy2:
	li	r13, 1
	ret

; k_zero(a, n): n bytes, a multiple of 4
k_zero:
	ldw	r1, 0(sp)
	sari	r1, r1, 1
	ldw	r2, 4(sp)
	sari	r2, r2, 1
	add	r2, r1, r2
k_zero1:
	bgeu	r1, r2, k_zero2
	stw	zero, 0(r1)
	addi	r1, r1, 4
	j	k_zero1
k_zero2:
	li	r13, 1
	ret

; the image's end, where the files it carries start (end.tm, last)
k_end:
	la	r13, _end
	shli	r13, r13, 1
	ori	r13, r13, 1
	ret

ksave:
	.word	0, 0
	.align	4
	.space	16384
kstacktop:
