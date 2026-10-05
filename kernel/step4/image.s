@ Claude Code
@ Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
@
@ mini-xv6, step 4: the user program's image, linked at 0 (user.ld),
@ in the kernel's read-only data; the kernel copies it into a process's
@ pages (xv6 would read an ELF from its file system: steps to come).
	.section .rodata
	.global user_image
	.global user_image_end
	.align	2
user_image:
	.incbin	"build/user.bin"
user_image_end:
