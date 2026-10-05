/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* mini-ml's runtime (plan_ml.md, decision 5; the tutorial's section
 * 11), in C for mini-cc and goken's libc, on arm and arm64: the
 * allocator and Cheney's copying collector, the primitives the stdlib
 * names, the channels, the uncaught exception, and main. No assembly:
 * the code mini-ml generates calls ml_alloc and the others with 5c's
 * and 7c's convention, and main calls ml_start (the start object's).
 *
 * A value is a word: an integer n as 2n+1, or the address of a block's
 * first field, the block's header the word before it (its size in
 * words << 10, its tag in the low byte: 247 a closure, 252 a string,
 * 253 a float, whose fields hold no value). The roots: the value
 * stack, from its base to ml_vsp (the ML code stores its top there
 * before calling C), and the units' globals (ml_units, the start
 * object's table of each unit's). A C function that allocates pushes
 * its values on the value stack first, and reads them back: the
 * collector moves them. A static block (a string, a closure, an
 * exception) is outside the heap, and the collector leaves it.
 *
 * ocaml-light's names are kept (format_int, make_vect, caml_flush...),
 * and its behavior on arm64, the contract: stdout's buffer is 4096
 * bytes, flushed by flush and at exit, lost on an uncaught exception;
 * an index out of bounds a fatal error. Floats are for phase 7: their
 * primitives here fail when called. */

#include "mlvalues.h"
#include "memory.h"

extern void ml_start(value*);
extern void ml_raise(value);
extern value ml_callback(value, value);
#ifndef __GNUC__
extern double ml_fsqrt(double);
#endif
extern value ml_units[];

value *ml_vsp;
void *ml_handler;

void failwith(char*);
static void raise_with(value*, char*);
static void raise_const(value*);

static void
fatal(char *msg)
{
	write(2, msg, strlen(msg));
	exit(2);
}

static void
unsupported(char *what)
{
	write(2, "mini-ml: ", 9);
	write(2, what, strlen(what));
	fatal(": not in the runtime yet\n");
}

/*****************************************************************************/
/* The heap: two halves in the bss, Cheney's collector */
/*****************************************************************************/

/* a half's words, at most: 512 MB on 64 bits (a link of ix's is 200 MB
 * of blocks), 256 on 32 (it was 32: mini-ld built for arm could not
 * link itself). They are the bss: the pages not touched are not
 * memory. (A kernel gives its own, -DMAXHEAP and -DSTACK: its bss is
 * the board's memory, cleared at the start.) */
#ifndef MAXHEAP
#define MAXHEAP 67108864
#define STACK 4194304           /* the value stack's */
#endif
/* a half's words at the start (ML_HEAP says another); it doubles when
 * less than half is free after a collection */
#ifndef HEAPSTART
#define HEAPSTART (1 << 18)
#endif

static value space0[MAXHEAP];
static value space1[MAXHEAP];
static value vstack[STACK];
static value *from;             /* the heap: from..limit, allocated up to hp */
static value *other;
static value *hp;
static value *limit;
static value size;
static value *lo;               /* the collector's: the space collected, */
static value *hi;
static value *next;             /* and where the next copy goes */

/* An index out of bounds: OCaml's Invalid_argument "index out of
 * bounds", which a program may catch (tiny-cpu's search of a table
 * does). Made once, at the start, and kept as a root: the generated
 * code calls here without saying where the value stack's top is, so
 * nothing may be allocated now. */
/* old: fatal("Fatal error: out-of-bound access in array or string\n"),
 * as ocaml-light's ocamlopt on arm64 */
static value bound_exn;

/* the named values of Callback.register, roots too */
#define NAMED 64
static value named_names[NAMED];
static value named_values[NAMED];
static int nnamed;

/* The value stacks. A program has one, vstack. A kernel's processes
 * each have theirs (plan_kernel_mini_ml.md: "a process is two
 * pointers"): the kernel gives each a number and its memory
 * (ml_stack), and says which one runs (ml_stack_switch: the top and
 * the handler of the one that stops are kept, those of the other put
 * back; the kernel switches the machine's stack, and the register that
 * holds the top in ML's code). The collector scans them all. */
#define STACKS 65
static value *stack_base[STACKS];
static value *stack_top[STACKS];
static void *stack_handler[STACKS];
static struct caml__roots_block *stack_roots[STACKS];
static int stack_now;

/* C's own values (memory.h's CAMLparam and CAMLlocal, ocaml-light's): a
 * C function that allocates, or calls ML, while it holds values says
 * where they are, in a block on its frame, chained here; the collector
 * moves them. A chain per stack: a process's C frames are its own. */
struct caml__roots_block *local_roots;

void
ml_root(struct caml__roots_block *b, value *v0, value *v1, value *v2)
{
	b->next = local_roots;
	b->v[0] = v0;
	b->v[1] = v1;
	b->v[2] = v2;
	local_roots = b;
}

void
ml_stack(int i, value *base)
{
	stack_base[i] = base;
	stack_top[i] = base;
	stack_handler[i] = nil;
	stack_roots[i] = nil;
}

void
ml_stack_switch(int i)
{
	stack_top[stack_now] = ml_vsp;
	stack_handler[stack_now] = ml_handler;
	stack_roots[stack_now] = local_roots;
	stack_now = i;
	ml_vsp = stack_top[i];
	ml_handler = stack_handler[i];
	local_roots = stack_roots[i];
}

/* a value's copy in to-space: an integer or a pointer outside the space
 * collected as is; a copied block's header is 0, its first field the
 * copy's address (every block has a field: an empty array is static) */
static value
copy(value v)
{
	value *p, *q;
	value h, n, i;

	p = (value*)v;
	if(Is_int(v) || p < lo || p >= hi)
		return v;
	h = p[-1];
	if(h == 0)
		return p[0];
	n = ((uvalue)h) >> 10;
	q = next + 1;
	q[-1] = h;
	for(i = 0; i < n; i++)
		q[i] = p[i];
	next = q + n;
	p[-1] = 0;
	p[0] = (value)q;
	return (value)q;
}

/* the roots copied, then the copies scanned, breadth first, scan
 * chasing next; the halves swapped */
static void
collect(void)
{
	value *scan, *v, *roots;
	value n, i, u, h;
	struct caml__roots_block *b;

	lo = from;
	hi = limit;
	next = other;
	stack_top[stack_now] = ml_vsp;
	stack_roots[stack_now] = local_roots;
	for(i = 0; i < STACKS; i++){
		for(v = stack_base[i]; v < stack_top[i]; v++)
			*v = copy(*v);
		for(b = stack_roots[i]; b != nil; b = b->next)
			for(u = 0; u < 3; u++)
				if(b->v[u] != nil)
					*b->v[u] = copy(*b->v[u]);
	}
	for(u = 1; u <= ml_units[0]; u++){
		roots = (value*)ml_units[u];
		for(i = 1; i <= roots[0]; i++){
			v = (value*)roots[i];
			*v = copy(*v);
		}
	}
	bound_exn = copy(bound_exn);
	for(i = 0; i < nnamed; i++){
		named_names[i] = copy(named_names[i]);
		named_values[i] = copy(named_values[i]);
	}
	for(scan = other; scan < next; scan = scan + n + 1){
		h = *scan;
		n = ((uvalue)h) >> 10;
		if((h & 255) < 251)
			for(i = 1; i <= n; i++)
				scan[i] = copy(scan[i]);
	}
	other = from;
	from = lo == space0 ? space1 : space0;
	hp = next;
}

/* if less than half is free after, the heap grows, up to its halves */
static void
gc(value need)
{
	collect();
	while((hp - from + need) * 2 > size && size < MAXHEAP)
		size = size * 2;
	if(size > MAXHEAP)
		size = MAXHEAP;
	limit = from + size;
	if(hp + need > limit)
		fatal("Fatal error: out of memory\n");
}

/* Gc's: a collection, whichever was asked */
value gc_full_major(value u) { gc(0); return u; }
value gc_major(value u) { gc(0); return u; }
value gc_minor(value u) { gc(0); return u; }
value gc_compaction(value u) { gc(0); return u; }

value
ml_alloc(value n, value tag)
{
	value *p;

	if(hp + n + 1 > limit)
		gc(n + 1);
	p = hp + 1;
	p[-1] = (n << 10) | tag;
	hp = p + n;
	return (value)p;
}

static void
push(value v)
{
	*ml_vsp = v;
	ml_vsp++;
}

static value
pop(void)
{
	ml_vsp--;
	return *ml_vsp;
}

/*****************************************************************************/
/* Strings: the last byte the number of padding bytes before it */
/*****************************************************************************/

static value
string_alloc(value len)
{
	value w, s;

	w = len / W + 1;
	s = ml_alloc(w, String_tag);
	Field(s, w - 1) = 0;
	Bytes(s)[w * W - 1] = w * W - 1 - len;
	return s;
}

static value
length(value s)
{
	return Wosize(s) * W - 1 - Bytes(s)[Wosize(s) * W - 1];
}

/* a C string as an ML one */
value
ml_string(char *s)
{
	value r, n;

	n = strlen(s);
	r = string_alloc(n);
	memmove(Bytes(r), s, n);
	return r;
}

value
ml_string_length(value s)
{
	return Val_int(length(s));
}

static void
bound(value s, value i)
{
	if(i < 0 || i >= length(s))
		ml_raise(bound_exn);
}

value
ml_string_get(value s, value i)
{
	bound(s, Long_val(i));
	return Val_int(Bytes(s)[Long_val(i)]);
}

value
ml_string_set(value s, value i, value c)
{
	bound(s, Long_val(i));
	Bytes(s)[Long_val(i)] = Long_val(c);
	return Val_unit;
}

void
caml_array_bound_error(void)
{
	ml_raise(bound_exn);
}

value
create_string(value n)
{
	return string_alloc(Long_val(n));
}

value
blit_string(value s1, value o1, value s2, value o2, value n)
{
	memmove(Bytes(s2) + Long_val(o2), Bytes(s1) + Long_val(o1), Long_val(n));
	return Val_unit;
}

value
fill_string(value s, value o, value n, value c)
{
	value i;

	for(i = 0; i < Long_val(n); i++)
		Bytes(s)[Long_val(o) + i] = Long_val(c);
	return Val_unit;
}

value
is_printable(value c)
{
	c = Long_val(c);
	return Val_bool(c >= 32 && c < 127);
}

value
caml_string_equal(value a, value b)
{
	value n;

	n = length(a);
	if(n != length(b))
		return Val_false;
	return Val_bool(memcmp(Bytes(a), Bytes(b), n) == 0);
}

/* n's digits, in base b, at the end of buf; where they start */
static int
digits(uvalue n, int b, int upper, char *buf, int end)
{
	int d;

	do {
		d = n % b;
		buf[--end] = d < 10 ? '0' + d : (upper ? 'A' : 'a') + d - 10;
		n = n / b;
	} while(n != 0);
	return end;
}

/* the same for what a word doesn't hold: an int64 on arm */
static int
digits64(uvlong n, int b, int upper, char *buf, int end)
{
	int d;

	do {
		d = n % b;
		buf[--end] = d < 10 ? '0' + d : (upper ? 'A' : 'a') + d - 10;
		n = n / b;
	} while(n != 0);
	return end;
}

/* printf's integers: %[-0 +]width[d i u x X o], as C's; n of bits bits
 * when it is printed unsigned: 31 or 63 an int's, as ocaml-light's,
 * 32 and 64 an int32's and an int64's */
static value
format_num(value fmt, vlong n, int bits)
{
	char buf[96];
	uchar *f;
	int i, start, left, zero, sign, space, width, neg, b, upper, len, pad, k;
	uvlong u;

	f = Bytes(fmt);
	left = zero = sign = space = width = 0;
	for(i = 1; f[i] == '-' || f[i] == '0' || f[i] == '+' || f[i] == ' '; i++)
		switch(f[i]){
		case '-': left = 1; break;
		case '0': zero = 1; break;
		case '+': sign = 1; break;
		case ' ': space = 1; break;
		}
	while(f[i] >= '0' && f[i] <= '9')
		width = width * 10 + f[i++] - '0';
	while(f[i] == 'l' || f[i] == 'n' || f[i] == 'L')
		i++;
	b = 10; upper = 0; neg = 0;
	switch(f[i]){
	case 'x': b = 16; break;
	case 'X': b = 16; upper = 1; break;
	case 'o': b = 8; break;
	}
	if((f[i] == 'd' || f[i] == 'i') && n < 0){
		neg = 1;
		u = -(uvlong)n;
	}else if((b != 10 || f[i] == 'u') && bits < 64)
		u = (uvlong)n & (((uvlong)1 << bits) - 1);
	else
		u = n;
	start = u == (uvalue)u ? digits(u, b, upper, buf, 64) : digits64(u, b, upper, buf, 64);
	if(neg)
		buf[--start] = '-';
	else if(sign)
		buf[--start] = '+';
	else if(space)
		buf[--start] = ' ';
	len = 64 - start;
	pad = width > len ? width - len : 0;
	k = 0;
	if(pad > 0 && !left && !zero)
		for(; k < pad; k++) buf[k] = ' ';
	if(pad > 0 && zero && !left){
		/* the sign first, then the zeros */
		if(neg || sign || space){
			buf[k++] = buf[start++];
			len--;
		}
		for(i = 0; i < pad; i++) buf[k++] = '0';
	}
	memmove(buf + k, buf + start, len);
	k += len;
	if(pad > 0 && left)
		for(i = 0; i < pad; i++) buf[k++] = ' ';
	buf[k] = 0;
	return ml_string(buf);
}

value format_int(value fmt, value arg) { return format_num(fmt, Long_val(arg), 8 * W - 1); }

/* an integer's value: -, then 0x 0o 0b or decimal, _ between digits;
 * who is the function that fails */
static vlong
parse_int(value s, char *who)
{
	uchar *p;
	value neg, b, d, len, i;
	uvlong n;

	p = Bytes(s);
	len = length(s);
	i = 0; neg = 0; n = 0; b = 10;
	if(i < len && p[i] == '-'){ neg = 1; i++; }
	if(i + 1 < len && p[i] == '0'){
		switch(p[i + 1]){
		case 'x': case 'X': b = 16; i += 2; break;
		case 'o': case 'O': b = 8; i += 2; break;
		case 'b': case 'B': b = 2; i += 2; break;
		}
	}
	if(i == len)
		goto bad;
	for(; i < len; i++){
		if(p[i] == '_')
			continue;
		if(p[i] >= '0' && p[i] <= '9') d = p[i] - '0';
		else if(p[i] >= 'a' && p[i] <= 'f') d = p[i] - 'a' + 10;
		else if(p[i] >= 'A' && p[i] <= 'F') d = p[i] - 'A' + 10;
		else goto bad;
		if(d >= b)
			goto bad;
		n = n * b + d;
	}
	return neg ? -(vlong)n : (vlong)n;
bad:
	failwith(who);
	return 0;
}

value int_of_string(value s) { return Val_int((value)parse_int(s, "int_of_string")); }

/*****************************************************************************/
/* Exceptions: the predefined, raising from C, the uncaught one */
/*****************************************************************************/

/* an exception is a block with its name, a static one; its value a
 * block [the exception; its arguments] */
value caml_exn_Match_failure[2];
value caml_exn_Assert_failure[2];
value caml_exn_Out_of_memory[2];
value caml_exn_Stack_overflow[2];
value caml_exn_Invalid_argument[2];
value caml_exn_Failure[2];
value caml_exn_Not_found[2];
value caml_exn_Sys_error[2];
value caml_exn_End_of_file[2];
value caml_exn_Division_by_zero[2];
value caml_atom0[1];            /* the empty array's header */

/* (a header, then the name's bytes and its padding: 16 letters are 5
 * words of 32 bits, 3 of 64) */
static value names[10][8];

static void
exception(value *e, value *name, char *s)
{
	value n;

	n = strlen(s);
	name[0] = (((n / W) + 1) << 10) | String_tag;
	memmove(name + 1, s, n);
	Bytes(name + 1)[((n / W) + 1) * W - 1] = ((n / W) + 1) * W - 1 - n;
	e[0] = (1 << 10) | 0;
	e[1] = (value)(name + 1);
}

static void
init_exceptions(void)
{
	exception(caml_exn_Match_failure, names[0], "Match_failure");
	exception(caml_exn_Assert_failure, names[1], "Assert_failure");
	exception(caml_exn_Out_of_memory, names[2], "Out_of_memory");
	exception(caml_exn_Stack_overflow, names[3], "Stack_overflow");
	exception(caml_exn_Invalid_argument, names[4], "Invalid_argument");
	exception(caml_exn_Failure, names[5], "Failure");
	exception(caml_exn_Not_found, names[6], "Not_found");
	exception(caml_exn_Sys_error, names[7], "Sys_error");
	exception(caml_exn_End_of_file, names[8], "End_of_file");
	exception(caml_exn_Division_by_zero, names[9], "Division_by_zero");
}

/* raise e(msg) from C */
static void
raise_with(value *e, char *msg)
{
	value s, x;

	s = ml_string(msg);
	push(s);
	x = ml_alloc(2, 0);
	s = pop();
	Field(x, 0) = (value)(e + 1);
	Field(x, 1) = s;
	ml_raise(x);
}

/* raise a constant exception from C */
static void
raise_const(value *e)
{
	value x;

	x = ml_alloc(1, 0);
	Field(x, 0) = (value)(e + 1);
	ml_raise(x);
}

void
failwith(char *msg)
{
	raise_with(caml_exn_Failure, msg);
}

static char ebuf[256];
static int elen;

static void
eadd(char *s, int n)
{
	int i;

	for(i = 0; i < n && elen < 255; i++)
		ebuf[elen++] = s[i];
}

/* as ocaml-light's printexc.c: its name, then its integer and string
 * arguments (a single tuple's fields, as Match_failure's); stdout isn't
 * flushed */
value
ml_uncaught(value exn)
{
	char buf[64];
	value b, v, i, start, name;
	int s;

	name = Field(Field(exn, 0), 0);
	eadd((char*)Bytes(name), length(name));
	if(Wosize(exn) >= 2){
		b = exn;
		start = 1;
		v = Field(exn, 1);
		if(Wosize(exn) == 2 && !Is_int(v) && Tag(v) == 0){
			b = v;
			start = 0;
		}
		eadd("(", 1);
		for(i = start; i < Wosize(b); i++){
			if(i > start)
				eadd(", ", 2);
			v = Field(b, i);
			if(Is_int(v)){
				if(Long_val(v) < 0){
					s = digits(-(uvalue)Long_val(v), 10, 0, buf, 64);
					buf[--s] = '-';
				}else
					s = digits(Long_val(v), 10, 0, buf, 64);
				eadd(buf + s, 64 - s);
			}else if(Tag(v) == String_tag){
				eadd("\"", 1);
				eadd((char*)Bytes(v), length(v));
				eadd("\"", 1);
			}else
				eadd("_", 1);
		}
		eadd(")", 1);
	}
	write(2, "Fatal error: uncaught exception ", 32);
	write(2, ebuf, elen);
	write(2, "\n", 1);
	exit(2);
	return Val_unit;
}

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

/*****************************************************************************/
/* Arrays, Obj, Callback */
/*****************************************************************************/

value
make_vect(value n, value init)
{
	value a, i;

	n = Long_val(n);
	if(n < 0)
		raise_with(caml_exn_Invalid_argument, "Array.make");
	if(n == 0)
		return (value)(caml_atom0 + 1);
	push(init);
	a = ml_alloc(n, 0);
	init = pop();
	for(i = 0; i < n; i++)
		Field(a, i) = init;
	return a;
}

value
obj_tag(value v)
{
	return Is_int(v) ? Val_int(1000) : Val_int(Tag(v));
}

value
obj_is_block(value v)
{
	return Val_bool(!Is_int(v));
}

value
obj_block(value tag, value n)
{
	value b, i;

	b = ml_alloc(Long_val(n), Long_val(tag));
	for(i = 0; i < Long_val(n); i++)
		Field(b, i) = Val_unit;
	return b;
}


value
register_named_value(value name, value v)
{
	if(nnamed == NAMED)
		fatal("mini-ml: too many named values\n");
	named_names[nnamed] = name;
	named_values[nnamed] = v;
	nnamed++;
	return Val_unit;
}

/* C calls ML (ocaml-light's callback.h's names, for a kernel's C): the
 * value under a name, where the collector keeps it up to date; a
 * function applied, to one argument at a time as ML's own calls of an
 * unknown function are (ml_callback is the start object's: ML's
 * arguments are in registers; not with gcc: Gen says why) */
value*
caml_named_value(char *name)
{
	int i;
	char *p, *q;

	for(i = 0; i < nnamed; i++){
		p = (char*)Bytes(named_names[i]);
		for(q = name; *p == *q && *p != 0; p++)
			q++;
		if(*p == *q)
			return &named_values[i];
	}
	return nil;
}

#ifndef __GNUC__
/* (ml_vsp is the top when ML last called C: the function called leaves
 * its own there, above; C's is put back after) */
value
callback(value f, value a)
{
	value *top;

	top = ml_vsp;
	f = ml_callback(f, a);
	ml_vsp = top;
	return f;
}

value
callback2(value f, value a, value b)
{
	push(b);
	f = callback(f, a);
	b = pop();
	return callback(f, b);
}
#endif

/*****************************************************************************/
/* Channels: ocaml-light's io.c, a buffer written when full */
/*****************************************************************************/

typedef struct Chan Chan;
struct Chan {
	int fd;
	int len;                /* output: the bytes buffered; input: those left, */
	int pos;                /* from pos */
	vlong offset;
	uchar buf[4096];
};

value
caml_open_descriptor(value fd)
{
	Chan *c;

	c = malloc(sizeof(Chan));
	c->fd = Long_val(fd);
	c->len = 0;
	c->pos = 0;
	c->offset = 0;
	return (value)c;
}

static void
flush_chan(Chan *c)
{
	if(c->len > 0)
		write(c->fd, c->buf, c->len);
	c->offset += c->len;
	c->len = 0;
}

value
caml_flush(value ch)
{
	flush_chan((Chan*)ch);
	return Val_unit;
}

static void
putc_chan(Chan *c, int b)
{
	if(c->len == 4096)
		flush_chan(c);
	c->buf[c->len++] = b;
}

value
caml_output_char(value ch, value b)
{
	putc_chan((Chan*)ch, Long_val(b));
	return Val_unit;
}

