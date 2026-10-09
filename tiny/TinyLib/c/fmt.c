/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/*
 * ix's own, NOT Plan 9's: in the place of goken's fmt/ (dofmt.c,
 * fltfmt.c, strtod.c and nine others, 2,372 lines; see ../README.md),
 * what mini-ml's runtime asks of it: snprint and sprint with C's
 * conversions (no fmtinstall, no runes, no %r), strtod, and the NaN
 * and Inf helpers of libc.h.
 *
 * Floats are converted exactly, both ways, as C99 and so OCaml want
 * ("%.17g" then float_of_string gives the float back): a double is
 * m * 2^e, whose decimal expansion is finite, at most 767 digits. It
 * is computed whole (expand) with one operation on large numbers, a
 * multiplication by a small one: m * 2^e when e >= 0, and
 * m * 5^-e / 10^-e when e < 0 (in 32 bits: arm has no 64-bit
 * division but vlrt.c's). Printing rounds those digits (half to
 * even). Reading guesses a double, then moves it until the digits
 * read are between the two halfway points around it, which are
 * expanded the same way. Slower than Plan 9's or David Gay's, which
 * avoid the large numbers when they can; shorter.
 *
 * tests/fmt.sh compares it with glibc's on a few million floats.
 */

enum {
	Base = 10000,		/* a limb: 4 digits, so that 32 bits are enough */
	Ld = 4,
	Nlimb = 200,
	Ndig = Nlimb*Ld + 1,
	Maxprec = 150,
	Nbody = 512,

