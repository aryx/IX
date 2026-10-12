@ Claude Code
@ Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
@
@ mini-xv6 (plan_kernel.md), what OCaml cannot say: the boot (the MMU
@ on), the trap entries (a system call, an IRQ, an abort, from user
@ mode: the user's registers into the running process's trap frame,
@ then the kernel on the process's kernel stack), the way back to user
@ mode, the switch between kernel stacks. Built up in kernels/steps/step1-5/.
@
@ The MMU on. xv6 arm-pi1's layout:
@ the user's programs from 0 to 1GB, the kernel at KERNBASE
@ (0x80000000: the RAM seen from there), the devices at 0xFE000000, the
@ vectors at 0xFFFF0000 (high vectors: address 0 is the user's).
@
@ The boot runs at the physical addresses (loaded at 0x8000, linked at
@ KERNBASE + 0x8000: only relative branches, and each linked address
@ less KERNBASE), fills the kernel's page table (1MB sections, ARMv6's
@ format), turns the MMU on and jumps to the linked addresses. Then
@ step 3's world: stacks, the VFP, kmain; the trap entries, now with a
@ data and a prefetch abort from user mode going to the kernel too.
@
@ The translation (set up here, used by machine.c): TTBR1 the kernel's
@ table (16KB, 4096 entries, one a MB); TTBCR N = 2 once the kernel
@ runs, so that addresses below 1GB go through TTBR0, a process's table
@ (4KB, 1024 entries), the rest through TTBR1.

	.equ	KERNBASE, 0x80000000
	.ifndef PI2
	.equ	RAM_MB, 512			@ the RAM mapped at KERNBASE: all of it (the GPU's part: the framebuffer QEMU gives)
	.endif
	.ifdef PI2
	@ (and S, bit 16: memory several cores share. The caches of the
	@ cores are kept the same for it, and the lock's pair of
	@ instructions, ldrex and strex, sees another core's write only
	@ there: for memory not said shared the architecture asks for a
	@ core's own monitor only.)
	.equ	SECTION, 0x1040e
	.else
	.equ	SECTION, 0x40e			@ a section, AP 01 (kernel read-write), domain 0; C and B: cached, once the caches are on (caches_enable)
	.endif
	.equ	DEVICE, 0x412			@ the same, XN, neither C nor B: the devices'
	.equ	UNCACHED, 0x1412		@ the same, TEX 001: memory that is not cached (machine.c says whose)

@ The Pi 2 (--defsym PI2=1; docs/plans/plan_pi2.md): the same kernel
@ on a Cortex-A7 or A53. What differs is here and marked: the mode the
@ firmware starts the kernel in, the devices' physical address, the
@ cycle counter, and the caches' operations on a whole cache, ARMv7's.
@ Its memory is 1 GB, the devices in its last 16 MB: the RAM at
@ KERNBASE reaches 0xBF000000, past where the Pi 1 has its second
@ view of it, not cached. That view is the Pi 2's at 0x40000000, the
@ GB between the user's addresses and KERNBASE, which nothing used.
	.ifdef PI2
	.equ	IO_MB, 0x3f0			@ the devices' first MB: 0x3F000000
	.equ	RAM_MB, 0x3f0			@ the RAM below them: 1008 MB
	.equ	UNCACHED_L1, 0x1000		@ entry 0x400: the RAM again at 0x40000000
	.else
	.equ	IO_MB, 0x200			@ 0x20000000
	.equ	UNCACHED_L1, 0x2800		@ entry 0xA00: at 0xA0000000
	.endif

	.section .text.boot
	.global _start
_start:
	.ifdef PI2
	@ The firmware (and QEMU's -kernel) starts a Pi 2's kernel in the
	@ hypervisor's mode, which has its own registers for the tables
	@ and its own vectors: down to SVC, interrupts masked, as a Pi 1
	@ is started. (Not in that mode: an emulator that starts in SVC.)
	mrs	r0, cpsr
	and	r1, r0, #0x1f
	cmp	r1, #0x1a
	bne	0f
	bic	r0, r0, #0x1f
	orr	r0, r0, #0xd3			@ SVC, IRQs and FIQs masked
	orr	r0, r0, #0x100			@ and the asynchronous aborts
	msr	spsr_cxsf, r0
	adr	lr, 0f
	.word	0xe12ef30e			@ msr elr_hyp, lr
	.word	0xe160006e			@ eret
0:
	@ The other cores (MPIDR's low bits their number) come here too:
	@ the firmware keeps them in a loop of its own until the first
	@ writes this address to their mailbox (machine.c's cores_start);
	@ an emulator given the image as a Pi 1's is (QEMU's -device
	@ loader) starts the four of them towards it at once. Each waits
	@ until the first core names it (core_go), all of the kernel's
	@ tables and data being the first core's to set up.
	@ (old: they waited here for ever, before the mode was left)
	mrc	p15, 0, r5, c0, c0, 5
	ands	r5, r5, #3
	beq	8f
	@ (core_stage: how far this core came, for the first to tell if
	@ it does not come up; its caches are off, these go to memory)
	ldr	r3, =core_stage
	sub	r3, r3, #KERNBASE
	add	r3, r3, r5, lsl #2
	mov	r2, #1
	str	r2, [r3]
	ldr	r1, =core_go
	sub	r1, r1, #KERNBASE
9:	ldr	r2, [r1]
	cmp	r2, r5
	beq	7f
	wfe
	b	9b
	@ the first core's table, as it had it when its MMU went on (the
	@ first MB as itself is still in it)
7:	mov	r2, #2
	str	r2, [r3]
	ldr	r4, =kpgdir
	sub	r4, r4, #KERNBASE
	mov	r0, #1
	mcr	p15, 0, r0, c3, c0, 0		@ DACR
	mcr	p15, 0, r4, c2, c0, 0		@ TTBR0
	mcr	p15, 0, r4, c2, c0, 1		@ TTBR1
	mov	r0, #0
	mcr	p15, 0, r0, c2, c0, 2		@ TTBCR N = 0 for now
	mcr	p15, 0, r0, c8, c7, 0
	mrc	p15, 0, r0, c1, c0, 0
	orr	r0, r0, #1
	orr	r0, r0, #(1 << 13)
	orr	r0, r0, #(1 << 23)
	bic	r0, r0, #(3 << 28)
	mcr	p15, 0, r0, c1, c0, 0
	ldr	pc, =core_high
8:
	.endif
	@ the physical address of the kernel's table (kpgdir, in the bss)
	ldr	r4, =kpgdir
	sub	r4, r4, #KERNBASE
	@ the bss cleared, at its physical addresses
	ldr	r0, =__bss_start
	ldr	r1, =__bss_end
	sub	r0, r0, #KERNBASE
	sub	r1, r1, #KERNBASE
	mov	r2, #0
1:	cmp	r0, r1
	strlo	r2, [r0], #4
	blo	1b
	@ the RAM at KERNBASE: entries 0x800.., MB i -> i
	mov	r0, #0
	ldr	r3, =SECTION
2:	orr	r1, r3, r0, lsl #20
	add	r2, r4, #0x2000			@ entry 0x800
	str	r1, [r2, r0, lsl #2]
	add	r0, r0, #1
	cmp	r0, #RAM_MB
	blo	2b
	@ the RAM again at 0xA0000000, not cached: entries 0xA00.. (UNCACHED_L1)
	mov	r0, #0
	ldr	r3, =UNCACHED
4:	orr	r1, r3, r0, lsl #20
	add	r2, r4, #UNCACHED_L1
	str	r1, [r2, r0, lsl #2]
	add	r0, r0, #1
	cmp	r0, #RAM_MB
	blo	4b
	@ the devices at 0xFE000000: 16 MB from 0x20000000 (IO_MB)
	mov	r0, #0
	ldr	r3, =DEVICE
3:	add	r1, r0, #IO_MB
	orr	r1, r3, r1, lsl #20
	add	r2, r4, #0x3f80			@ entry 0xFE0
	str	r1, [r2, r0, lsl #2]
	add	r0, r0, #1
	cmp	r0, #16
	blo	3b
	.ifdef PI2
	@ the cores' controller (0x40000000: their mailboxes, their
	@ timers' routing) at 0xFF000000: entry 0xFF0
	ldr	r1, =(0x40000000 | DEVICE)
	add	r2, r4, #0x3000
	str	r1, [r2, #0xfc0]
	.endif
	@ the first MB mapped as itself too, while the MMU goes on here
	ldr	r1, =SECTION
	str	r1, [r4]
	@ the vectors: their page, and a second-level table mapping it at
	@ 0xFFFF0000 (entry 0xFFF: a coarse table, its entry 0xF0 the page)
	ldr	r5, =vectors_page
	sub	r5, r5, #KERNBASE
	ldr	r0, =vectors
	sub	r0, r0, #KERNBASE
	mov	r1, r5
	ldmia	r0!, {r2, r3, r6, r7, r8, r9, r10, r11}
	stmia	r1!, {r2, r3, r6, r7, r8, r9, r10, r11}
	ldmia	r0!, {r2, r3, r6, r7, r8, r9, r10, r11}
	stmia	r1!, {r2, r3, r6, r7, r8, r9, r10, r11}
	ldr	r6, =vectors_l2
	sub	r6, r6, #KERNBASE
	orr	r1, r5, #0x1e			@ a small page, AP 01, XN clear, C and B
	str	r1, [r6, #0xf0 * 4]
	orr	r1, r6, #1			@ a coarse table, domain 0
	add	r2, r4, #0x3000
	str	r1, [r2, #0xffc]		@ entry 0xFFF
	@ domain 0 a client (permissions checked); both tables the kernel's
	mov	r0, #1
	mcr	p15, 0, r0, c3, c0, 0		@ DACR
	mcr	p15, 0, r4, c2, c0, 0		@ TTBR0
	mcr	p15, 0, r4, c2, c0, 1		@ TTBR1
	mov	r0, #0
	mcr	p15, 0, r0, c2, c0, 2		@ TTBCR N = 0 for now
	mcr	p15, 0, r0, c8, c7, 0		@ the TLB invalidated
	@ on: the MMU (M), ARMv6's format (XP), the high vectors (V)
	mrc	p15, 0, r0, c1, c0, 0
	orr	r0, r0, #1
	orr	r0, r0, #(1 << 13)
	orr	r0, r0, #(1 << 23)
	.ifdef PI2
	@ (and the tables' bits meant as ARMv6's: TRE and AFE, bits 28
	@ and 29, clear, whatever the firmware left)
	bic	r0, r0, #(3 << 28)
	.endif
	mcr	p15, 0, r0, c1, c0, 0
	@ to the linked addresses
	ldr	pc, =high

	.text
high:
	@ a stack for each mode, then SVC's
	cps	#0x12
	ldr	sp, =irq_stack_top
	cps	#0x1b
	ldr	sp, =und_stack_top
	cps	#0x17
	ldr	sp, =abt_stack_top
	cps	#0x13
	ldr	sp, =stack_top
	@ the first MB no longer mapped as itself: the user's from now on.
	@ TTBCR first (N = 2: only below 1GB through TTBR0), then TTBR0 an
	@ empty table until a process runs. The other order leaves, for a
	@ few instructions, every address -- the kernel's too -- going
	@ through the empty table: QEMU let it pass (its TLB still held the
	@ kernel's translations), mini-qemu did not (it empties its TLB on
	@ every TTBR write), and hardware need not either.
	mov	r0, #2
	mcr	p15, 0, r0, c2, c0, 2		@ TTBCR N = 2
	ldr	r0, =empty_pgdir
	sub	r0, r0, #KERNBASE
	mcr	p15, 0, r0, c2, c0, 0		@ TTBR0
	mov	r0, #0
	mcr	p15, 0, r0, c8, c7, 0
	@ the VFP on
	mrc	p15, 0, r0, c1, c0, 2
	orr	r0, r0, #0xf00000
	mcr	p15, 0, r0, c1, c0, 2
	mov	r0, #0x40000000
	vmsr	fpexc, r0
	bl	kmain
halt:
	wfi
	b	halt

	.ifdef PI2
@ Another core (r5 its number), at the linked addresses: its own
@ stacks (core_stacks: 128 KB a core, the three modes' 16 KB each at
@ the bottom, SVC's the rest), then as the first core above; and
@ machine.c's core_main, which does not return.
core_high:
	ldr	r3, =core_stage
	mov	r2, #3
	str	r2, [r3, r5, lsl #2]
	sub	r1, r5, #1
	ldr	r0, =core_stacks
	add	r0, r0, r1, lsl #17
	cps	#0x12
	add	sp, r0, #0x4000
	cps	#0x1b
	add	sp, r0, #0x8000
	cps	#0x17
	add	sp, r0, #0xc000
	cps	#0x13
	add	sp, r0, #0x20000
	mov	r0, #2
	mcr	p15, 0, r0, c2, c0, 2		@ TTBCR N = 2
	ldr	r0, =empty_pgdir
	sub	r0, r0, #KERNBASE
	mcr	p15, 0, r0, c2, c0, 0		@ TTBR0
	mov	r0, #0
	mcr	p15, 0, r0, c8, c7, 0
	mrc	p15, 0, r0, c1, c0, 2
	orr	r0, r0, #0xf00000
	mcr	p15, 0, r0, c1, c0, 2
	mov	r0, #0x40000000
	vmsr	fpexc, r0
	mov	r0, r5
	bl	core_main
1:	wfi
	b	1b
@ the cores waiting in the start are told to look at core_go again
	.global core_wake
core_wake:
	sev
	bx	lr
@ The kernel's lock (runtime.c says where it is taken): a word, 1 when
@ a core has it, taken by ARMv6K's pair, a load that marks the word
@ and a store that fails if another core wrote it since. A core that
@ waits turns here, its interrupts masked. The first core has it from
@ the start.
	.global klock_take
klock_take:
	ldr	r1, =klock
	mov	r2, #1
1:	ldrex	r0, [r1]
	cmp	r0, #0
	bne	1b
	strex	r0, r2, [r1]
	cmp	r0, #0
	bne	1b
	mcr	p15, 0, r0, c7, c10, 5		@ (a barrier: what the last holder wrote is seen)
	bx	lr
	.global klock_give
klock_give:
	ldr	r1, =klock
	mov	r0, #0
	mcr	p15, 0, r0, c7, c10, 5
	str	r0, [r1]
	mcr	p15, 0, r0, c7, c10, 4
	bx	lr
	.endif

vectors:
	ldr	pc, [pc, #24]		@ 0x00 reset
	ldr	pc, [pc, #24]		@ 0x04 undefined
	ldr	pc, [pc, #24]		@ 0x08 svc
	ldr	pc, [pc, #24]		@ 0x0c prefetch abort
	ldr	pc, [pc, #24]		@ 0x10 data abort
	ldr	pc, [pc, #24]		@ 0x14 (unused)
	ldr	pc, [pc, #24]		@ 0x18 IRQ
	ldr	pc, [pc, #24]		@ 0x1c FIQ
	.word	_start, undefined_entry, svc_entry, prefetch_entry, data_entry, _start, irq_entry, _start

@ from user mode: the user's registers into the trap frame (the running
@ process's, cur_tf), r0 = what happened, then the kernel. A system
@ call returns to the next instruction (lr); an abort's lr is 8 after
@ the faulting instruction (data) or 4 (prefetch): kept as it is, the
@ process is killed.
@ (The Pi 2, several cores: the trap frame is the one of the process
@ this core runs, cur_tfs by the core's number, MPIDR's low bits; and
@ once the user is saved the core takes the kernel's lock,
@ kernel_enter, which user_return gives back: runtime.c.)
	.macro	save_user kind
	.ifdef PI2
	stmfd	sp!, {r0, r1}		@ r0 and r1 aside
	mrc	p15, 0, r0, c0, c0, 5
	and	r0, r0, #3
	ldr	r1, =cur_tfs
	ldr	r0, [r1, r0, lsl #2]
	ldr	r1, [sp, #4]
	.else
	str	r0, [sp, #-4]!		@ r0 aside
	ldr	r0, =cur_tf
	ldr	r0, [r0]
	.endif
	stmib	r0, {r1-r12}		@ words 1-12
	add	r0, r0, #52
	stmia	r0, {sp, lr}^		@ 13, 14: the user's sp and lr
	nop
	sub	r0, r0, #52
	str	lr, [r0, #60]		@ 15: where to go back
	mrs	r1, spsr
	str	r1, [r0, #64]		@ 16: the user's CPSR
	.ifdef PI2
	ldr	r1, [sp], #8
	.else
	ldr	r1, [sp], #4
	.endif
	str	r1, [r0]		@ 0: the user's r0
	@ the user's floats: d0-d7, which a function may change (the
	@ kernel's own, another process's, before this one goes on: an
	@ interrupt comes in the middle of a computation), and the FPSCR.
	@ d8-d15 are kept by whoever uses them, and by swtch.
	vmrs	r1, fpscr
	str	r1, [r0, #68]		@ 17
	add	r1, r0, #72
	vstmia	r1, {d0-d7}		@ 18-33
	.endm

@ (in SVC mode, on the process's kernel stack)
	.macro	enter
	.ifdef PI2
	bl	kernel_enter
	.endif
	.endm

svc_entry:
	save_user
	enter
	bl	trap

	.global user_return
user_return:
	.ifdef PI2
	bl	kernel_leave
	mrc	p15, 0, r0, c0, c0, 5
	and	r0, r0, #3
	ldr	r1, =cur_tfs
	ldr	r0, [r1, r0, lsl #2]
	.else
	ldr	r0, =cur_tf
	ldr	r0, [r0]
	.endif
	ldr	r1, [r0, #68]
	vmsr	fpscr, r1
	add	r1, r0, #72
	vldmia	r1, {d0-d7}
	ldr	r1, [r0, #64]
	msr	spsr_cxsf, r1
	ldr	lr, [r0, #60]
	add	r1, r0, #52
	ldmia	r1, {sp, lr}^
	nop
	ldmia	r0, {r0-r12}
	movs	pc, lr

@ an IRQ: from user mode (the only mode with IRQs on); lr 4 after the
@ instruction to resume
irq_entry:
	sub	lr, lr, #4
	save_user
	cps	#0x13
	enter
	bl	irq
	b	user_return

@ an abort: from user mode, the process's (in abort mode here: the user
@ saved, then to SVC mode and the process's kernel stack); from the
@ kernel, a kernel's fault: the machine stops
@ (old: sp was the scratch, and set to abt_stack_top again after it;
@ r0, put aside on the mode's stack, now: each core has its own
@ stacks, set once at its start)
	.macro	from_user
	str	r0, [sp, #-4]!
	mrs	r0, spsr
	and	r0, r0, #0x1f
	cmp	r0, #0x10
	ldr	r0, [sp], #4
	.endm

data_entry:
	from_user
	bne	kernel_data
	save_user
	cps	#0x13
	enter
	mov	r0, #3
	bl	user_abort
	b	user_return
@ claude: a probe (machine.c's io_probe: probing[0] set) is the kernel
@ asking whether a device is there: its fault is the answer (probing[1]
@ takes the link, not 0) and the kernel goes on after the instruction
@ that faulted (the link is 8 past it). QEMU's raspi has no PWM, its
@ registers no memory at all, and a game's first sound halted the
@ machine. r0 is the scratch, as above; the flags are the SPSR's again
@ at the return.
kernel_data:
	str	r0, [sp, #-4]!
	ldr	r0, =probing
	ldr	r0, [r0]
	cmp	r0, #0
	beq	1f
	ldr	r0, =probing
	str	lr, [r0, #4]
	ldr	r0, [sp], #4
	subs	pc, lr, #4
1:	add	sp, sp, #4
	mov	r0, #3
	b	fault
prefetch_entry:
	from_user
	bne	kernel_prefetch
	save_user
	cps	#0x13
	enter
	mov	r0, #2
	bl	user_abort
	b	user_return
kernel_prefetch:
	mov	r0, #2
	b	fault
@ claude: an undefined instruction from user mode is the process's (as
@ an abort: user_abort, kind 1; 9pi's FPA code, mini-9pi's hoc), from
@ the kernel a kernel's fault
undefined_entry:
	from_user
	bne	kernel_undefined
	save_user
	cps	#0x13
	enter
	mov	r0, #1
	bl	user_abort
	b	user_return
kernel_undefined:
	mov	r0, #1
fault:
	mov	r1, lr
	bl	kfault
	b	halt

@ the system's registers and instructions, for machine.c
	.global set_ttbr0
set_ttbr0:
	mcr	p15, 0, r0, c2, c0, 0		@ TTBR0
	mov	r0, #0
	mcr	p15, 0, r0, c8, c7, 0		@ the TLB invalidated
	mcr	p15, 0, r0, c7, c5, 6		@ the branch predictor's too: its entries are addresses of the process left
	mcr	p15, 0, r0, c7, c5, 4		@ and what was fetched ahead (prefetch flush)
	bx	lr
@ the processor's cycle counter (the ARM1176's performance monitor, c15):
@ started at 0, and read (machine.c's cpu_mhz)
	.global cycles_start
cycles_start:
	.ifdef PI2
	@ (ARMv7's performance monitor, c9: the cycle counter enabled
	@ (PMCNTENSET's bit 31), then counting, from 0 (PMCR's E and C))
	mov	r0, #0x80000000
	mcr	p15, 0, r0, c9, c12, 1
	mov	r0, #5
	mcr	p15, 0, r0, c9, c12, 0
	.else
	mov	r0, #5				@ counting (bit 0), the cycle counter at 0 (bit 2)
	mcr	p15, 0, r0, c15, c12, 0
	.endif
	bx	lr
	.global cycles
cycles:
	.ifdef PI2
	mrc	p15, 0, r0, c9, c13, 0		@ PMCCNTR
	.else
	mrc	p15, 0, r0, c15, c12, 1
	.endif
	bx	lr
	.global wait_for_interrupt
wait_for_interrupt:
	wfi
	bx	lr
@ The caches (machine.c says what each is for). On: both emptied first
@ (what they hold at power on is anything), the branch predictor's too,
@ then the data cache (C), the instructions' (I) and the prediction (Z).
	.ifdef PI2
@ The Pi 2's caches (ARMv7's; plan_pi2.md's stage 2). What differs
@ from the ARM1176's below: no operation empties a whole data cache,
@ and there are several (a first level for each core, a second for
@ all): each is walked, a line at a time, by its level, set and way.
@ The data cache is indexed by the physical address on the Cortex-A7
@ and the A53, so a page seen at two addresses is one set of lines,
@ as on the Pi 1; the instructions' is not, and is emptied whole
@ where code was written (cache_sync_range, the Pi 1's, whose
@ operations ARMv7 has too).
@
@ dcache_all: every line of every data or unified cache invalidated
@ (r0 = 0), or written to memory first (r0 = 1); r0 = 2: the first
@ level's only, invalidated (a core that starts: the second level is
@ every core's, and holds what the running ones wrote). The walk is the ARM
@ manual's and Linux's (v7_flush_dcache_all): CLIDR says the levels
@ and which have a data cache, CSSELR chooses one, CCSIDR says its
@ line's size, its ways and its sets.
dcache_all:
	push	{r4-r11}
	mov	r6, r0
	mrc	p15, 1, r0, c0, c0, 1		@ CLIDR
	ands	r3, r0, #0x7000000		@ the level where the caches end,
	mov	r3, r3, lsr #23			@ twice
	beq	5f
	tst	r6, #2
	movne	r3, #2
	bic	r6, r6, #2
	mov	r10, #0				@ the level, twice
1:	add	r2, r10, r10, lsr #1
	mov	r1, r0, lsr r2
	and	r1, r1, #7			@ this level's kind
	cmp	r1, #2
	blt	4f				@ none, or instructions only
	mcr	p15, 2, r10, c0, c0, 0		@ CSSELR
	mcr	p15, 0, r1, c7, c5, 4		@ (taken before the next read)
	mrc	p15, 1, r1, c0, c0, 0		@ CCSIDR
	and	r2, r1, #7
	add	r2, r2, #4			@ log2 of a line's bytes
	ldr	r4, =0x3ff
	ands	r4, r4, r1, lsr #3		@ the ways, less 1
	clz	r5, r4				@ where a way's number goes
	ldr	r7, =0x7fff
	ands	r7, r7, r1, lsr #13		@ the sets, less 1
2:	mov	r9, r4
3:	orr	r11, r10, r9, lsl r5
	orr	r11, r11, r7, lsl r2
	cmp	r6, #0
	mcreq	p15, 0, r11, c7, c6, 2		@ invalidated
	mcrne	p15, 0, r11, c7, c14, 2		@ written and invalidated
	subs	r9, r9, #1
	bge	3b
	subs	r7, r7, #1
	bge	2b
4:	add	r10, r10, #2
	cmp	r3, r10
	bgt	1b
5:	mov	r10, #0
	mcr	p15, 2, r10, c0, c0, 0
	mcr	p15, 0, r10, c7, c10, 4
	mcr	p15, 0, r10, c7, c5, 4
	pop	{r4-r11}
	bx	lr
	.endif
	.global caches_enable
caches_enable:
	.ifdef PI2
	@ A Cortex-A7's caches want its SMP bit first (ACTLR's bit 6: this
	@ core's caches are among several cores'), even with one core
	@ running; an A53 has the bit elsewhere, its firmware sets it, and
	@ this write does nothing there. Then every data cache and the
	@ instructions' emptied, the branch predictor's too, and on.
	@ (caches_enable_core: another core's, its own first level only)
	mov	r12, #0
	b	1f
	.global caches_enable_core
caches_enable_core:
	mov	r12, #2
1:	push	{lr}
	mrc	p15, 0, r0, c1, c0, 1
	orr	r0, r0, #(1 << 6)
	mcr	p15, 0, r0, c1, c0, 1
	mov	r0, r12
	bl	dcache_all
	mov	r0, #0
	mcr	p15, 0, r0, c7, c5, 0		@ the instructions' cache invalidated
	mcr	p15, 0, r0, c7, c5, 6		@ the branch predictor's
	mcr	p15, 0, r0, c7, c5, 4
	mrc	p15, 0, r0, c1, c0, 0
	orr	r0, r0, #(1 << 2)
	orr	r0, r0, #(1 << 11)
	orr	r0, r0, #(1 << 12)
	mcr	p15, 0, r0, c1, c0, 0
	mcr	p15, 0, r0, c7, c5, 4
	pop	{pc}
	.endif
	mov	r0, #0
	mcr	p15, 0, r0, c7, c7, 0		@ both caches invalidated
	mcr	p15, 0, r0, c7, c5, 6		@ the branch predictor's
	mrc	p15, 0, r0, c1, c0, 0
	orr	r0, r0, #(1 << 2)
	orr	r0, r0, #(1 << 11)
	orr	r0, r0, #(1 << 12)
	mcr	p15, 0, r0, c1, c0, 0
	bx	lr
@ cache_clean_range(from, to): the data cache's lines (32 bytes) of
@ these addresses written to memory
	.global cache_clean_range
cache_clean_range:
	bic	r0, r0, #31
5:	mcr	p15, 0, r0, c7, c10, 1
	add	r0, r0, #32
	cmp	r0, r1
	blo	5b
	mov	r0, #0
	mcr	p15, 0, r0, c7, c10, 4		@ and there before going on: a line cleaned waits in the write buffer
	bx	lr
@ cache_sync_range(from, to): written to memory, and no longer in the
@ instructions' cache: what was written may be run. The lines written,
@ waited for (the instructions' cache reads the memory, not the write
@ buffer), then all of the instructions' cache emptied, the branch
@ predictor's and what was fetched ahead. All of it and not these
@ lines, as principia's 9pi (cacheiinv: it has no other) and Linux
@ (v6_coherent_kern_range) do on this processor.
@ old: a line at a time, mcr p15, 0, r0, c7, c5, 1 in the loop, and no
@ wait: programs died on the author's Pi1 with the caches on, the more
@ they started others (rio, rc at an ls), and not with them off.
	.global cache_sync_range
cache_sync_range:
	bic	r0, r0, #31
6:	mcr	p15, 0, r0, c7, c10, 1
	add	r0, r0, #32
	cmp	r0, r1
	blo	6b
	mov	r0, #0
	mcr	p15, 0, r0, c7, c10, 4
	.ifdef PI2
	@ every core's (ICIALLUIS, BPIALLIS): the code written here may
	@ be run on another, whose cache has the page's old bytes
	mcr	p15, 0, r0, c7, c1, 0
	mcr	p15, 0, r0, c7, c1, 6
	.else
	mcr	p15, 0, r0, c7, c5, 0
	mcr	p15, 0, r0, c7, c5, 6
	.endif
	mcr	p15, 0, r0, c7, c5, 4
	bx	lr
@ cache_flush_all: everything written to memory and both caches emptied
@ (9pi's cacheuwbinv, which it does at each change of process)
	.global cache_flush_all
cache_flush_all:
	.ifdef PI2
	push	{lr}
	mov	r0, #1
	bl	dcache_all
	mov	r0, #0
	mcr	p15, 0, r0, c7, c5, 0
	mcr	p15, 0, r0, c7, c5, 6
	mcr	p15, 0, r0, c7, c5, 4
	pop	{pc}
	.endif
	mov	r0, #0
	mcr	p15, 0, r0, c7, c10, 4
	mcr	p15, 0, r0, c7, c5, 4
	mcr	p15, 0, r0, c7, c14, 0		@ the data cache written and emptied
	mcr	p15, 0, r0, c7, c5, 0		@ the instructions' emptied
	mcr	p15, 0, r0, c7, c5, 6
	mcr	p15, 0, r0, c7, c10, 4
	mcr	p15, 0, r0, c7, c5, 4
	bx	lr
@ the writes not yet in memory, there
	.global cache_drain
cache_drain:
	mov	r0, #0
	mcr	p15, 0, r0, c7, c10, 4
	bx	lr
	.global fault_address
fault_address:
	cmp	r0, #0
	mrceq	p15, 0, r0, c6, c0, 0		@ FAR
	mrcne	p15, 0, r0, c6, c0, 2		@ IFAR
	bx	lr
	.global fault_status
fault_status:
	cmp	r0, #0
	mrceq	p15, 0, r0, c5, c0, 0		@ DFSR
	mrcne	p15, 0, r0, c5, c0, 1		@ IFSR
	bx	lr
	.global empty_table
empty_table:
	ldr	r0, =empty_pgdir
	sub	r0, r0, #KERNBASE
	bx	lr

@ swtch(from, to): step 3's
	.global swtch
swtch:
	stmia	r0!, {r4-r11, sp, lr}
	vstmia	r0, {d8-d15}
	ldmia	r1!, {r4-r11, sp, lr}
	vldmia	r1, {d8-d15}
	bx	lr

@ the file system's image, xv6 arm-pi1's fs.img: the ramdisk, written
@ in place (a data section: the kernel's to change)
	.data
	.ifdef PI2
@ how far each of the other cores came in its start (written with its
@ caches off: lines of its own, read by the first without the cache)
	.global core_stage
	.balign	64
core_stage:
	.space	64
klock:
	.word	1
	.balign	64
	.endif
	.align	9
	.global fs_image
	.global fs_image_end
fs_image:
	.incbin	"fs.img"			@ claude: from the build directory (as -I)
fs_image_end:
	.align	2
	.global fs_image_size
fs_image_size:
	.word	fs_image_end - fs_image

@ the console's font, xv6 arm-pi1's (font1.bin: 128 characters, 16 bytes
@ each, a row a byte, its bit 0 the leftmost pixel)
	.balign	16
	.global	font_image
font_image:
	.incbin	"font.bin"		@ claude: from the build directory (as -I)

@ the page tables of the boot: the kernel's (16KB, 16KB aligned), the
@ vectors' second-level table (1KB) and page, the empty user table
	.bss
	.ifdef PI2
	.align	12
core_stacks:
	.space	3 * 0x20000
	.endif
	.align	14
	.global kpgdir
kpgdir:
	.space	16384
	.global empty_pgdir
empty_pgdir:
	.space	4096
vectors_page:
	.space	4096
	.align	10
vectors_l2:
	.space	1024