value
caml_output(value ch, value s, value ofs, value len)
{
	value i;

	for(i = 0; i < Long_val(len); i++)
		putc_chan((Chan*)ch, Bytes(s)[Long_val(ofs) + i]);
	return Val_unit;
}

value
caml_output_int(value ch, value n)
{
	Chan *c;

	c = (Chan*)ch;
	n = Long_val(n);
	putc_chan(c, n >> 24);
	putc_chan(c, n >> 16);
	putc_chan(c, n >> 8);
	putc_chan(c, n);
	return Val_unit;
}

/* a system call of Linux's, by its number (the Unix section below):
 * goken's _syscall6, or gnu.h's ux */
#ifndef __GNUC__
/* a word each (a long is 32 bits for 7c: a pointer would lose its half) */
extern value _syscall6(value, value, value, value, value, value, value);
#define ux _syscall6
#endif

/* Linux's read, by its number: its answer says an interruption (-4,
 * EINTR), which a libc's read hides */
#define Interrupted (-4)
static long
fill(Chan *c)
{
	long n;

	n = ux(W == 8 ? 63 : 3, c->fd, (value)c->buf, 4096, 0, 0, 0);
	if(n > 0){
		c->offset += n;
		c->len = n;
		c->pos = 0;
	}
	return n;
}

/* the next byte, or -1 at the end; a signal's interruption is not one
 * (the signal stays noted, for the next place that runs the handlers) */
static int
getc_chan(Chan *c)
{
	long n;

	if(c->len == 0){
		do n = fill(c); while(n == Interrupted);
		if(n <= 0)
			return -1;
	}
	c->len--;
	return c->buf[c->pos++];
}

value
caml_input_char(value ch)
{
	int b;

	b = getc_chan((Chan*)ch);
	if(b < 0)
		raise_const(caml_exn_End_of_file);
	return Val_int(b);
}

/* The three a program waits in (Pervasives' input_char, input and
 * input_line): interrupted by a signal, they say so (-2, -1, and
 * Scan_interrupted), for Pervasives to run the signal's handler, which
 * is OCaml's, and ask again. Interrupted too, without reading, when a
 * signal came before (signalled[0]: one is noted). */
static int signalled[65];

static long
fill_or_signal(Chan *c)
{
	return signalled[0] ? Interrupted : fill(c);
}

value
ml_input_char(value ch)
{
	Chan *c;
	long n;

	c = (Chan*)ch;
	if(c->len == 0){
		n = fill_or_signal(c);
		if(n <= 0)
			return Val_int(n == Interrupted ? -2 : -1);
	}
	c->len--;
	return Val_int(c->buf[c->pos++]);
}

value
caml_input(value ch, value s, value ofs, value len)
{
	Chan *c;
	value n;
	int b;

	c = (Chan*)ch;
	if(c->len == 0 && Long_val(len) > 0 && fill_or_signal(c) == Interrupted)
		return Val_int(-1);
	n = 0;
	while(n < Long_val(len) && c->len > 0){
		b = getc_chan(c);
		if(b < 0)
			break;
		Bytes(s)[Long_val(ofs) + n] = b;
		n++;
	}
	return Val_int(n);
}

/* how far to the next newline (included), negated if the buffer ends
 * first: ocaml-light's input_scan_line, which input_line loops on */
#define Scan_interrupted (-100000)
value
caml_input_scan_line(value ch)
{
	Chan *c;
	int i;
	long n;

	c = (Chan*)ch;
	if(c->len == 0){
		n = fill_or_signal(c);
		if(n <= 0)
			return Val_int(n == Interrupted ? Scan_interrupted : 0);
	}
	for(i = 0; i < c->len; i++)
		if(c->buf[c->pos + i] == '\n')
			return Val_int(i + 1);
	return Val_int(-c->len);
}

value
caml_close_channel(value ch)
{
	Chan *c;

	c = (Chan*)ch;
	flush_chan(c);
	close(c->fd);
	return Val_unit;
}

value
caml_pos_out(value ch)
{
	return Val_int(((Chan*)ch)->offset + ((Chan*)ch)->len);
}

value
caml_pos_in(value ch)
{
	return Val_int(((Chan*)ch)->offset - ((Chan*)ch)->len);
}

/* a file's size: its end sought, then where the channel was (offset is
 * the file's position: what was read of it, or written) */
value
caml_channel_size(value ch)
{
	Chan *c;
	vlong size;

	c = (Chan*)ch;
	size = seek(c->fd, 0, 2);
	if(size < 0 || seek(c->fd, c->offset, 0) < 0)
		raise_with(caml_exn_Sys_error, "not a file");
	return Val_int(size);
}

/* what is buffered is dropped (read), or written first */
value
caml_seek_in(value ch, value n)
{
	Chan *c;

	c = (Chan*)ch;
	if(seek(c->fd, Long_val(n), 0) < 0)
		raise_with(caml_exn_Sys_error, "seek_in");
	c->offset = Long_val(n);
	c->len = 0;
	c->pos = 0;
	return Val_unit;
}

value
caml_seek_out(value ch, value n)
{
	Chan *c;

	c = (Chan*)ch;
	flush_chan(c);
	if(seek(c->fd, Long_val(n), 0) < 0)
		raise_with(caml_exn_Sys_error, "seek_out");
	c->offset = Long_val(n);
	return Val_unit;
}

/* output_binary_int's 4 bytes, the high one first, with its sign */
value
caml_input_int(value ch)
{
	int i, b, n;

	n = 0;
	for(i = 0; i < 4; i++){
		b = getc_chan((Chan*)ch);
		if(b < 0)
			raise_const(caml_exn_End_of_file);
		n = n << 8 | b;
	}
	return Val_int((value)n);
}

/*****************************************************************************/
/* Sys */
/*****************************************************************************/

static int argc;
static char **argv;

value
sys_exit(value n)
{
	exit(Long_val(n));
	return Val_unit;
}

value
sys_get_argv(value unit)
{
	value a, s;
	int i;

	a = make_vect(Val_int(argc), Val_unit);
	for(i = 0; i < argc; i++){
		push(a);
		s = ml_string(argv[i]);
		a = pop();
		Field(a, i) = s;
	}
	return a;
}

value
sys_get_config(value unit)
{
	value r, s;

	s = ml_string("Plan9");
	push(s);
	r = ml_alloc(2, 0);
	s = pop();
	Field(r, 0) = s;
	Field(r, 1) = Val_int(8 * W);
	return r;
}

value
sys_getenv(value name)
{
	char *v;

	v = getenv((char*)Bytes(name));
	if(v == nil)
		raise_const(caml_exn_Not_found);
	return ml_string(v);
}

/* ocaml-light's open_flag, in its order: a constant constructor's number */
enum { Open_rdonly, Open_wronly, Open_append, Open_creat, Open_trunc, Open_excl };

/* A file opened as Plan 9's: open, which doesn't make it, then create,
 * which makes it (and empties it); with Open_excl, create alone, which
 * fails when the file is there. Open_append is a seek to the end, once:
 * not Unix's O_APPEND, each write at the end whoever else writes */
value
sys_open(value name, value flags, value perm)
{
	int fd, set, mode;
	char *s;

	s = (char*)Bytes(name);
	set = 0;
	for(; !Is_int(flags); flags = Field(flags, 1))
		set |= 1 << Long_val(Field(flags, 0));
	/* (Open_append alone writes too: OCaml's flag for it is O_APPEND | O_WRONLY) */
	mode = (set & (1 << Open_wronly | 1 << Open_append)) ? OWRITE : OREAD;
	fd = -1;
	if(!(set & 1 << Open_creat))
		fd = open(s, mode | ((set & 1 << Open_trunc) ? OTRUNC : 0));
	else if(set & 1 << Open_excl)
		fd = create(s, mode | OEXCL, Long_val(perm));
	else{
		fd = open(s, mode | ((set & 1 << Open_trunc) ? OTRUNC : 0));
		if(fd < 0)
			fd = create(s, mode, Long_val(perm));
	}
	if(fd < 0)
		raise_with(caml_exn_Sys_error, s);
	if(set & 1 << Open_append)
		seek(fd, 0, 2);
	return Val_int(fd);
}

