/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A part of mini-ml's runtime: runtime.c includes it. */

/*****************************************************************************/
/* Floats: boxed, a block of the double's bits (phase 7; on arm64: on
 * arm, mini-ld encodes 5c's FPA, not the Pi's VFP) */
/*****************************************************************************/

/* (past 21 the two are infinities, their quotient a NaN: libc's tanh.c's bound) */

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
/* (ml_fsqrt is the start object's: the processor's instruction, on arm64) */
/* a zero result with its argument's sign, as C's (goken's give 0.0:
 * ceil -0.3 is -0.0, floor -0.0 is -0.0) */
static double
signed_zero(double r, double x)
{
	if(r == 0 && *(vlong*)&x < 0)
		*(vlong*)&r = Sign;
	return r;
}

value floor_float(value a) { return copy_double(signed_zero(floor(Double_val(a)), Double_val(a))); }

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
