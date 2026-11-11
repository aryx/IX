// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// hello: a program to try the tools on, in /examples on tiny-kernel. Its
// square is assembly's (square.tm), the rest C; the Buildfile beside it
// builds it, from /src's C runtime:
//
//	cd /examples; build; ./hello
//	trace ./hello                its system calls
//	debug ./hello                b square, c, bt, r, s, x/i pc 3, q
#include "/src/TinyKernel/libc/user.h"

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