value
sys_close(value fd)
{
	close(Long_val(fd));
	return Val_unit;
}

/* 0 a file, 1 a directory, -1 nothing */
static int
file_kind(value name)
{
	Dir *d;
	int k;

	d = dirstat((char*)Bytes(name));
	if(d == nil)
		return -1;
	k = (d->mode & DMDIR) != 0;
	free(d);
	return k;
}

value sys_file_exists(value name) { return Val_bool(file_kind(name) >= 0); }

value
sys_is_directory(value name)
{
	int k;

	k = file_kind(name);
	if(k < 0)
		raise_with(caml_exn_Sys_error, (char*)Bytes(name));
	return Val_bool(k);
}

/* a file, or an empty directory (Sys.rmdir too: Plan 9's remove) */
value
sys_remove(value name)
{
	if(remove((char*)Bytes(name)) < 0)
		raise_with(caml_exn_Sys_error, (char*)Bytes(name));
	return Val_unit;
}

value
sys_mkdir(value name, value perm)
{
	int fd;

	fd = create((char*)Bytes(name), OREAD, DMDIR | Long_val(perm));
	if(fd < 0)
		raise_with(caml_exn_Sys_error, (char*)Bytes(name));
	close(fd);
	return Val_unit;
}

#ifndef __GNUC__
/* Plan 9's rename: a file's name changed in its directory (dirwstat) */
static int
rename_in_dir(char *from, char *to, char *name)
{
	Dir d;

	USED(to);
	nulldir(&d);
	d.name = name;
	return dirwstat(from, &d);
}

/* sh -c cmd, waited for: its exit status, 255 for a signal */
static int
shell(char *cmd)
{
	Waitmsg *w;
	int pid, st;

	pid = fork();
	if(pid == 0){
		execl("/bin/sh", "sh", "-c", cmd, nil);
		exits("exec");
	}
	if(pid < 0)
		return 127;
	do{
		w = wait();
		if(w == nil)
			return 127;
		st = w->msg[0] == 0 ? 0 : w->msg[0] >= '0' && w->msg[0] <= '9' ? atoi(w->msg) : 255;
		st = w->pid == pid ? st : -1;
		free(w);
	}while(st < 0);
	return st;
}
#endif

/* the two names in one directory: Plan 9 has no other rename, and a
 * file moved to another directory is copied */
value
sys_rename(value from, value to)
{
	char *f, *t, *fb, *tb;

	f = (char*)Bytes(from);
	t = (char*)Bytes(to);
	fb = strrchr(f, '/');
	tb = strrchr(t, '/');
	fb = fb == nil ? f : fb + 1;
	tb = tb == nil ? t : tb + 1;
	if(fb - f != tb - t || strncmp(f, t, fb - f) != 0 || rename_in_dir(f, t, tb) < 0)
		raise_with(caml_exn_Sys_error, f);
	return Val_unit;
}

value
sys_getcwd(value unit)
{
	char buf[1024];

	if(getwd(buf, sizeof buf) == nil)
		raise_with(caml_exn_Sys_error, "getcwd");
	return ml_string(buf);
}

/* a directory's names, without . and .. */
value
sys_read_directory(value name)
{
	Dir *d;
	value a, s;
	long n, i;
	int fd;

	fd = open((char*)Bytes(name), OREAD);
	n = fd < 0 ? -1 : dirreadall(fd, &d);
	if(fd >= 0)
		close(fd);
	if(n < 0)
		raise_with(caml_exn_Sys_error, (char*)Bytes(name));
	a = make_vect(Val_int(n), Val_unit);
	for(i = 0; i < n; i++){
		push(a);
		s = ml_string(d[i].name);
		a = pop();
		Field(a, i) = s;
	}
	free(d);
	return a;
}

value
sys_system_command(value cmd)
{
	return Val_int(shell((char*)Bytes(cmd)));
}

/* Signals. A handler is OCaml's (Sys.signal's function), and C can't
 * call it: here a signal is only noted, and the stdlib runs the
 * handlers of those noted where a program waits, when a read or a
 * system call comes back interrupted (Pervasives' run_signals). So a
 * handler runs between two instructions of OCaml's, never in the
 * middle of the collector; and not in a computation that asks nothing
 * of the system, where OCaml would run it at an allocation. */
static void
note_signal(int sig)
{
	/* an interrupt again, the first one's handler not run yet: the
	 * program computes and waits nowhere, so the system's default, its
	 * end (exit_group, 130 as a shell says it) */
	if(sig == 2 && signalled[sig])
		ux(W == 8 ? 94 : 248, 130, 0, 0, 0, 0, 0);
	signalled[sig] = 1;
	signalled[0] = 1;
}

#ifndef __GNUC__
/* rt_sigaction, by its number: the handler, no flag (a system call
 * interrupted says so, and is not started again), no mask */
static void
set_signal(int sig, int how)
{
	value act[5];	/* handler, flags, restorer, and a mask of 64 bits */

	act[0] = how == 0 ? 0 : how == 1 ? 1 : (value)note_signal;
	act[1] = act[2] = act[3] = act[4] = 0;
	ux(W == 8 ? 134 : 174, sig, (value)act, 0, 8, 0, 0);
}
#endif

/* how: 0 the system's default, 1 ignored, 2 noted */
value
ml_signal(value sig, value how)
{
	set_signal(Long_val(sig), Long_val(how));
	return Val_unit;
}

/* a signal noted, forgotten here, or 0 */
value
ml_signal_pending(value unit)
{
	int s;

	if(!signalled[0])	/* none: asked after each system call (Unix's check) */
		return Val_int(0);
	signalled[0] = 0;	/* before the look: a signal coming meanwhile sets it again */
	for(s = 1; s < 65; s++)
		if(signalled[s]){
			signalled[s] = 0;
			signalled[0] = 1;
			return Val_int(s);
		}
	return Val_int(0);
}

/*****************************************************************************/
/* Floats: boxed, a block of the double's bits (phase 7; on arm64: on
 * arm, mini-ld encodes 5c's FPA, not the Pi's VFP) */
/*****************************************************************************/

/* what goken's libc lacks, from what it has (not glibc's to the last
 * bit) */
static double ml_tan(double x) { return sin(x) / cos(x); }
static double ml_sinh(double x) { return (exp(x) - exp(-x)) / 2; }
static double ml_cosh(double x) { return (exp(x) + exp(-x)) / 2; }
static double ml_tanh(double x) { return ml_sinh(x) / ml_cosh(x); }
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

value int32_neg(value a) { return copy_int32(-U32(a)); }
value int32_add(value a, value b) { return copy_int32(U32(a) + U32(b)); }
value int32_sub(value a, value b) { return copy_int32(U32(a) - U32(b)); }
value int32_mul(value a, value b) { return copy_int32(U32(a) * U32(b)); }
value int32_and(value a, value b) { return copy_int32(U32(a) & U32(b)); }
value int32_or(value a, value b) { return copy_int32(U32(a) | U32(b)); }
value int32_xor(value a, value b) { return copy_int32(U32(a) ^ U32(b)); }
value int32_shift_left(value a, value n) { return copy_int32(U32(a) << Long_val(n)); }
value int32_shift_right(value a, value n) { return copy_int32(Int32_val(a) >> Long_val(n)); }
value int32_shift_right_unsigned(value a, value n) { return copy_int32(U32(a) >> Long_val(n)); }
value int32_of_int(value n) { return copy_int32((int)Long_val(n)); }
value int32_to_int(value a) { return Val_int((value)Int32_val(a)); }
value int32_format(value fmt, value a) { return format_num(fmt, Int32_val(a), 32); }
value int32_of_string(value s) { return copy_int32((int)parse_int(s, "Int32.of_string")); }

