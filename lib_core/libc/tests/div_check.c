/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* arm's division (arch/arm/div.s: _div, _mod, _divu, _modu, which the
 * compiler calls for / and %) against a long division by shifts: the
 * values around 0, the powers of two and their neighbours, the
 * extremes, and pairs of a generator's, each with its sign changed.
 * Exits "bad", the pair on the standard error, at the first wrong
 * answer. Built and run by mem_check.sh (arm only: arm64 divides). */
#include <u.h>
#include <libc.h>

/* n / d and n % d by shifts and subtractions, d not 0 */
static ulong
udiv(ulong n, ulong d, ulong *r)
{
	ulong q, rem;
	int i;

	q = 0;
	rem = 0;
	for(i = 31; i >= 0; i--){
		rem = (rem << 1) | ((n >> i) & 1);
		q <<= 1;
		if(rem >= d){
			rem -= d;
			q |= 1;
		}
	}
	*r = rem;
	return q;
}

static ulong seed = 1;
static ulong
next(void)
{
	seed = seed * 1103515245 + 12345;
	return seed ^ (seed >> 13);
}

/* "bad n d" on the standard error, in hexadecimal (no print in this
 * libc.a: fmt is not in it) */
static void
bad(ulong n, ulong d)
{
	char buf[32];
	int i, k;
	ulong v;

	k = 0;
	buf[k++] = 'b'; buf[k++] = 'a'; buf[k++] = 'd';
	for(v = n, i = 0; i < 2; i++, v = d){
		int s;
		buf[k++] = ' ';
		for(s = 28; s >= 0; s -= 4)
			buf[k++] = "0123456789abcdef"[(v >> s) & 15];
	}
	buf[k++] = '\n';
	write(2, buf, k);
	exits("bad");
}

static ulong vals[200];
static int nvals;

static int
check(ulong n, ulong d)
{
	ulong q, r, an, ad;
	long sn, sd, sq, sr;

	if(d == 0)
		return 0;
	q = udiv(n, d, &r);
	if(n / d != q || n % d != r)
		return 1;
	sn = n;
	sd = d;
	/* (the one quotient that does not fit, as C leaves it) */
	if(sn == (long)0x80000000 && sd == -1)
		return 0;
	an = sn < 0 ? -sn : sn;
	ad = sd < 0 ? -sd : sd;
	q = udiv(an, ad, &r);
	sq = (sn < 0) != (sd < 0) ? -(long)q : (long)q;
	sr = sn < 0 ? -(long)r : (long)r;
	if(sn / sd != sq || sn % sd != sr)
		return 1;
	return 0;
}

void
main(void)
{
	int i, j, k;
	ulong n, d;

	for(i = 0; i < 20; i++){
		vals[nvals++] = i;
		vals[nvals++] = -i;
	}
	for(i = 2; i < 32; i++)
		for(k = -1; k <= 1; k++)
			vals[nvals++] = (1UL << i) + k;
	vals[nvals++] = 0x7fffffff;
	vals[nvals++] = 0x80000000;
	vals[nvals++] = 0xffffffff;
	for(i = 0; i < nvals; i++)
		for(j = 0; j < nvals; j++)
			if(check(vals[i], vals[j]))
				bad(vals[i], vals[j]);
	for(i = 0; i < 1000000; i++){
		n = next();
		d = next() >> (next() & 31);
		if(check(n, d) || check(n >> (i & 31), d))
			bad(n, d);
	}
	exits(nil);
}
