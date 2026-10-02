// mini-xv6, step 3, on the Pi 4 (plan_kernel_mini_ml.md, step 4): step
// 2's (the vectors, the trap's entry and return through cur_tf, the
// running process's frame), and swtch, from one kernel stack to
// another. (First, as there: the vectors are the image's first bytes.)

#include "../../step2/pi4/l.s"

// swtch(from, to): what a context keeps is the stack pointer, the link
// (where swtch returns: where the other called it, or, the first time,
// machine.c's trampoline) and R26, the value stack's top in ML's code,
// which goes through the C that called here untouched. Nothing else:
// 7c's C keeps no register across a call, and ML's spills its own.
// machine.c's k_swtch wraps it with the runtime's view of the stacks.
TEXT swtch+0(SB), $0
	MOV	to+8(FP), R1
	MOV	RSP, R2
	MOV	R2, 0(R0)
	MOV	R30, 8(R0)
	MOV	R26, 16(R0)
	MOV	0(R1), R2
	MOV	R2, RSP
	MOV	8(R1), R30
	MOV	16(R1), R26
	RETURN