value
int32_div(value a, value b)
{
	if(Int32_val(b) == 0)
		raise_const(caml_exn_Division_by_zero);
	return copy_int32(Int32_val(a) / Int32_val(b));
}

value
int32_mod(value a, value b)
{
	if(Int32_val(b) == 0)
		raise_const(caml_exn_Division_by_zero);
	return copy_int32(Int32_val(a) % Int32_val(b));
}

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

value
int32_float_of_bits(value a)
{
	float f;
	int n;

	n = Int32_val(a);
	memmove(&f, &n, 4);
	return copy_double(f);
}

value int64_of_float(value a) { return copy_int64((vlong)Double_val(a)); }
value int64_to_float(value a) { return copy_double((double)Int64_val(a)); }
value int32_of_float(value a) { return copy_int32((int)Double_val(a)); }
value int32_to_float(value a) { return copy_double((double)Int32_val(a)); }

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

/*****************************************************************************/
/* Digest: MD5 (RFC 1321) */
/*****************************************************************************/

typedef struct MD5 MD5;
struct MD5 {
	unsigned int h[4];
	uvlong len;             /* the bytes added */
	uchar buf[64];          /* those of the block not yet full */
};

/* 2^32 |sin(i + 1)|: a table, not computed, for arm has no floats here */
static unsigned int md5_k[64] = {
	0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
	0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
	0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
	0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
	0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
	0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
	0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
	0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
	0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
	0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
	0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
	0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
	0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
	0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
	0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
	0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
};
/* a round's four rotations */
static uchar md5_s[16] = { 7, 12, 17, 22, 5, 9, 14, 20, 4, 11, 16, 23, 6, 10, 15, 21 };

static void
md5_block(MD5 *m)
{
	unsigned int a, b, c, d, f, t, w[16];
	uchar *p;
	int i, g, r;

	p = m->buf;
	for(i = 0; i < 16; i++, p += 4)
		w[i] = p[0] | p[1] << 8 | p[2] << 16 | (unsigned int)p[3] << 24;
	a = m->h[0]; b = m->h[1]; c = m->h[2]; d = m->h[3];
	for(i = 0; i < 64; i++){
		/* without ~ on 32 bits: 7c's EORW $0xffffffff is an illegal
		 * instruction by 7l (and so by mini-ld, its twin). The first two
		 * are (b & c) | (~b & d) and (d & b) | (~d & c); ~d is -1 - d */
		switch(i >> 4){
		case 0: f = d ^ (b & (c ^ d)); g = i; break;
		case 1: f = c ^ (d & (b ^ c)); g = (5 * i + 1) & 15; break;
		case 2: f = b ^ c ^ d; g = (3 * i + 5) & 15; break;
		default: f = c ^ (b | (0xffffffff - d)); g = (7 * i) & 15; break;
		}
		t = a + f + md5_k[i] + w[g];
		r = md5_s[(i >> 4) * 4 + (i & 3)];
		a = d; d = c; c = b;
		b += t << r | t >> (32 - r);
	}
	m->h[0] += a; m->h[1] += b; m->h[2] += c; m->h[3] += d;
}

static void
md5_init(MD5 *m)
{
	m->h[0] = 0x67452301; m->h[1] = 0xefcdab89; m->h[2] = 0x98badcfe; m->h[3] = 0x10325476;
	m->len = 0;
}

static void
md5_add(MD5 *m, uchar *p, long n)
{
	long i;

	for(i = 0; i < n; i++){
		m->buf[m->len++ & 63] = p[i];
		if((m->len & 63) == 0)
			md5_block(m);
	}
}

/* the padding (a 1 bit, zeros, the length in bits), then the digest:
 * the 16 bytes of an ML string */
static value
md5_end(MD5 *m)
{
	uchar pad[8], b;
	uvlong bits;
	value s;
	int i;

	bits = m->len * 8;
	for(i = 0; i < 8; i++)
		pad[i] = bits >> (8 * i);
	b = 0x80;
	md5_add(m, &b, 1);
	b = 0;
	while((m->len & 63) != 56)
		md5_add(m, &b, 1);
	md5_add(m, pad, 8);
	s = string_alloc(16);
	for(i = 0; i < 16; i++)
		Bytes(s)[i] = m->h[i >> 2] >> (8 * (i & 3));
	return s;
}

value
md5_string(value s, value ofs, value len)
{
	MD5 m;

	md5_init(&m);
	md5_add(&m, Bytes(s) + Long_val(ofs), Long_val(len));
	return md5_end(&m);
}

/* len bytes of the channel (End_of_file if it has fewer), or with a
 * negative len all that is left */
value
md5_chan(value ch, value len)
{
	MD5 m;
	value n;
	int b;
	uchar c;

	md5_init(&m);
	for(n = Long_val(len); n != 0; n--){
		b = getc_chan((Chan*)ch);
		if(b < 0){
			if(n > 0)
				raise_const(caml_exn_End_of_file);
			break;
		}
		c = b;
		md5_add(&m, &c, 1);
	}
	return md5_end(&m);
}

/*****************************************************************************/
/* Unix: a system call (Linux's) */
/*****************************************************************************/

/* The Unix module is OCaml (lib_core's Unix): each of its functions a
 * system call of Linux's, by its number, its structures packed and read
 * as bytes there. So here is only the call: nothing of a libc's, and
 * the same for goken's (its _syscall6) and for glibc (gnu.h's ux).
 * An argument is an int, a string or bytes (their address), or an
 * int32 or an int64 (their value: an int has 31 bits on arm). The
 * answer is the kernel's: a negative errno when it fails. */
static value
ux_arg(value v)
{
	if(Is_int(v))
		return Long_val(v);
	if(Tag(v) == Int32_tag)
		return Int32_val(v);
	if(Tag(v) == Int64_tag)
		return Int64_val(v);
	return v;
}

value
unix_syscall(value nr, value args)
{
	return Val_int(ux(Long_val(nr), ux_arg(Field(args, 0)), ux_arg(Field(args, 1)), ux_arg(Field(args, 2)),
		ux_arg(Field(args, 3)), ux_arg(Field(args, 4)), ux_arg(Field(args, 5))));
}

/* execve: its two arrays of strings, as C's, ended by nil */
static char**
ux_strings(value a)
{
	char **v;
	value i, n;

	n = Wosize(a);
	v = malloc((n + 1) * sizeof(char*));
	for(i = 0; i < n; i++)
		v[i] = (char*)Field(a, i);
	v[n] = nil;
	return v;
}

value
unix_execve(value path, value argv, value envp)
{
	return Val_int(ux(W == 8 ? 221 : 11, path, (value)ux_strings(argv), (value)ux_strings(envp), 0, 0, 0));
}

/*****************************************************************************/
/* Marshal: a value as bytes, and back */
/*****************************************************************************/

/* OCaml's format (ocaml-light's too): 20 bytes (the magic number, the
 * data's length, the objects' count, the words they take on 32 and on
 * 64 bits), then the value, depth first, each thing a byte's code and
 * what follows, the high byte first: a small integer or a wider one, a
 * string, a block (its tag, its size, then its fields), a float, an
 * int32 or an int64 (as OCaml's custom blocks "_i" and "_j"), or a
 * block met before, by how many objects ago (so what is shared stays
 * shared, and a cycle ends). The same bytes as OCaml's wherever a value
 * is the same blocks in both; not a constructor's inline record (here
 * a block of its own), an array of floats (here boxed), a closure
 * (refused). */
