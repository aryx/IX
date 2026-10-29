/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */

/* a program's own loops over memory, gc.c's scan's kind: blocks of
 * words copied by *q++ = *p++, then walked, each word tested and
 * summed; no libc in the loops */
#include <u.h>
#include <libc.h>

enum { N = 4096 };
ulong from[N], to[N];

static ulong*
copyw(ulong *q, ulong *p, int n)
{
	ulong *e;

	e = p + n;
	while(p < e)
		*q++ = *p++;
	return q;
}

static ulong
walk(ulong *p, ulong *e)
{
	ulong s, w;

	s = 0;
	while(p < e){
		w = *p++;
		if(w & 1)
			s += w >> 1;
		else
			s ^= w;
	}
	return s;
}

void
main(void)
{
	ulong s, x;
	int i, k;

	x = 12345;
	for(i = 0; i < N; i++){
		x = x * 1103515245 + 12345;
		from[i] = x;
	}
	s = 0;
	for(k = 0; k < 400; k++){
		copyw(to, from + (k & 15), N - 16);
		s += walk(to, to + N - 16);
	}
	print("%lu\n", s);
	exits(0);
}