	Fminus = 1, Fplus = 2, Fspace = 4, Fzero = 8, Fsharp = 16, Fupper = 32,
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

double NaN(void) { return u2d(infbits | 1); }
double Inf(int sign) { return u2d(sign < 0 ? infbits | (uvlong)1<<63 : infbits); }
int isNaN(double d) { return (d2u(d) & ~((uvlong)1<<63)) > infbits; }

int
isInf(double d, int sign)
{
	uvlong x;

	x = d2u(d);
	if(sign == 0)
		return (x & ~((uvlong)1<<63)) == infbits;
	return x == d2u(Inf(sign));
}

/*
 * Exact digits
 */

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

/* dig cut to its first k digits (k <= 0: to nothing, or to a 1 before
 * them), rounded to the nearest, a half to the even one. Returns the
 * new number of digits; dp is one more when 99.. became 1. */
static int
roundto(char *dig, int n, int *dp, int k)
{
	int i, up;

	if(k >= n)
		return n;
	if(k < 0)
		return 0;
	up = dig[k] > '5' || (dig[k] == '5' && (n > k+1 || (k > 0 && (dig[k-1] & 1))));
	if(up){
		for(i = k-1; i >= 0 && dig[i] == '9'; i--)
			;
		if(i < 0){
			dig[0] = '1';
			(*dp)++;
			return 1;
		}
		dig[i]++;
		k = i + 1;
	}
	while(k > 0 && dig[k-1] == '0')
		k--;
	return k;
}

/*
 * Printing
 */

/* a float's body (no sign) for the verb c (e, f or g), precision p */
static int
fltbody(char *s, double d, int c, int p, int flags)
{
	char dig[Ndig], *s0;
	int n, dp, e, x, i, strip;
	uvlong m;

	s0 = s;
	m = mantissa(d2u(d), &e);
	n = expand(m, e, dig, &dp);
	if(n == 0)
		dp = 1;
	strip = 0;
	if(c == 'g'){
		if(p == 0)
			p = 1;
		n = roundto(dig, n, &dp, p);
		x = dp - 1;
		strip = !(flags & Fsharp);
		if(x < -4 || x >= p){
			c = 'e';
			p--;
		}else{
			c = 'f';
			p -= dp;
		}
	}
	if(c == 'e'){
		n = roundto(dig, n, &dp, p+1);
		x = dp - 1;
		dp = 1;
	}else
		n = roundto(dig, n, &dp, dp+p);
	/* the digits before the point, the point, p digits after it */
	if(dp <= 0)
		*s++ = '0';
	for(i = 0; i < dp; i++)
		*s++ = i < n ? dig[i] : '0';
	if(p > 0 || (flags & Fsharp))
		*s++ = '.';
	for(i = dp; i < dp+p; i++)
		*s++ = i >= 0 && i < n ? dig[i] : '0';
	if(strip && p > 0){
		while(s[-1] == '0')
			s--;
		if(s[-1] == '.')
			s--;
	}
	if(c == 'e'){
		*s++ = flags & Fupper ? 'E' : 'e';
		*s++ = x < 0 ? '-' : '+';
		if(x < 0)
			x = -x;
		if(x >= 100)
			*s++ = '0' + x/100;
		*s++ = '0' + x/10%10;
		*s++ = '0' + x%10;
	}
	return s - s0;
}

/* an integer's digits */
static int
intbody(char *s, uvlong v, int base, int flags)
{
	char tmp[24], *digits;
	int n, i;

	digits = flags & Fupper ? "0123456789ABCDEF" : "0123456789abcdef";
	n = 0;
	do{
		tmp[n++] = digits[v % base];
		v /= base;
	}while(v != 0);
	for(i = 0; i < n; i++)
		s[i] = tmp[n-1-i];
	return n;
}

/* C's printf: %[-+ 0#][width][.precision][l|ll](d i u x X o c s e f g E F G %),
 * a width or a precision may be *. At most len-1 bytes and a 0 are
 * written; returns their number. */
int
vsnprint(char *buf, int len, char *fmt, va_list args)
{
	char body[Nbody], *b, *out, *end;
	int c, flags, width, prec, lng, n, i, sign, pad, base;
	vlong v;
	double d;

	out = buf;
	end = buf + len - 1;
	if(len <= 0)
		return 0;
	while((c = *fmt++) != 0){
		if(c != '%'){
			if(out < end)
				*out++ = c;
			continue;
		}
		flags = 0;
		for(;; fmt++){
			if(*fmt == '-') flags |= Fminus;
			else if(*fmt == '+') flags |= Fplus;
			else if(*fmt == ' ') flags |= Fspace;
			else if(*fmt == '0') flags |= Fzero;
			else if(*fmt == '#') flags |= Fsharp;
			else break;
		}
		width = 0;
		prec = -1;
		if(*fmt == '*'){
			fmt++;
			width = va_arg(args, int);
			if(width < 0){
				flags |= Fminus;
				width = -width;
			}
		}else
			while(*fmt >= '0' && *fmt <= '9')
				width = width*10 + *fmt++ - '0';
		if(*fmt == '.'){
			fmt++;
			prec = 0;
			if(*fmt == '*'){
				fmt++;
				prec = va_arg(args, int);
			}else
				while(*fmt >= '0' && *fmt <= '9')
					prec = prec*10 + *fmt++ - '0';
		}
		for(lng = 0; *fmt == 'l'; fmt++)
			lng++;
		c = *fmt++;
		if(c == 0)
			break;
		b = body;
		n = 0;
		sign = 0;
		base = 10;
		switch(c){
		case 'c':
			body[0] = va_arg(args, int);
			n = 1;
			flags &= ~Fzero;
			break;
		case 's':
			b = va_arg(args, char*);
			if(b == nil)
				b = "<nil>";
			n = strlen(b);
			if(prec >= 0 && n > prec)
				n = prec;
			flags &= ~Fzero;
			break;
		case 'd':
		case 'i':
			if(lng >= 2)
				v = va_arg(args, vlong);
			else if(lng == 1)
				v = va_arg(args, long);
			else
				v = va_arg(args, int);
			if(v < 0){
				sign = '-';
				v = -v;
			}
			n = intbody(body, v, 10, flags);
			break;
		case 'o':
			base = 8;
			goto Unsigned;
		case 'X':
			flags |= Fupper;
		case 'x':
			base = 16;
		case 'u':
		Unsigned:
			if(lng >= 2)
				v = va_arg(args, uvlong);
			else if(lng == 1)
				v = va_arg(args, ulong);
			else
				v = va_arg(args, uint);
			n = intbody(body, v, base, flags);
			flags &= ~(Fplus|Fspace);
			break;
		case 'E':
		case 'F':
		case 'G':
			flags |= Fupper;
			c += 'a' - 'A';
		case 'e':
		case 'f':
		case 'g':
			d = va_arg(args, double);
			if(d2u(d) >> 63){
				sign = '-';
				d = -d;
			}
			if(isNaN(d) || isInf(d, 1)){
				if(isNaN(d))
					b = flags & Fupper ? "NAN" : "nan";
				else
					b = flags & Fupper ? "INF" : "inf";
				n = 3;
				flags &= ~Fzero;
				break;
			}
			if(prec < 0)
				prec = 6;
			if(prec > Maxprec)
				prec = Maxprec;
			n = fltbody(body, d, c, prec, flags);
			break;
		default:	/* %%, and what is not a verb */
			body[0] = c;
			n = 1;
			flags = 0;
			break;
		}
		if(sign == 0 && c != 'c' && c != 's' && c != '%'){
			if(flags & Fplus)
				sign = '+';
			else if(flags & Fspace)
				sign = ' ';
		}
		pad = width - n - (sign != 0);
		if(!(flags & (Fminus|Fzero)))
			for(; pad > 0; pad--)
				if(out < end)
					*out++ = ' ';
		if(sign != 0 && out < end)
			*out++ = sign;
		if(!(flags & Fminus))
			for(; pad > 0; pad--)
				if(out < end)
					*out++ = '0';
		for(i = 0; i < n; i++)
			if(out < end)
				*out++ = b[i];
		for(; pad > 0; pad--)
			if(out < end)
				*out++ = ' ';
	}
	*out = 0;
	return out - buf;
}

int
snprint(char *buf, int len, char *fmt, ...)
{
	va_list args;
	int n;

	va_start(args, fmt);
	n = vsnprint(buf, len, fmt, args);
	va_end(args);
	return n;
}

int
sprint(char *buf, char *fmt, ...)
{
	va_list args;
	int n;

	va_start(args, fmt);
	n = vsnprint(buf, 65536, fmt, args);	/* big number, but sprint is deprecated anyway */
	va_end(args);
	return n;
}

/*
 * Reading
 */

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
