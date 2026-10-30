/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* the program mini-acid debugs in debuggers/tests/acid_proc.sh: three
 * calls deep, a parameter each, a local, a global */
#include <u.h>
#include <libc.h>

int count;

int
leaf(int a, int b)
{
	return a*b + count;
}

int
middle(int x)
{
	int y;

	y = leaf(x, x+1);
	return y + 1;
}

void
main(void)
{
	count = middle(3);
	exits(nil);
}