enum {
	Small_block = 0x80, Small_int = 0x40, Small_string = 0x20,
	Int8 = 0, Int16 = 1, Int32c = 2, Int64c = 3, Shared8 = 4, Shared16 = 5, Shared32 = 6,
	Block32 = 8, String8 = 9, String32 = 10, Double_big = 11, Double_little = 12,
	Custom = 0x12, Custom_len = 0x18, Custom_fixed = 0x19,
	Mheader = 20
};
#define Mmagic 0x8495A6BE

/* kept from a call to the next: the bytes written, or read from a
 * channel; the blocks met, by their address when writing (a hash
 * table), by their number when reading */
static uchar *mbuf;
static value mlen, mcap;
static value *mkeys, *mvals, *mobjs;
static value mslots, mnobjs, mcount, msize32, msize64, mobjcap;
static uchar *msrc;

/* Their memory is the system's (mmap and munmap, by their numbers), n
 * bytes of zeros, given back when one grows. Not the C library's: its
 * malloc (goken's, a placeholder) gives 64 MB in all and takes nothing
 * back, and a large unit's object asked for more (mini-ml compiling
 * machine/Arm64.ml: the library aborted, without a word). */
static void*
m_alloc(value n)
{
#ifdef __GNUC__
	void *p;

	p = calloc(n, 1);
	if(p == nil)
		fatal("Fatal error: out of memory\n");
	return p;
#else
	value p;

	p = ux(W == 8 ? 222 : 192, 0, n, 3, 0x22, -1, 0);
	if(p < 0 && p > -4096)
		fatal("Fatal error: out of memory\n");
	return (void*)p;
#endif
}

static void
m_free(void *p, value n)
{
	if(p == nil)
		return;
#ifdef __GNUC__
	free(p);
#else
	ux(W == 8 ? 215 : 91, (value)p, n, 0, 0, 0, 0);
#endif
}

static void
m_room(value n)
{
	uchar *b;
	value cap;

	if(mlen + n > mcap){
		cap = (mlen + n) * 2 + 4096;
		b = m_alloc(cap);
		if(mbuf != nil)		/* (the first time, the header's place is already counted) */
			memmove(b, mbuf, mlen);
		m_free(mbuf, mcap);
		mbuf = b;
		mcap = cap;
	}
}

/* n's low bytes, the high one first */
static void
m_put(uvlong n, int bytes)
{
	m_room(bytes);
	while(bytes-- > 0)
		mbuf[mlen++] = n >> (8 * bytes);
}

/* the block's number, or -1 and it is given the next */
static value
m_seen(value v)
{
	value *keys, *vals;
	value i, k, old;

	if(mcount * 2 >= mslots){
		old = mslots;
		keys = mkeys;
		vals = mvals;
		mslots = old == 0 ? 1024 : old * 2;
		mkeys = m_alloc(mslots * sizeof(value));
		mvals = m_alloc(mslots * sizeof(value));
		for(i = 0; i < old; i++)
			if(keys[i] != 0){
				for(k = ((uvalue)keys[i] >> 3) & (mslots - 1); mkeys[k] != 0; k = (k + 1) & (mslots - 1))
					;
				mkeys[k] = keys[i];
				mvals[k] = vals[i];
			}
		m_free(keys, old * sizeof(value));
		m_free(vals, old * sizeof(value));
	}
	for(k = ((uvalue)v >> 3) & (mslots - 1); mkeys[k] != 0; k = (k + 1) & (mslots - 1))
		if(mkeys[k] == v)
			return mvals[k];
	mkeys[k] = v;
	mvals[k] = mnobjs++;
	mcount++;
	return -1;
}

static void
m_write(value v)
{
	value n, i, tag, d;

top:
	if(Is_int(v)){
		n = Long_val(v);
		if(n >= 0 && n < 64)
			m_put(Small_int + n, 1);
		else if(n >= -128 && n < 128)
			m_put(Int8 << 8 | (n & 255), 2);
		else if(n >= -32768 && n < 32768){
			m_put(Int16, 1);
			m_put(n, 2);
		/* 31 bits, as OCaml: what a machine of 32 bits can read */
		}else if((vlong)n >= -((vlong)1 << 30) && (vlong)n < ((vlong)1 << 30)){
			m_put(Int32c, 1);
			m_put(n, 4);
		}else{
			m_put(Int64c, 1);
			m_put(n, 8);
		}
		return;
	}
	n = Wosize(v);
	tag = Tag(v);
	if(n == 0){
		m_put(Small_block + tag, 1);
		return;
	}
	d = m_seen(v);
	if(d >= 0){
		d = mnobjs - d;
		if(d < 256)
			m_put(Shared8 << 8 | d, 2);
		else if(d < 65536){
			m_put(Shared16, 1);
			m_put(d, 2);
		}else{
			m_put(Shared32, 1);
			m_put(d, 4);
		}
		return;
	}
	switch(tag){
	case String_tag:
		n = length(v);
		if(n < 32)
			m_put(Small_string + n, 1);
		else if(n < 256)
			m_put(String8 << 8 | n, 2);
		else{
			m_put(String32, 1);
			m_put(n, 4);
		}
		m_room(n);
		memmove(mbuf + mlen, Bytes(v), n);
		mlen += n;
		msize32 += 2 + n / 4;
		msize64 += 2 + n / 8;
		return;
	case Double_tag:
		m_put(Double_little, 1);
		m_room(8);
		memmove(mbuf + mlen, Bytes(v), 8);
		mlen += 8;
		msize32 += 3;
		msize64 += 2;
		return;
	/* OCaml's sizes: a custom block has a word more, its operations */
	case Int64_tag:
		m_put(Custom_fixed, 1);
		m_put('_' << 16 | 'j' << 8, 3);
		m_put(Int64_val(v), 8);
		msize32 += 4;
		msize64 += 3;
		return;
	case Int32_tag:
		m_put(Custom_fixed, 1);
		m_put('_' << 16 | 'i' << 8, 3);
		m_put(Int32_val(v), 4);
		msize32 += 3;
		msize64 += 3;
		return;
	case Closure_tag:
		mcount = 0;
		raise_with(caml_exn_Invalid_argument, "output_value: functional value");
	}
	if(tag < 16 && n < 8)
		m_put(Small_block + tag + (n << 4), 1);
	else{
		m_put(Block32, 1);
		m_put(((uvlong)n << 10) | tag, 4);
	}
	msize32 += 1 + n;
	msize64 += 1 + n;
	for(i = 0; i < n - 1; i++)
		m_write(Field(v, i));
	/* the last field without a call: a long list is not a deep stack */
	v = Field(v, n - 1);
	goto top;
}

/* v's bytes in mbuf, mlen of them, the header first */
static void
marshal(value v)
{
	value len;

	if(mslots > 0)
		memset(mkeys, 0, mslots * sizeof(value));
	mlen = Mheader;
	mnobjs = mcount = msize32 = msize64 = 0;
	m_room(Mheader);
	m_write(v);
	len = mlen;
	mlen = 0;
	m_put(Mmagic, 4);
	m_put(len - Mheader, 4);
	m_put(mnobjs, 4);
	m_put(msize32, 4);
	m_put(msize64, 4);
	mlen = len;
}

value
output_value_to_string(value v, value flags)
{
	value s;

	marshal(v);
	s = string_alloc(mlen);
	memmove(Bytes(s), mbuf, mlen);
	return s;
}

