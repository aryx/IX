/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A part of mini-ml's runtime: runtime.c includes it. */

/*****************************************************************************/
/* Floats: boxed, a block of the double's bits (phase 7; on arm64: on
 * arm, mini-ld encodes 5c's FPA, not the Pi's VFP) */
/*****************************************************************************/

/* what goken's libc lacks, from what it has (not glibc's to the last
 * bit) */
static double ml_tan(double x) { return sin(x) / cos(x); }
static double ml_sinh(double x) { return (exp(x) - exp(-x)) / 2; }
static double ml_cosh(double x) { return (exp(x) + exp(-x)) / 2; }
/* (past 21 the two are infinities, their quotient a NaN: libc's tanh.c's bound) */
static double ml_tanh(double x) { if(x > 21) return 1; if(x < -21) return -1; return ml_sinh(x) / ml_cosh(x); }
static double ml_fmod(double a, double b) { double i; modf(a / b, &i); return a - i * b; }

static value
copy_double(double d)
{
	value b;

	b = ml_alloc(sizeof(double) / W, Double_tag);
	*(double*)b = d;
	return b;
}

/* a float of its 64 bits: no float's instruction */
static value
copy_double_bits(vlong n)
{
	value b;

	b = ml_alloc(sizeof(double) / W, Double_tag);
	Int64_val(b) = n;
	return b;
}

/* on the sign's bit: a zero's and a nan's too, which 0 - x and x < 0 miss */
#define Sign ((vlong)1 << 63)
value caml_negfloat(value a) { return copy_double_bits(Int64_val(a) ^ Sign); }
value caml_absfloat(value a) { return copy_double_bits(Int64_val(a) & ~Sign); }
value caml_floatofint(value n) { return copy_double((double)Long_val(n)); }
value caml_intoffloat(value a) { return Val_int((value)Double_val(a)); }
value caml_addfloat(value a, value b) { return copy_double(Double_val(a) + Double_val(b)); }
value caml_subfloat(value a, value b) { return copy_double(Double_val(a) - Double_val(b)); }
value caml_mulfloat(value a, value b) { return copy_double(Double_val(a) * Double_val(b)); }
value caml_divfloat(value a, value b) { return copy_double(Double_val(a) / Double_val(b)); }
value exp_float(value a) { return copy_double(exp(Double_val(a))); }
value log_float(value a) { return copy_double(log(Double_val(a))); }
value log10_float(value a) { return copy_double(log10(Double_val(a))); }
/* (ml_fsqrt is the start object's: the processor's instruction, on arm64) */
value sqrt_float(value a) { return copy_double(ml_fsqrt(Double_val(a))); }
value sin_float(value a) { return copy_double(sin(Double_val(a))); }
value cos_float(value a) { return copy_double(cos(Double_val(a))); }
value tan_float(value a) { return copy_double(ml_tan(Double_val(a))); }
value asin_float(value a) { return copy_double(asin(Double_val(a))); }
value acos_float(value a) { return copy_double(acos(Double_val(a))); }
value atan_float(value a) { return copy_double(atan(Double_val(a))); }
value sinh_float(value a) { return copy_double(ml_sinh(Double_val(a))); }
value cosh_float(value a) { return copy_double(ml_cosh(Double_val(a))); }
value tanh_float(value a) { return copy_double(ml_tanh(Double_val(a))); }
/* a zero result with its argument's sign, as C's (goken's give 0.0:
 * ceil -0.3 is -0.0, floor -0.0 is -0.0) */
static double
signed_zero(double r, double x)
{
	if(r == 0 && *(vlong*)&x < 0)
		*(vlong*)&r = Sign;
	return r;
}

value ceil_float(value a) { return copy_double(signed_zero(ceil(Double_val(a)), Double_val(a))); }
value floor_float(value a) { return copy_double(signed_zero(floor(Double_val(a)), Double_val(a))); }
value atan2_float(value a, value b) { return copy_double(atan2(Double_val(a), Double_val(b))); }
value power_float(value a, value b) { return copy_double(pow(Double_val(a), Double_val(b))); }
value fmod_float(value a, value b) { return copy_double(ml_fmod(Double_val(a), Double_val(b))); }
value ldexp_float(value a, value n) { return copy_double(ldexp(Double_val(a), Long_val(n))); }

/* a pair of the result's parts: frexp's and modf's */
static value
pair(value a, value b)
{
	value r;

	push(a);
	push(b);
	r = ml_alloc(2, 0);
	Field(r, 1) = pop();
	Field(r, 0) = pop();
	return r;
}

value
frexp_float(value a)
{
	int e;
	double m;

	m = frexp(Double_val(a), &e);
	return pair(copy_double(m), Val_int(e));
}

value
modf_float(value a)
{
	double i, f;
	value fv;

	f = modf(Double_val(a), &i);
	fv = copy_double(f);
	push(fv);
	fv = copy_double(i);
	return pair(pop(), fv);
}

/* printf's floats, by libc's formatter: OCaml's format is C's */
value
format_float(value fmt, value a)
{
	char buf[512];	/* 1e308 by %f is 309 digits */

	snprint(buf, sizeof buf, (char*)Bytes(fmt), Double_val(a));
	return ml_string(buf);
}

value
float_of_string(value s)
{
	char *end;
	double d;

	d = strtod((char*)Bytes(s), &end);
	if(end != (char*)Bytes(s) + length(s) || length(s) == 0)
		failwith("float_of_string");
	return copy_double(d);
}
