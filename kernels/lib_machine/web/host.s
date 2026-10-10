@ Claude Code
@ Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
@
@ What the kernel built for a page (make WEB=1; plan_web.md, stage 2)
@ asks of its machine, which is mini-qemu's board compiled to
@ JavaScript: bytes moved and filled by the host itself, where the Pi's
@ kernel runs libc.c's loops. An instruction of the emulator costs some
@ hundreds of the host's, and memmove with a page's zeros were a third
@ of the instructions of a boot.
@
@ The request is a read of a register of CP15 that no processor has
@ (Board.host_call answers it): 1 when the board did it, 0 when it
@ would not (a range not all mapped, or not RAM in one piece), and the
@ caller then runs its loop. On a Raspberry Pi the instruction is
@ undefined: this kernel is not for one.

@ host_move(to, from, n): as memmove
	.global host_move
host_move:
	mrc	p15, 7, r0, c15, c0, 0
	bx	lr
@ host_fill(to, byte, n): as memset
	.global host_fill
host_fill:
	mrc	p15, 7, r0, c15, c0, 1
	bx	lr