value
output_value_to_buffer(value buf, value ofs, value len, value v, value flags)
{
	marshal(v);
	if(mlen > Long_val(len))
		failwith("Marshal.to_buffer: buffer overflow");
	memmove(Bytes(buf) + Long_val(ofs), mbuf, mlen);
	return Val_int(mlen);
}

value
output_value(value ch, value v, value flags)
{
	value i;

	marshal(v);
	for(i = 0; i < mlen; i++)
		putc_chan((Chan*)ch, mbuf[i]);
	return Val_unit;
}

/* bytes high byte first, as an unsigned number */
static uvlong
m_get(uchar *p, int bytes)
{
	uvlong n;

	for(n = 0; bytes-- > 0; p++)
		n = n << 8 | *p;
	return n;
}

static uvlong
m_next(int bytes)
{
	msrc += bytes;
	return m_get(msrc - bytes, bytes);
}

/* the value read at msrc, into dest. Its blocks are allocated as they
 * come: the heap has room for them all (m_read's), so none moves */
static void
m_value(value *dest)
{
	value v, n, i, tag;
	int code;

top:
	code = *msrc++;
	if(code >= Small_block){
		tag = code & 15;
		n = (code >> 4) & 7;
		goto block;
	}
	if(code >= Small_int){
		*dest = Val_int(code & 63);
		return;
	}
	if(code >= Small_string){
		n = code & 31;
		goto string;
	}
	switch(code){
	case Int8: n = m_next(1); *dest = Val_int(n >= 128 ? n - 256 : n); return;
	case Int16: n = m_next(2); *dest = Val_int(n >= 32768 ? n - 65536 : n); return;
	case Int32c: *dest = Val_int((value)(int)m_next(4)); return;
	case Int64c:
		if(W == 4)
			failwith("input_value: integer too large");
		*dest = Val_int((value)m_next(8));
		return;
	case Shared8: *dest = mobjs[mnobjs - (value)m_next(1)]; return;
	case Shared16: *dest = mobjs[mnobjs - (value)m_next(2)]; return;
	case Shared32: *dest = mobjs[mnobjs - (value)m_next(4)]; return;
	case Block32:
		n = m_next(4);
		tag = n & 255;
		n = (uvalue)n >> 10;
		goto block;
	case String8: n = m_next(1); goto string;
	case String32: n = m_next(4); goto string;
	case Double_little:
		v = copy_double_bits(0);
		memmove(Bytes(v), msrc, 8);
		msrc += 8;
		break;
	case Double_big:
		v = copy_double_bits(m_next(8));
		break;
	case Custom_len:
	case Custom_fixed:
	case Custom:
		/* "_j" an int64, "_i" an int32; Custom_len has its sizes before the data */
		if(msrc[0] != '_' || (msrc[1] != 'j' && msrc[1] != 'i') || msrc[2] != 0)
			failwith("input_value: unknown custom block");
		i = msrc[1] == 'j';
		msrc += code == Custom_len ? 15 : 3;
		if(i)
			v = copy_int64(m_next(8));
		else
			v = copy_int32(m_next(4));
		break;
	default:
		failwith("input_value: ill-formed message");
		return;
	}
	mobjs[mnobjs++] = v;
	*dest = v;
	return;
string:
	v = string_alloc(n);
	memmove(Bytes(v), msrc, n);
	msrc += n;
	mobjs[mnobjs++] = v;
	*dest = v;
	return;
block:
	if(n == 0){
		*dest = (value)(caml_atom0 + 1);
		return;
	}
	v = ml_alloc(n, tag);
	mobjs[mnobjs++] = v;
	*dest = v;
	for(i = 0; i < n - 1; i++)
		m_value(&Field(v, i));
	dest = &Field(v, n - 1);
	goto top;
}

/* the header at h checked; room made in the heap for the value's
 * blocks (their words are the header's, or fewer), and a table for
 * their count; the data's length */
static value
m_header(uchar *h)
{
	value need, n;

	if(m_get(h, 4) != Mmagic)
		failwith("input_value: bad object");
	need = m_get(h + (W == 8 ? 16 : 12), 4) + 64;
	if(hp + need > limit)
		gc(need);
	n = m_get(h + 8, 4) + 1;
	if(n > mobjcap){
		m_free(mobjs, mobjcap * sizeof(value));
		mobjs = m_alloc(n * 2 * sizeof(value));
		mobjcap = n * 2;
	}
	mnobjs = 0;
	return m_get(h + 4, 4);
}

value
input_value_from_string(value s, value ofs)
{
	value v;

	/* the collection m_header may do moves the string */
	push(s);
	m_header(Bytes(s) + Long_val(ofs));
	s = pop();
	msrc = Bytes(s) + Long_val(ofs) + Mheader;
	m_value(&v);
	return v;
}

value
input_value(value ch)
{
	uchar h[Mheader];
	value v, i, len;
	int b;

	for(i = 0; i < Mheader; i++){
		b = getc_chan((Chan*)ch);
		if(b < 0)
			raise_const(caml_exn_End_of_file);
		h[i] = b;
	}
	len = m_get(h + 4, 4);
	mlen = 0;
	m_room(len);
	for(i = 0; i < len; i++){
		b = getc_chan((Chan*)ch);
		if(b < 0)
			failwith("input_value: truncated object");
		mbuf[i] = b;
	}
	m_header(h);
	msrc = mbuf;
	m_value(&v);
	return v;
}

value
marshal_data_size(value s, value ofs)
{
	if(m_get(Bytes(s) + Long_val(ofs), 4) != Mmagic)
		failwith("Marshal.data_size: bad object");
	return Val_int(m_get(Bytes(s) + Long_val(ofs) + 4, 4));
}

/*****************************************************************************/
/* Not yet: the others below */
/*****************************************************************************/


/* the stdlib's other externals, which a unit's closure of its externals
 * names (Lower's Iexternal): each fails when called. The list is the
 * stdlib's non-% primitives this file doesn't define (the
 * floats' functions, Gc, and some of Sys) */
/* by Linux's numbers: chdir, and clock_gettime of the process's
 * processor time (the clock 2), its seconds and nanoseconds a word each */
value
sys_chdir(value name)
{
	if(ux(W == 8 ? 49 : 12, (value)Bytes(name), 0, 0, 0, 0, 0) < 0)
		raise_with(caml_exn_Sys_error, (char*)Bytes(name));
	return Val_unit;
}

value
sys_time(value unit)
{
	value t[2];

	ux(W == 8 ? 113 : 263, 2, (value)t, 0, 0, 0, 0);
	return copy_double(t[0] + t[1] / 1e9);
}

value caml_get_exception_backtrace(void) { unsupported("caml_get_exception_backtrace"); return 0; }

/*****************************************************************************/
/* main */
/*****************************************************************************/

void
main(int ac, char *av[])
{
	char *s;

	argc = ac;
	argv = av;
	init_exceptions();
	caml_atom0[0] = 0;
	size = HEAPSTART;
	s = getenv("ML_HEAP");
	if(s != nil)
		size = atoi(s);
	if(size < 16)
		size = 16;
	if(size > MAXHEAP)
		size = MAXHEAP;
	from = space0;
	other = space1;
	hp = from;
	limit = from + size;
	ml_vsp = vstack;
	ml_stack(0, vstack);
	push(ml_string("index out of bounds"));
	bound_exn = ml_alloc(2, 0);
	Field(bound_exn, 0) = (value)(caml_exn_Invalid_argument + 1);
	Field(bound_exn, 1) = pop();
	ml_start(vstack);
	exit(0);
}
