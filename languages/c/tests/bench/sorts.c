/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */

/* a quicksort of integers by hand (comparisons, swaps through
 * indexes, recursion), then libc's qsort, which calls back a
 * comparison function for each pair */
#include <u.h>
#include <libc.h>

enum { N = 30000 };
int a[N], b[N];

static void
sort(int *v, int lo, int hi)
{
	int i, j, p, t;

	while(lo < hi){
		p = v[(lo + hi) / 2];
		i = lo;
		j = hi;
		while(i <= j){
			while(v[i] < p)
				i++;
			while(v[j] > p)
				j--;
			if(i <= j){
				t = v[i]; v[i] = v[j]; v[j] = t;
				i++;
				j--;
			}
		}
		if(j - lo < hi - i){
			sort(v, lo, j);
			lo = i;
		}else{
			sort(v, i, hi);
			hi = j;
		}
	}
}

static int
cmp(void *x, void *y)
{
	return *(int*)x - *(int*)y;
}

void
main(void)
{
	ulong x, s;
	int i;

	x = 7;
	for(i = 0; i < N; i++){
		x = x * 1103515245 + 12345;
		a[i] = b[i] = (x >> 8) & 0xffffff;
	}
	sort(a, 0, N - 1);
	qsort(b, N, sizeof b[0], cmp);
	s = 0;
	for(i = 0; i < N; i++){
		if(a[i] != b[i])
			print("differ at %d\n", i);
		s = s * 31 + a[i];
	}
	print("%lu\n", s);
	exits(0);
}
