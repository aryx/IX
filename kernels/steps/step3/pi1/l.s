// mini-xv6, step 3, on the Pi 1 by ix's tools (plan_kernel_mini_ml.md,
// step 9): step 2's (the start, the vectors, the trap's entry and
// return through cur_tf, the running process's frame), and swtch, from
// one kernel stack to another.

#include "../../step2/pi1/l.s"

// swtch(from, to): what a context keeps is the stack pointer, the link
// (where swtch returns: where the other called it, or, the first time,
// machine.c's trampoline) and R10, the value stack's top in ML's code,
// which goes through the C that called here untouched. Nothing else:
// 5c's C keeps no register across a call, and ML's spills its own.
// machine.c's k_swtch wraps it with the runtime's view of the stacks.
TEXT swtch+0(SB), $0
	MOVW	to+4(FP), R1
	MOVW	R13, 0(R0)
	MOVW	R14, 4(R0)
	MOVW	R10, 8(R0)
	MOVW	0(R1), R13
	MOVW	4(R1), R14
	MOVW	8(R1), R10
	RET
