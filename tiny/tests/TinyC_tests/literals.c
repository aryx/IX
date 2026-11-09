// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// The type of a number by its suffix: u makes it unsigned, so that a
// comparison or a division with it is unsigned too (old: the u was
// dropped, -1 < 1u was true). And a do while, and volatile, which a
// declaration in a function may start with.
#include "libc.h"

void
main(int argc, char *argv[])
{
	int i;
	volatile int v;

	print("%d\n", -1 < 1u);
	print("%d\n", -1 < 1);
	print("%ud\n", -1 / 10u);
	print("%d\n", -1 / 10);
	print("%ud\n", 0xffffffffu >> 28);
	print("%d\n", sizeof 1u);
	v = 3;
	i = 0;
	do
		i += v;
	while(i < 10);
	print("%d\n", i);
	exits(0);
}
