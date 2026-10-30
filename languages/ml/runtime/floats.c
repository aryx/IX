/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A part of mini-ml's runtime: runtime.c includes it. */

/*****************************************************************************/
/* Floats: boxed, a block of the double's bits (phase 7; on arm64: on
 * arm, mini-ld encodes 5c's FPA, not the Pi's VFP) */
/*****************************************************************************/

/* what goken's libc lacks, from what it has (not glibc's to the last
 * bit); not static: the compiled code calls them on doubles (Lower's
 * float_calls) */
double ml_tan(double x) { return sin(x) / cos(x); }
double ml_sinh(double x) { return (exp(x) - exp(-x)) / 2; }
double ml_cosh(double x) { return (exp(x) + exp(-x)) / 2; }
/* (past 21 the two are infinities, their quotient a NaN: libc's tanh.c's bound) */
/* old: return ml_sinh(x) / ml_cosh(x): four calls of exp for two values.
 * The same operations on them, so the same bits; and 0 for 0 at once
 * (the quotient's value there): the mixer's soft limit is a tanh for
 * each sample, silence included, a tenth of a game's instructions on
 * mini-9pi (docs/notes/notes_profiling_techniques.md) */
double
ml_tanh(double x)
{
	double e, f;

	if(x > 21) return 1;
	if(x < -21) return -1;
	if(x == 0) return 0;
	e = exp(x);
	f = exp(-x);
	return ((e - f) / 2) / ((e + f) / 2);
}
double ml_fmod(double a, double b) { double i; modf(a / b, &i); return a - i * b; }

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

/* the compiled code's floor and ceil (ssa's Emit, its round): 2^52,
 * -2^52, 1.0, 0.0 */
double ml_round[4] = { 4503599627370496.0, -4503599627370496.0, 1.0, 0.0 };

/* OPTIMIZATION: within an int's range, floor is the processor's
 * conversion (it truncates toward 0) and one step down for a negative
 * number that is not whole; the C library's floor is modf's, a bit at a
 * time (the two, 5% of mini-doom's frame: its spans, its angles).
 * old: floor (and ceil) of the C library always */
static double
ml_floor(double x)
{
	double r;
	int i;

	if(x > -2147483648.0 && x < 2147483647.0){
		i = x;
		r = i;
		if(r > x)
			r -= 1.0;
		return r;
	}
	return floor(x);
}

value
floor_float(value a)
{
	return copy_double(signed_zero(ml_floor(Double_val(a)), Double_val(a)));
}

value
ceil_float(value a)
{
	return copy_double(signed_zero(-ml_floor(-Double_val(a)), Double_val(a)));
}
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

/* (OCaml's passes a number's underscores, 8_000_000.: so a constant of
 * a program's text, which mini-ml reads by this) */
/* old: strtod of the string itself, which stops at an underscore:
 * mini-ml built by mini-ml refused tiny/TinyMachine.ml's 8_000_000.
 * ("TinyMachine.ml: float_of_string", the fixed point's second build) */
value
float_of_string(value s)
{
	char buf[128], *end;
	double d;
	int i, n;

	n = 0;
	for(i = 0; i < length(s) && n < (int)sizeof buf - 1; i++)
		if(Bytes(s)[i] != '_')
			buf[n++] = Bytes(s)[i];
	buf[n] = 0;
	d = strtod(buf, &end);
	if(end != buf + n || n == 0 || i < length(s))
		failwith("float_of_string");
	return copy_double(d);
}

/* Float.Array: a block of doubles (Double_array_tag), made zeroed;
 * its floats read and written by the compiled code when it is ssa's
 * (Unbox), by these otherwise (simple's Gen). Its length as the
 * index's bound: OCaml's checks */
value
caml_floatarray_create(value n)
{
	value a, i;

	n = Long_val(n);
	if(n < 0 || (uvalue)n > Max_wosize / (sizeof(double) / W))
		raise_with(caml_exn_Invalid_argument, "Float.Array.create");
	if(n == 0)
		return (value)(caml_atom0 + 1);
	a = ml_alloc(n * (sizeof(double) / W), Double_array_tag);
	for(i = 0; i < n; i++)
		((double*)a)[i] = 0.0;
	return a;
}

value
ml_floatarray_length(value a)
{
	return Val_long(Double_array_length(a));
}

value
ml_floatarray_unsafe_get(value a, value i)
{
	return copy_double(((double*)a)[Long_val(i)]);
}

value
ml_floatarray_get(value a, value i)
{
	if((uvalue)Long_val(i) >= Double_array_length(a))
		caml_array_bound_error();
	return ml_floatarray_unsafe_get(a, i);
}

value
ml_floatarray_unsafe_set(value a, value i, value x)
{
	((double*)a)[Long_val(i)] = Double_val(x);
	return Val_unit;
}

value
ml_floatarray_set(value a, value i, value x)
{
	if((uvalue)Long_val(i) >= Double_array_length(a))
		caml_array_bound_error();
	return ml_floatarray_unsafe_set(a, i, x);
}
