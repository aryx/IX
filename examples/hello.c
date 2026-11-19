/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */

/* hello: a program to try the tools on, in /src/examples on mini-9pi.
 * Its square is assembly's (square_arm.s, or square_arm64.s on that
 * machine), the rest C, over lib_core's C library, which is Plan 9's:
 * a line is formatted by snprint and written, since that library has
 * no print (lib_core/libc/README.md says what it has). The mkfile
 * beside it builds it (cc, asm, then ld):
 *
 *	cd /src/examples; mk; ../_mk/5-plan9/examples/hello
 */
#include <u.h>
#include <libc.h>

int square(int n);

void
main(void)
{
	char line[64];
	int i, sum, n;

	sum = 0;
	for(i = 1; i <= 10; i++)
		sum = sum + square(i);
	n = snprint(line, sizeof line, "hello: the squares of 1 to 10 add up to %d\n", sum);
	write(1, line, n);
	exits(nil);
}
