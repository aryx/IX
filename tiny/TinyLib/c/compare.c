/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A part of mini-ml's runtime: runtime.c includes it. */

/*****************************************************************************/
/* compare and hash */
/*****************************************************************************/

/* OCaml's compare: integers before blocks, then the tags, strings by
 * their bytes, the other blocks by their sizes then their fields.
 * Floats have two orders. compare's is total: a nan equal to itself and
 * below the others. The relations' (=, <...) is IEEE's: a nan is
 * unordered with any float, itself too, which cmp_unordered says, and
 * then no relation holds but <>; so there a value is not known equal
 * to itself before its floats are looked at. */
static int cmp_total, cmp_unordered;

static value
cmp(value a, value b)
{
	value ta, tb, n, m, i, c;
	double x, y;

top:
	if(a == b && cmp_total)
		return 0;
	if(Is_int(a)){
		if(Is_int(b))
			return a < b ? -1 : a > b;
		return -1;
	}
	if(Is_int(b))
		return 1;
	ta = Tag(a);
	tb = Tag(b);
	if(ta != tb)
		return ta < tb ? -1 : 1;
	if(ta == String_tag){
		n = length(a);
		m = length(b);
		for(i = 0; i < n && i < m; i++)
			if(Bytes(a)[i] != Bytes(b)[i])
				return Bytes(a)[i] < Bytes(b)[i] ? -1 : 1;
		return n < m ? -1 : n > m ? 1 : 0;
	}
	if(ta == Double_tag){
		x = Double_val(a);
		y = Double_val(b);
		if(x < y) return -1;
		if(x > y) return 1;
		if(x == y) return 0;
		if(!cmp_total){
			cmp_unordered = 1;
			return 1;
		}
		return x == x ? 1 : y == y ? -1 : 0;
	}
	if(ta == Int64_tag)
		return Int64_val(a) < Int64_val(b) ? -1 : Int64_val(a) > Int64_val(b) ? 1 : 0;
	if(ta == Int32_tag)
		return Int32_val(a) < Int32_val(b) ? -1 : Int32_val(a) > Int32_val(b) ? 1 : 0;
	if(ta == Closure_tag)
		raise_with(caml_exn_Invalid_argument, "equal: functional value");
	n = Wosize(a);
	m = Wosize(b);
	if(n != m)
		return n < m ? -1 : 1;
	if(n == 0)
		return 0;
	for(i = 0; i < n - 1; i++){
		c = cmp(Field(a, i), Field(b, i));
		if(c != 0)
			return c;
	}
	/* the last field without a call: a long list is not a deep stack */
	a = Field(a, n - 1);
	b = Field(b, n - 1);
	goto top;
}

value
compare(value a, value b)
{
	cmp_total = 1;
	return Val_int(cmp(a, b));
}

/* the relations, of two values not both integers (the compiled code
 * compares those) */
static value
relation(value a, value b)
{
	cmp_total = 0;
	cmp_unordered = 0;
	return cmp(a, b);
}

value ml_equal(value a, value b) { return Val_bool(relation(a, b) == 0 && !cmp_unordered); }
value ml_notequal(value a, value b) { return Val_bool(relation(a, b) != 0 || cmp_unordered); }
value ml_lessthan(value a, value b) { return Val_bool(relation(a, b) < 0 && !cmp_unordered); }
value ml_lessequal(value a, value b) { return Val_bool(relation(a, b) <= 0 && !cmp_unordered); }
value ml_greaterthan(value a, value b) { return Val_bool(relation(a, b) > 0 && !cmp_unordered); }
value ml_greaterequal(value a, value b) { return Val_bool(relation(a, b) >= 0 && !cmp_unordered); }

/* Hashtbl.hash: a bounded walk, breadth first, as ocaml-light's hash.c
 * (count meaningful values, limit visited at most) */
static uvalue hash_acc;
static value hash_count, hash_limit;

#define Alpha 65599
#define Beta 19

static void
hash_rec(value v)
{
	value i;

	hash_limit--;
	if(hash_count < 0 || hash_limit < 0)
		return;
	if(Is_int(v)){
		hash_count--;
		hash_acc = hash_acc * Alpha + Long_val(v);
		return;
	}
	switch(Tag(v)){
	case String_tag:
		hash_count--;
		for(i = length(v) - 1; i >= 0; i--)
			hash_acc = hash_acc * Alpha + Bytes(v)[i];
		break;
	case Double_tag:
		hash_count--;
		for(i = W - 1; i >= 0; i--)
			hash_acc = hash_acc * Alpha + Bytes(v)[i];
		break;
	case Int32_tag:
	case Int64_tag:
		hash_count--;
		for(i = (Tag(v) == Int64_tag ? 8 : 4) - 1; i >= 0; i--)
			hash_acc = hash_acc * Alpha + Bytes(v)[i];
		break;
	case Closure_tag:
		hash_count--;
		break;
	default:
		hash_count--;
		hash_acc = hash_acc * Beta + Tag(v);
		for(i = Wosize(v) - 1; i >= 0; i--)
			hash_rec(Field(v, i));
		break;
	}
}

value
hash_univ_param(value count, value limit, value obj)
{
	hash_acc = 0;
	hash_count = Long_val(count);
	hash_limit = Long_val(limit);
	hash_rec(obj);
	return Val_int(hash_acc & (((uvalue)1 << (8 * W - 2)) - 1));
}
