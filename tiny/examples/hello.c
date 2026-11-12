// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// hello: a program to try the tools on, in /examples on tiny-kernel. Its
// square is assembly's (square.s), the rest C; the Buildfile beside it
// builds it, with /lib/c's runtime:
//
//	cd /examples; build; ./hello
//	trace ./hello                its system calls
//	debug ./hello                b square, c, bt, r, s, x/i pc 3, q
//
// (user.h, the system's calls, found by cc -I /src/TinyKernel/libc, the
// Buildfile's; on the host, tiny/TinyKernel/libc's)
#include "user.h"

int square(int n);

void
main(int argc, char *argv[])
{
	int i, sum;

	sum = 0;
	for(i = 1; i <= 10; i++)
		sum = sum + square(i);
	print("hello: the squares of 1 to 10 add up to %d\n", sum);
	exit(0);
}
