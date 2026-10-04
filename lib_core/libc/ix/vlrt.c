/* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 */
/*
 * ix's own, NOT Plan 9's file: what arm's compiler calls for a vlong
 * (64 bits on a machine of 32), after Plan 9's port/vlrt.c (760 lines
 * in goken; see ../README.md), whose functions, names and algorithms
 * these are, written shorter and for a little-endian machine only.
 * The compiler (5c's com64.c, mini-cc's Com64) turns a + b into
 * _addv(&r, a, b), a cast into _sl2v or _v2sl, a += b on a char into
 * _vasop, and so on; the multiplication is arch/arm/vlop.s's.
 *
 * tests/vlrt.sh compares each with gcc's 64 bits on the host.
 */
typedef unsigned int	uint;
typedef unsigned short	ushort;
typedef unsigned char	uchar;
typedef signed char	schar;
typedef unsigned long	ulong;	/* 32 bits for Plan 9's compilers */

typedef struct Vlong Vlong;
struct Vlong
{
	ulong	lo;
	ulong	hi;
};

void	abort(void);

void _addv(Vlong *r, Vlong a, Vlong b) { r->lo = a.lo + b.lo; r->hi = a.hi + b.hi + (r->lo < a.lo); }
void _subv(Vlong *r, Vlong a, Vlong b) { r->lo = a.lo - b.lo; r->hi = a.hi - b.hi - (r->lo > a.lo); }
void _andv(Vlong *r, Vlong a, Vlong b) { r->hi = a.hi & b.hi; r->lo = a.lo & b.lo; }
void _orv(Vlong *r, Vlong a, Vlong b) { r->hi = a.hi | b.hi; r->lo = a.lo | b.lo; }
void _xorv(Vlong *r, Vlong a, Vlong b) { r->hi = a.hi ^ b.hi; r->lo = a.lo ^ b.lo; }

static void
vneg(Vlong *v)
{
	v->hi = v->lo == 0 ? -v->hi : ~v->hi;
	v->lo = -v->lo;
}

/*
 * Shifts (by 32 or more, or by 0: not left to the machine's)
 */
void
_lshv(Vlong *r, Vlong a, int b)
{
	if(b >= 32){
		r->hi = b >= 64 ? 0 : a.lo << (b-32);
		r->lo = 0;
	}else if(b <= 0)
		*r = a;
	else{
		r->hi = (a.lo >> (32-b)) | (a.hi << b);
		r->lo = a.lo << b;
	}
}

void
_rshlv(Vlong *r, Vlong a, int b)
{
	if(b >= 32){
		r->lo = b >= 64 ? 0 : a.hi >> (b-32);
		r->hi = 0;
	}else if(b <= 0)
		*r = a;
	else{
		r->lo = (a.hi << (32-b)) | (a.lo >> b);
		r->hi = a.hi >> b;
	}
}

void
_rshav(Vlong *r, Vlong a, int b)
{
	long t;

	t = a.hi;
	if(b >= 32){
		r->lo = b >= 64 ? t >> 31 : t >> (b-32);
		r->hi = t >> 31;
	}else if(b <= 0)
		*r = a;
	else{
		r->lo = (t << (32-b)) | (a.lo >> b);
		r->hi = t >> b;
	}
}

/*
 * Divisions: by shifts and subtractions, a bit of the quotient at a time
 */
static void
dodiv(Vlong num, Vlong den, Vlong *q, Vlong *r)
{
	ulong numlo, numhi, denhi, denlo, quohi, quolo, t;
	int i;

	numhi = num.hi;
	numlo = num.lo;
	denhi = den.hi;
	denlo = den.lo;
	if(denlo == 0 && denhi == 0)	/* get a divide by zero */
		numlo = numlo / denlo;

	/* the divisor shifted up to the dividend: the number of iterations */
	if(numhi >= 1UL<<31){
		quohi = 1UL<<31;
		quolo = 0;
	}else{
		quohi = numhi;
		quolo = numlo;
	}
	i = 0;
	while(denhi < quohi || (denhi == quohi && denlo < quolo)){
		denhi = (denhi<<1) | (denlo>>31);
		denlo <<= 1;
		i++;
	}

	quohi = 0;
	quolo = 0;
	for(; i >= 0; i--){
		quohi = (quohi<<1) | (quolo>>31);
		quolo <<= 1;
		if(numhi > denhi || (numhi == denhi && numlo >= denlo)){
			t = numlo;
			numlo -= denlo;
			if(numlo > t)
				numhi--;
			numhi -= denhi;
			quolo |= 1;
		}
		denlo = (denlo>>1) | (denhi<<31);
		denhi >>= 1;
	}
	if(q){
		q->lo = quolo;
		q->hi = quohi;
	}
	if(r){
		r->lo = numlo;
		r->hi = numhi;
	}
}

