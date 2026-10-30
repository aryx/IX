/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* The segments as a JIT uses them (segattach(2)): a segment of zeros
 * attached, a function's instructions written in it, segflush, the
 * function called; then other instructions written at the same place,
 * segflush again, and the call runs the new ones (a processor that
 * kept the old ones decoded, or in its instructions' cache, would run
 * the old). segfree's zeros, a class refused, segdetach. */
#include <u.h>
#include <libc.h>
#include <os/plan9/seg.h>

typedef int (*fn)(int);

/* (ix's libc formats into a buffer only: snprint, vsnprint) */
static void
say(char *fmt, ...)
{
	char buf[256];
	va_list arg;

	va_start(arg, fmt);
	vsnprint(buf, sizeof buf, fmt, arg);
	va_end(arg);
	write(1, buf, strlen(buf));
}

void
main(void)
{
	ulong *code;
	fn f;

	code = segattach(0, "memory", nil, 4096);
	if(code == (void*)-1){
		say("segattach failed\n");
		exits("segattach");
	}
	say("attached, zeros: %d\n", code[0] == 0 && code[1023] == 0);
	code[0] = 0xE280002A;	/* ADD $42, R0 */
	code[1] = 0xE1A0F00E;	/* RET: MOVW R14, R15 */
	segflush(code, 8);
	f = (fn)code;
	say("f(1) = %d\n", f(1));
	code[0] = 0xE2800007;	/* ADD $7, R0 */
	segflush(code, 8);
	say("written again, f(1) = %d\n", f(1));
	segfree(code, 4096);
	say("freed, zeros: %d\n", code[0] == 0 && code[1] == 0);
	say("a bad class refused: %d\n", segattach(0, "nonsense", nil, 4096) == (void*)-1);
	say("detached: %d\n", segdetach(code) == 0);
	exits(nil);
}
