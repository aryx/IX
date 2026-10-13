/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* strtod, a float read exactly: the reading half of lib_core/libc/ix/fmt.c
 * (ix's own, not Plan 9's), for float_of_string, which tiny-assembler
 * calls on a constant (a compiler writes one with 17 digits: no
 * product of two exact floats gives it). The printing half is not
 * here: no tiny program prints a float.
 *
 * A double is m * 2^e, whose decimal expansion is finite, at most 767
 * digits. It is computed whole (expand) with one operation on large
 * numbers, a multiplication by a small one: m * 2^e when e >= 0, and
 * m * 5^-e / 10^-e when e < 0. Reading guesses a double, then moves it
 * until the digits read are between the two halfway points around it,
 * which are expanded the same way. */

enum {
	Base = 10000,		/* a limb: 4 digits, so that 32 bits are enough */
	Ld = 4,
	Nlimb = 200,
	Ndig = Nlimb*Ld + 1,
};

static uvlong infbits = (uvlong)0x7FF00000<<32;

static uvlong
d2u(double d)
{
	union { uvlong v; double d; } u;

	u.d = d;
	return u.v;
}

static double
u2d(uvlong v)
{
	union { uvlong v; double d; } u;

	u.v = v;
	return u.d;
}

static double NaN(void) { return u2d(infbits | 1); }
static double Inf(int sign) { return u2d(sign < 0 ? infbits | (uvlong)1<<63 : infbits); }

/* m * 2^e, exactly: its digits in dig, without zeros at either end; the
 * value is 0.dig * 10^dp. Returns their number, 0 for zero. */
static int
expand(uvlong m, int e, char *dig, int *dp)
{
	uint limb[Nlimb], by, x, c;
	int nl, i, j, k, n, frac;

	for(nl = 0; m != 0; m /= Base)
		limb[nl++] = m % Base;
	frac = e < 0 ? -e : 0;
	for(k = e < 0 ? -e : e; k > 0 && nl > 0; ){
		/* by 5^7 or 2^18 at most: a limb's product fits in 32 bits */
		if(e < 0){
			by = 1;
			for(i = 0; i < 7 && k > 0; i++, k--)
				by *= 5;
		}else{
			i = k > 18 ? 18 : k;
			by = 1 << i;
			k -= i;
		}
		c = 0;
		for(i = 0; i < nl; i++){
			x = c + limb[i] * by;
			c = x / Base;
			limb[i] = x - c*Base;	/* (not %: a second division) */
		}
		for(; c != 0; c /= Base)
			limb[nl++] = c % Base;
	}
	n = 0;
	for(i = nl-1; i >= 0; i--){
		x = limb[i];
		for(j = Ld-1; j >= 0; j--){
			dig[n+j] = '0' + x%10;
			x /= 10;
		}
		n += Ld;
	}
	*dp = n - frac;
	for(i = 0; i < n && dig[i] == '0'; i++)
		(*dp)--;
	while(n > i && dig[n-1] == '0')
		n--;
	memmove(dig, dig+i, n-i);
	return n - i;
}

/* the mantissa and the exponent of a finite double's bits */
static uvlong
mantissa(uvlong b, int *e)
{
	int x;

	x = (b >> 52) & 0x7FF;
	b &= ((uvlong)1<<52) - 1;
	*e = x == 0 ? -1074 : x - 1075;
	return x == 0 ? b : b | (uvlong)1<<52;
}

/* the digits read (0.dig * 10^dp) against the point halfway between
 * the double of bits b and the next one: (2m+1) * 2^(e-1) */
static int
cmphalf(char *dig, int n, int dp, uvlong b)
{
	char half[Ndig];
	int hn, hdp, e, c;
	uvlong m;

	m = mantissa(b, &e);
	hn = expand(2*m + 1, e - 1, half, &hdp);
	if(dp != hdp)
		return dp < hdp ? -1 : 1;
	c = memcmp(dig, half, n < hn ? n : hn);
	if(c != 0)
		return c;
	return n - hn;
}

