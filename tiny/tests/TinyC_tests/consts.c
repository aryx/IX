// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// consts: constant expressions, folded as the tree is built. A global
// initialized by an operator on constants (old: "not a constant
// initializer"), an array's size and a case by one, each folded in its
// type's bits: an int's product wrapping, an unsigned's, a shift, a
// negative divided, ~ and -; and a pointer's p + 1, its 1 scaled.
#include "libc.h"

enum { K = 1 << 4, M = K * 3 + 1 };

int six = 2 * 3;
int masks[3] = { 1 << 4, 0xff & ~0x0f, -7 / 2 };
unsigned int big = 0xffffffff + 2;
int wrap = 0x7fffffff + 1;
short sh = 70000;
int rem = -7 % 3;
char buf[M - K];

int
kind(int n)
{
	switch(n){
	case K - 1: return 1;
	case K * 2: return 2;
	}
	return 0;
}

void
main(int argc, char *argv[])
{
	int a[4];
	int *p;

	a[0] = 10; a[1] = 20; a[2] = 30; a[3] = 40;
	p = a;
	print("%d %d %d %d\n", six, masks[0], masks[1], masks[2]);
	print("%u %d %d %d\n", big, wrap, sh, rem);
	print("%d %d %d %d\n", (int)sizeof buf, kind(15), kind(32), kind(3));
	print("%d %d %d\n", *(p + 1), *(p + 3 - 1), (int)(&a[3] - &a[1]));
	print("%d %d\n", -(-5), ~~6);
	exits(0);
}