void
_divvu(Vlong *q, Vlong n, Vlong d)
{
	if(n.hi == 0 && d.hi == 0){
		q->hi = 0;
		q->lo = n.lo / d.lo;
	}else
		dodiv(n, d, q, 0);
}

void
_modvu(Vlong *r, Vlong n, Vlong d)
{
	if(n.hi == 0 && d.hi == 0){
		r->hi = 0;
		r->lo = n.lo % d.lo;
	}else
		dodiv(n, d, 0, r);
}

/* signed: of the absolute values; the quotient's sign is the signs'
 * product, the remainder's the dividend's */
static void
sdiv(Vlong n, Vlong d, Vlong *q, Vlong *r)
{
	long nneg, dneg;

	nneg = n.hi >> 31;
	if(nneg)
		vneg(&n);
	dneg = d.hi >> 31;
	if(dneg)
		vneg(&d);
	dodiv(n, d, q, r);
	if(q && nneg != dneg)
		vneg(q);
	if(r && nneg)
		vneg(r);
}

void
_divv(Vlong *q, Vlong n, Vlong d)
{
	if(n.hi == (((long)n.lo)>>31) && d.hi == (((long)d.lo)>>31)){
		q->lo = (long)n.lo / (long)d.lo;
		q->hi = ((long)q->lo) >> 31;
	}else
		sdiv(n, d, q, 0);
}

void
_modv(Vlong *r, Vlong n, Vlong d)
{
	if(n.hi == (((long)n.lo)>>31) && d.hi == (((long)d.lo)>>31)){
		r->lo = (long)n.lo % (long)d.lo;
		r->hi = ((long)r->lo) >> 31;
	}else
		sdiv(n, d, 0, r);
}

/*
 * x++, x--, ++x, --x: l the expression's value, r the variable
 */
void _vpp(Vlong *l, Vlong *r) { *l = *r; if(++r->lo == 0) r->hi++; }
void _vmm(Vlong *l, Vlong *r) { *l = *r; if(r->lo-- == 0) r->hi--; }
void _ppv(Vlong *l, Vlong *r) { if(++r->lo == 0) r->hi++; *l = *r; }
void _mmv(Vlong *l, Vlong *r) { if(r->lo-- == 0) r->hi--; *l = *r; }

/* lv op= rv where lv is of another type: 1 schar, 2 uchar, 3 short,
 * 4 ushort, 5 long, 6 ulong, 7 vlong, 8 uvlong, 9 int, 10 uint (the
 * odd ones signed) */
void
_vasop(Vlong *ret, void *lv, void fn(Vlong*, Vlong, Vlong), int type, Vlong rv)
{
	Vlong t, u;

	u = *ret;
	switch(type){
	default: abort(); break;
	case 1: t.lo = *(schar*)lv; break;
	case 2: t.lo = *(uchar*)lv; break;
	case 3: t.lo = *(short*)lv; break;
	case 4: t.lo = *(ushort*)lv; break;
	case 5: case 9: t.lo = *(long*)lv; break;
	case 6: case 10: t.lo = *(ulong*)lv; break;
	case 7: case 8: t = *(Vlong*)lv; break;
	}
	if(type != 7 && type != 8)
		t.hi = type & 1 ? (long)t.lo >> 31 : 0;
	fn(&u, t, rv);
	switch(type){
	case 1: case 2: *(uchar*)lv = u.lo; break;
	case 3: case 4: *(ushort*)lv = u.lo; break;
	case 7: case 8: *(Vlong*)lv = u; break;
	default: *(ulong*)lv = u.lo; break;
	}
	*ret = u;
}

/*
 * Conversions
 */
