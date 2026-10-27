; Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyMachine.ml)
;
; TinyKernel.ml's assembly: what ML cannot say. Linked first (the
; machine starts at 0). The functions follow tiny-c's convention
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
;
; With several cores (tiny-machine -cores n, plan_tiny_multicore.md)
; the kernel is core 0's alone; the others start here too and go to
; slave, a loop that runs no ML: the process core 0 puts in its
; mailbox run until its trap, the trap posted back.

_entry:
	csrr	r1, core
	bne	r1, zero, slave
	la	sp, kstacktop
	call	kmain			; runtime.c: the heap, then the ML toplevel
spin:
	j	spin

; int k_step(int frame): k_run for one instruction (a debugger's step):
; the timer's interrupt comes after the process's first instruction.
; The machine looks at the timer before each instruction, when the
; time has moved: from this csrr to eret are 34 instructions (old: 31,
; before the split's three in k_enter), so the process's first is at
; the time read plus 34 and runs, and the timer at plus 35 interrupts
; before its second. (A trap of that first instruction comes first: a
; call, a fault.)
k_step:
	csrr	r2, time
	addi	r2, r2, 35
	csrw	timecmp, r2
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
; the process of frame r1 entered (a slave's too)
k_enter:
	csrw	scratch, r1		; while in user mode, its frame
	ldw	r2, 64(r1)
	csrw	epc, r2
	csrr	r3, tbound		; (no branch: k_step counts these)
	sltu	r3, zero, r3
	shli	r3, r3, 5
	ori	r2, r3, 25		; supervisor; after eret user, interrupts on, relocating;
	csrw	status, r2		; and split (32) with a text (TinyKernelMemory's segments)
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
	wfi				; asleep until an interrupt (TinyMachineDevices's
	j	k_idle1			; wfi: old, a jump to itself, a host's work)

; Every trap. From user mode scratch is the process's frame (r1 swapped
; with it frees a register), from the idle loop 0; either way back to
; k_run's caller, interrupts off, with the cause.
trapvec:
	csrrw	r1, scratch, r1
	beq	r1, zero, k_waited
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
	csrr	r2, core
	bne	r2, zero, slave_post
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

k_waited:
	csrr	r1, core
	beq	r1, zero, k_back
	j	slave_take

; A slave (core k > 0). Its mailbox, at 0xb41000 + 64k (TinyKernel.ml's
; mailbox): the frame of the process to run (0: none), the window's
; base and size, the slice (instructions until its timer), then the
; trap's cause and value, posted; then the text's window, its base and
; size, and satp (TinyKernelMemory's mem_post). It waits for the cores'
; interrupt (core 0's word at -64(r0)): a frame there, it runs it; a trap of the
; process saved in the frame (trapvec), the cause and the value
; written, core 0's interrupt raised, and it waits again. Its timer
; is on only while a process runs.
slave:
	la	r1, trapvec
	csrw	tvec, r1
	li	r1, 33			; its timer, the cores' interrupt
	csrw	ie, r1
slave_wait:
	li	r1, -1
	csrw	timecmp, r1
	csrw	scratch, zero
	li	r1, 3			; supervisor, interrupts on
	csrw	status, r1
slave_spin:
	wfi
	j	slave_spin
slave_take:
	ldw	r1, -64(r0)		; the senders, cleared
	csrr	r3, core
	shli	r3, r3, 6
	li	r2, 0xb41000
	add	r3, r3, r2
	ldw	r1, 0(r3)
	beq	r1, zero, slave_wait	; nothing given (or a timer's)
	stw	zero, 0(r3)
	ldw	r2, 4(r3)
	csrw	base, r2
	ldw	r2, 8(r3)
	csrw	bound, r2
	ldw	r2, 24(r3)
	csrw	tbase, r2
	ldw	r2, 28(r3)
	csrw	tbound, r2
	ldw	r2, 32(r3)
	csrw	satp, r2
	ldw	r2, 12(r3)
	csrr	r4, time
	add	r2, r2, r4
	csrw	timecmp, r2
	j	k_enter
slave_post:
	shli	r3, r2, 6
	li	r2, 0xb41000
	add	r3, r3, r2
	csrr	r2, cause
	stw	r2, 16(r3)
	csrr	r2, tval
	stw	r2, 20(r3)
	stw	zero, -64(r0)		; core 0's interrupt
	j	slave_wait

; the trap's value (a system call's number, a fault's address, the
; interrupts' sources)
k_tval:
	csrr	r13, tval
	shli	r13, r13, 1
	ori	r13, r13, 1
	ret

; the traps to trapvec, the timer's, the console's, the mouse's and
; the network's interrupts on
k_init:
	la	r1, trapvec
	csrw	tvec, r1
	li	r1, 27			; the timer, the console, the mouse, the network
	csrw	ie, r1
	li	r13, 1
	ret

; the timer's next interrupt, n instructions from now (in 32 bits: the
; time outgrows ML's 31)
; k_ie(sources): the interrupts the machine may take from now, by
; their sources' bits (27: all five but the disk's)
k_ie:
	ldw	r1, 0(sp)
	sari	r1, r1, 1
	csrw	ie, r1
	li	r13, 1
	ret

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

; the number of cores (an ML integer)
k_cores:
	csrr	r13, cores
	shli	r13, r13, 1
	ori	r13, r13, 1
	ret

; the machine's speed, in instructions per second (an ML integer)
k_rate:
	csrr	r13, rate
	shli	r13, r13, 1
	ori	r13, r13, 1
	ret

; the windows of the next process: its data's, from base, size bytes;
; its text's, from tbase, tsize bytes (0 and 0: none, the data's alone,
; a partition); and satp (0: no pages; its user-only bit with them)
k_window:
	ldw	r1, 0(sp)
	sari	r1, r1, 1
	ldw	r2, 4(sp)
	sari	r2, r2, 1
	csrw	base, r1
	csrw	bound, r2
	ldw	r1, 8(sp)
	sari	r1, r1, 1
	ldw	r2, 12(sp)
	sari	r2, r2, 1
	csrw	tbase, r1
	csrw	tbound, r2
	ldw	r1, 16(sp)
	sari	r1, r1, 1
	csrw	satp, r1
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
