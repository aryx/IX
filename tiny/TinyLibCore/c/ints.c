/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A part of mini-ml's runtime: runtime.c includes it. */

/*****************************************************************************/
/* Int32 and Int64 */
/*****************************************************************************/

static value
copy_int32(int n)
{
	value b;

	b = ml_alloc(1, Int32_tag);
	Field(b, 0) = 0;
	Int32_val(b) = n;
	return b;
}

static value
copy_int64(vlong n)
{
	value b;

	b = ml_alloc(8 / W, Int64_tag);
	Int64_val(b) = n;
	return b;
}

/* the arithmetic unsigned, so that it wraps; the divisions and the
 * right shift signed */
#define U32(v) ((unsigned int)Int32_val(v))
#define U64(v) ((uvlong)Int64_val(v))

value int32_or(value a, value b) { return copy_int32(U32(a) | U32(b)); }
value int32_shift_left(value a, value n) { return copy_int32(U32(a) << Long_val(n)); }
value int32_shift_right_unsigned(value a, value n) { return copy_int32(U32(a) >> Long_val(n)); }
value int32_of_int(value n) { return copy_int32((int)Long_val(n)); }
value int32_to_int(value a) { return Val_int((value)Int32_val(a)); }
value int32_format(value fmt, value a) { return format_num(fmt, Int32_val(a), 32); }

value int64_neg(value a) { return copy_int64(-U64(a)); }
value int64_add(value a, value b) { return copy_int64(U64(a) + U64(b)); }
value int64_sub(value a, value b) { return copy_int64(U64(a) - U64(b)); }
value int64_mul(value a, value b) { return copy_int64(U64(a) * U64(b)); }
value int64_and(value a, value b) { return copy_int64(U64(a) & U64(b)); }
value int64_or(value a, value b) { return copy_int64(U64(a) | U64(b)); }
value int64_xor(value a, value b) { return copy_int64(U64(a) ^ U64(b)); }
value int64_shift_left(value a, value n) { return copy_int64(U64(a) << Long_val(n)); }
value int64_shift_right(value a, value n) { return copy_int64(Int64_val(a) >> Long_val(n)); }
value int64_shift_right_unsigned(value a, value n) { return copy_int64(U64(a) >> Long_val(n)); }
value int64_of_int(value n) { return copy_int64((vlong)Long_val(n)); }
value int64_to_int(value a) { return Val_int((value)Int64_val(a)); }
value int64_of_int32(value a) { return copy_int64((vlong)Int32_val(a)); }
value int64_to_int32(value a) { return copy_int32((int)Int64_val(a)); }
value int64_format(value fmt, value a) { return format_num(fmt, Int64_val(a), 64); }
value int64_of_string(value s) { return copy_int64(parse_int(s, "Int64.of_string")); }

/* A float's bits as an int64 and back: the block's 8 bytes, no float's
 * instruction (so on arm too: Pervasives' infinity and nan are made of
 * their bits when a program starts). An int32's are the single's that
 * the double rounds to. */
value int64_bits_of_float(value a) { return copy_int64(Int64_val(a)); }

value int64_float_of_bits(value a) { return copy_double_bits(Int64_val(a)); }

value
int32_bits_of_float(value a)
{
	float f;
	int n;

	f = Double_val(a);
	memmove(&n, &f, 4);
	return copy_int32(n);
}

value int64_of_float(value a) { return copy_int64((vlong)Double_val(a)); }
value int64_to_float(value a) { return copy_double((double)Int64_val(a)); }

value
int64_div(value a, value b)
{
	if(Int64_val(b) == 0)
		raise_const(caml_exn_Division_by_zero);
	return copy_int64(Int64_val(a) / Int64_val(b));
}

value
int64_mod(value a, value b)
{
	if(Int64_val(b) == 0)
		raise_const(caml_exn_Division_by_zero);
	return copy_int64(Int64_val(a) % Int64_val(b));
}