void _sl2v(Vlong *ret, long sl) { ret->lo = sl; ret->hi = sl >> 31; }
void _ul2v(Vlong *ret, ulong ul) { ret->lo = ul; ret->hi = 0; }
void _si2v(Vlong *ret, int si) { _sl2v(ret, si); }
void _ui2v(Vlong *ret, uint ui) { _ul2v(ret, ui); }
void _p2v(Vlong *ret, void *p) { _ul2v(ret, (ulong)p); }
void _sh2v(Vlong *ret, long sh) { _sl2v(ret, (sh << 16) >> 16); }
void _uh2v(Vlong *ret, ulong ul) { _ul2v(ret, ul & 0xffff); }
void _sc2v(Vlong *ret, long sc) { _sl2v(ret, (sc << 24) >> 24); }
void _uc2v(Vlong *ret, ulong ul) { _ul2v(ret, ul & 0xff); }

long _v2sc(Vlong rv) { return (long)(rv.lo << 24) >> 24; }
long _v2uc(Vlong rv) { return rv.lo & 0xff; }
long _v2sh(Vlong rv) { return (long)(rv.lo << 16) >> 16; }
long _v2uh(Vlong rv) { return rv.lo & 0xffff; }
long _v2sl(Vlong rv) { return rv.lo; }
long _v2ul(Vlong rv) { return rv.lo; }
long _v2si(Vlong rv) { return rv.lo; }
long _v2ui(Vlong rv) { return rv.lo; }

/* a double's 53 bits shifted to the integer's place */
void
_d2v(Vlong *y, double d)
{
	union { double d; struct Vlong; } x;
	ulong xhi, xlo, ylo, yhi;
	int sh;

	x.d = d;
	xhi = (x.hi & 0xfffff) | 0x100000;
	xlo = x.lo;
	sh = 1075 - ((x.hi >> 20) & 0x7ff);
	ylo = 0;
	yhi = 0;
	if(sh == 0){
		ylo = xlo;
		yhi = xhi;
	}else if(sh > 0 && sh < 32){
		ylo = (xlo >> sh) | (xhi << (32-sh));
		yhi = xhi >> sh;
	}else if(sh >= 32 && sh < 64)
		ylo = xhi >> (sh-32);
	else if(sh < 0 && sh >= -10){
		ylo = xlo << -sh;
		yhi = (xhi << -sh) | (xlo >> (32+sh));
	}else if(sh < 0)
		yhi = d;	/* overflow: causes something awful */
	y->hi = yhi;
	y->lo = ylo;
	if(x.hi & (1UL<<31))
		vneg(y);
}

void _f2v(Vlong *y, float f) { _d2v(y, f); }

double
_v2d(Vlong x)
{
	if(x.hi & (1UL<<31)){
		vneg(&x);
		/* (hi unsigned: the smallest vlong is its own opposite; Plan 9's
		 * has (long)x.hi here, and gives 2^63 for -2^63) */
		return -(x.hi*4294967296. + x.lo);
	}
	return (long)x.hi*4294967296. + x.lo;
}

float _v2f(Vlong x) { return _v2d(x); }

/*
 * Comparisons: lt, le, gt, ge signed; lo, ls, hi, hs unsigned
 */
int _testv(Vlong rv) { return rv.lo || rv.hi; }
int _eqv(Vlong lv, Vlong rv) { return lv.lo == rv.lo && lv.hi == rv.hi; }
int _nev(Vlong lv, Vlong rv) { return lv.lo != rv.lo || lv.hi != rv.hi; }
int _ltv(Vlong lv, Vlong rv) { return (long)lv.hi < (long)rv.hi || (lv.hi == rv.hi && lv.lo < rv.lo); }
int _lev(Vlong lv, Vlong rv) { return (long)lv.hi < (long)rv.hi || (lv.hi == rv.hi && lv.lo <= rv.lo); }
int _gtv(Vlong lv, Vlong rv) { return (long)lv.hi > (long)rv.hi || (lv.hi == rv.hi && lv.lo > rv.lo); }
int _gev(Vlong lv, Vlong rv) { return (long)lv.hi > (long)rv.hi || (lv.hi == rv.hi && lv.lo >= rv.lo); }
int _lov(Vlong lv, Vlong rv) { return lv.hi < rv.hi || (lv.hi == rv.hi && lv.lo < rv.lo); }
int _lsv(Vlong lv, Vlong rv) { return lv.hi < rv.hi || (lv.hi == rv.hi && lv.lo <= rv.lo); }
int _hiv(Vlong lv, Vlong rv) { return lv.hi > rv.hi || (lv.hi == rv.hi && lv.lo > rv.lo); }
int _hsv(Vlong lv, Vlong rv) { return lv.hi > rv.hi || (lv.hi == rv.hi && lv.lo >= rv.lo); }
