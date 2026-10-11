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
@ host_input(buf): the next key or move from the page, 8 bytes in buf:
@ 1 a keyboard's report, 2 the mouse's state, 0 nothing (Board.ml)
	.global host_input
host_input:
	mrc	p15, 7, r0, c15, c0, 2
	bx	lr
@ host_cursor(buf): the cursor's 66 bytes given to the page: 1 when it
@ draws the cursor itself
	.global host_cursor
host_cursor:
	mrc	p15, 7, r0, c15, c0, 3
	bx	lr
@ host_draw(desc): memdraw's general loop on three images of the
@ kernel's, by the host: 1 drawn, 0 not this one, -1 no host that draws
	.global host_draw
host_draw:
	mrc	p15, 7, r0, c15, c0, 4
	bx	lr
@ host_code(pa, n): the instructions at these physical addresses were
@ written: what the emulator decoded and translated of them is void
	.global host_code
host_code:
	mrc	p15, 7, r0, c15, c0, 5
	bx	lr