static int
lower(int c)
{
	return c >= 'A' && c <= 'Z' ? c + 'a' - 'A' : c;
}

/* s starts with the word w, in either case */
static int
word(char *s, char *w)
{
	int n;

	for(n = 0; w[n] != 0; n++)
		if(lower(s[n]) != w[n])
			return 0;
	return n;
}

/* C's strtod, without the hexadecimal floats */
double
strtod(char *s0, char **endp)
{
	char dig[Ndig], *s, *t;
	int n, dp, neg, seen, point, sticky, x, xneg, c, i;
	uvlong b;
	double d, p;

	s = s0;
	while(*s == ' ' || (*s >= '\t' && *s <= '\r'))
		s++;
	neg = *s == '-';
	if(*s == '-' || *s == '+')
		s++;
	if((n = word(s, "infinity")) != 0 || (n = word(s, "inf")) != 0){
		s += n;
		d = Inf(1);
		goto Out;
	}
	if((n = word(s, "nan")) != 0){
		s += n;
		d = NaN();
		goto Out;
	}
	/* the digits, without the zeros before them: 0.dig * 10^dp. Past
	 * the buffer (longer than any halfway point), digits that are
	 * not all 0 count as a last 1: it only says on which side of a
	 * halfway point the number is. */
	n = 0;
	dp = 0;
	seen = 0;
	point = 0;
	sticky = 0;
	for(;; s++){
		if(*s == '.' && !point){
			point = 1;
			continue;
		}
		if(*s < '0' || *s > '9')
			break;
		seen = 1;
		if(n == 0 && *s == '0'){
			if(point)
				dp--;
			continue;
		}
		if(n < Ndig-1)
			dig[n++] = *s;
		else if(*s != '0')
			sticky = 1;
		if(!point)
			dp++;
	}
	if(!seen){
		if(endp != nil)
			*endp = s0;
		return 0;
	}
	if(lower(*s) == 'e'){
		t = s + 1;
		xneg = *t == '-';
		if(*t == '-' || *t == '+')
			t++;
		if(*t >= '0' && *t <= '9'){
			for(x = 0; *t >= '0' && *t <= '9'; t++)
				if(x < 100000)
					x = x*10 + *t - '0';
			dp += xneg ? -x : x;
			s = t;
		}
	}
	if(sticky)
		dig[n++] = '1';
	while(n > 0 && dig[n-1] == '0')
		n--;
	d = 0;
	if(n == 0 || dp < -330)
		goto Out;
	if(dp > 310){
		d = Inf(1);
		goto Out;
	}
	/* a guess from the first digits, a few units off at most (a power
	 * of 10 up to 10^22 is exact) ... */
	for(i = 0; i < n && i < 17; i++)
		d = d*10 + (dig[i] - '0');
	x = dp - i;
	for(; x >= 22; x -= 22)
		d *= 1e22;
	for(; x <= -22; x += 22)
		d /= 1e22;
	for(p = 1, i = x < 0 ? -x : x; i > 0; i--)
		p *= 10;
	d = x < 0 ? d/p : d*p;
	/* ... moved to the double whose two halfway points are around the
	 * digits; on one of them, to the even one. Positive doubles are
	 * in the order of their bits, from 0 to infinity. */
	b = d2u(d);
	if(b > infbits)
		b = infbits;
	while(b < infbits && (c = cmphalf(dig, n, dp, b)) >= 0 && (c > 0 || (b & 1)))
		b++;
	while(b > 0 && (c = cmphalf(dig, n, dp, b-1)) <= 0 && (c < 0 || (b & 1)))
		b--;
	d = u2d(b);
Out:
	if(endp != nil)
		*endp = s;
	return neg ? u2d(d2u(d) | (uvlong)1<<63) : d;	/* (not -d: -0 is not 0 - 0) */
}
