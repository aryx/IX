/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* TinyML's runtime, its part common to every program (the host's,
 * runtime.c; TinyKernel.ml's, TinyKernel/runtime.c): the allocator
 * and Cheney's copying collector, the primitives the prelude names,
 * stdout's buffer, the uncaught exception. Its includer gives the
 * memory (ml_run) and write and exit. A word is intptr's: 8 bytes on
 * arm64, 4 on tiny-machine (tiny-ml).
 *
 * A value is a word: an integer n as 2n+1, or the address of a block's
 * first field, the block's header the word before it (its size in
 * words << 10, its tag in the low byte: 247 a closure, 252 a string,
 * whose fields hold no value). The roots are the value stack, from its
 * base to ml_vsp (which the ML code stores before calling C), and the
 * program's globals (ml_globals, ml_nglobals, written by tiny-ml). A C
 * function that allocates pushes its values on the value stack first,
 * and reads them back: the collector moves them. */

typedef intptr value;
typedef unsigned char uchar;

#define W sizeof(value)

extern long write(int, void*, long);
extern void exit(int);

extern void ml_start(value*);
extern value ml_globals[];
extern value ml_nglobals;

value *ml_vsp;
void *ml_handler;
/* the value stack's end, when the includer says it (mlsys.c): past it,
 * a recursion too deep is said at the next allocation (old: none, the
 * stack ran into the heap's first blocks: tiny-c's List.map over a
 * file's tokens, wrong values, then a loop or an exception) */
value *ml_vlimit;

/* the memory, the includer's (ml_init_heap): the value stack's base,
 * the heap's two halves and their size in words */
static value *vbase;
static value maxheap;
static value *from;           /* the heap: from..limit, allocated up to hp */
static value *other;          /* the other half */
static value *hp;
static value *limit;
static value size;
static value *lo;             /* the collector's: the space collected, */
static value *hi;
static value *next;           /* and where the next copy goes */

static void
fatal(char *msg)
{
	long n;

	for(n = 0; msg[n] != 0; n++)
		;
	write(2, msg, n);
	exit(2);
}

/* a value's copy in to-space: an integer or a pointer outside the space
 * collected (a static block) as is; a copied block's header is 0, its
 * first field the copy's address */
static value
copy(value v)
{
	value *p;
	value *q;
	value h;
	value n;
	value i;

	p = (value*)v;
	if((v & 1) != 0 || p < lo || p >= hi)
		return v;
	h = p[-1];
	if(h == 0)
		return p[0];
	n = h >> 10;
	q = next + 1;
	q[-1] = h;
	for(i = 0; i < n; i++)
		q[i] = p[i];
	next = q + n;
	p[-1] = 0;
	p[0] = (value)q;
	return (value)q;
}

/* Cheney: the roots copied, then the copies scanned, breadth first,
 * scan chasing next; the halves swapped */
static void
collect(void)
{
	value *to;
	value *scan;
	value *v;
	value n;
	value i;
	value h;

	to = other;
	lo = from;
	hi = limit;
	next = to;
	for(v = vbase; v < ml_vsp; v++)
		*v = copy(*v);
	for(i = 0; i < ml_nglobals; i++)
		ml_globals[i] = copy(ml_globals[i]);
	for(scan = to; scan < next; scan = scan + n + 1){
		h = *scan;
		n = h >> 10;
		if((h & 255) < 251)
			for(i = 1; i <= n; i++)
				scan[i] = copy(scan[i]);
	}
	other = from;
	from = to;
	hp = next;
}

/* if less than half is free after, the heap grows: its halves are
 * the includer's, as big as they can be (maxheap words), and size the
 * part in use */
static void
gc(value need)
{
	collect();
	while((hp - from + need) * 2 > size && size < maxheap)
		size = size * 2;
	if(size > maxheap)
		size = maxheap;
	limit = from + size;
	if(hp + need > limit)
		fatal("Fatal error: out of memory\n");
}

value
ml_alloc(value n, value tag)
{
	value *p;

	if(hp + n + 1 > limit)
		gc(n + 1);
	if(ml_vlimit && ml_vsp > ml_vlimit)
		fatal("Fatal error: stack overflow\n");
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

static value
wosize(value v)
{
	return ((value*)v)[-1] >> 10;
}

/* strings: the last byte the number of padding bytes before it */
static value
string_alloc(value len)
{
	value w;
	value s;

	/* (W as a value: sizeof's type has no sign, and tiny-cpu divides
	 * signed only, so len / W was a call of __udivmod, some thousand
	 * instructions for each string made) */
	w = len / (value)W + 1;
	s = ml_alloc(w, 252);
	((value*)s)[w - 1] = 0;
	((uchar*)s)[w * W - 1] = w * W - 1 - len;
	return s;
}

static value
length(value s)
{
	value w;

	w = wosize(s);
	return w * W - 1 - ((uchar*)s)[w * W - 1];
}

value
ml_string_length(value s)
{
	return length(s) * 2 + 1;
}

value
ml_string_get(value s, value i)
{
	i = i >> 1;
	if(i < 0 || i >= length(s))
		fatal("Fatal error: out-of-bound access in array or string\n");
	return ((uchar*)s)[i] * 2 + 1;
}

value
ml_string_make(value n, value c)
{
	value s;
	value i;

	n = n >> 1;
	s = string_alloc(n);
	for(i = 0; i < n; i++)
		((uchar*)s)[i] = c >> 1;
	return s;
}

value
ml_string_sub(value s, value ofs, value len)
{
	value r;
	value i;

	push(s);
	r = string_alloc(len >> 1);
	s = pop();
	for(i = 0; i < len >> 1; i++)
		((uchar*)r)[i] = ((uchar*)s)[(ofs >> 1) + i];
	return r;
}

// bytes are strings that are changed: Bytes.set, the copy of
// Bytes.to_string, Bytes.blit_string's
value
ml_bytes_set(value s, value i, value c)
{
	i = i >> 1;
	if(i < 0 || i >= length(s))
		fatal("Fatal error: out-of-bound access in array or string\n");
	((uchar*)s)[i] = c >> 1;
	return 1;
}

value
ml_bytes_to_string(value s)
{
	return ml_string_sub(s, 1, ml_string_length(s));
}

value
ml_bytes_blit_string(value src, value so, value dst, value d, value n)
{
	value i;

	so = so >> 1;
	d = d >> 1;
	n = n >> 1;
	if(n < 0 || so < 0 || so + n > length(src) || d < 0 || d + n > length(dst))
		fatal("Fatal error: out-of-bound access in array or string\n");
	for(i = 0; i < n; i++)
		((uchar*)dst)[d + i] = ((uchar*)src)[so + i];
	return 1;
}

value
ml_concat(value a, value b)
{
	value la;
	value lb;
	value s;
	value i;

	la = length(a);
	lb = length(b);
	push(a);
	push(b);
	s = string_alloc(la + lb);
	b = pop();
	a = pop();
	for(i = 0; i < la; i++)
		((uchar*)s)[i] = ((uchar*)a)[i];
	for(i = 0; i < lb; i++)
		((uchar*)s)[la + i] = ((uchar*)b)[i];
	return s;
}

/* String.concat: the strings of a list (a cell a block of two fields,
 * [] an integer, as ML makes them) joined by sep, the result made once
 * (old: in ML, TinyLibCore's String.concat, three calls of the runtime
 * a piece: Printf's strings, many pieces of a few bytes, cost more than
 * the ^ they replaced) */
value
ml_string_concat(value sep, value l)
{
	value n;
	value ls;
	value c;
	value s;
	value r;
	value pos;
	value i;
	value k;

	ls = length(sep);
	n = 0;
	for(c = l; (c & 1) == 0; c = ((value*)c)[1])
		n += length(((value*)c)[0]) + ls;
	if((l & 1) == 0)
		n -= ls;
	push(sep);
	push(l);
	r = string_alloc(n);
	l = pop();
	sep = pop();
	pos = 0;
	for(c = l; (c & 1) == 0; c = ((value*)c)[1]){
		s = ((value*)c)[0];
		k = length(s);
		for(i = 0; i < k; i++)
			((uchar*)r)[pos + i] = ((uchar*)s)[i];
		pos += k;
		if((((value*)c)[1] & 1) == 0){
			for(i = 0; i < ls; i++)
				((uchar*)r)[pos + i] = ((uchar*)sep)[i];
			pos += ls;
		}
	}
	return r;
}

/* n's digits at the end of buf; where they start */
static value
digits(value n, char *buf)
{
	value i;
	value d;
	value neg;

	neg = n < 0;
	i = 24;
	do {
		i--;
		d = n % 10;
		if(d < 0)
			d = -d;
		buf[i] = '0' + d;
		n = n / 10;
	} while(n != 0);
	if(neg){
		i--;
		buf[i] = '-';
	}
	return i;
}

value
ml_string_of_int(value v)
{
	char buf[24];
	value i;
	value k;
	value s;

	i = digits(v >> 1, buf);
	s = string_alloc(24 - i);
	for(k = 0; k < 24 - i; k++)
		((uchar*)s)[k] = buf[i + k];
	return s;
}

/* OCaml's compare: integers before blocks, then the tags, strings by
 * their bytes, the other blocks by their sizes then their fields */
static value
compare(value a, value b)
{
	value ta;
	value tb;
	value n;
	value m;
	value i;
	value c;
	uchar *p;
	uchar *q;

	if(a == b)
		return 0;
	if(a & 1){
		if(b & 1)
			return a < b ? -1 : 1;
		return -1;
	}
	if(b & 1)
		return 1;
	ta = ((value*)a)[-1] & 255;
	tb = ((value*)b)[-1] & 255;
	if(ta != tb)
		return ta < tb ? -1 : 1;
	if(ta == 252){
		n = length(a);
		m = length(b);
		p = (uchar*)a;
		q = (uchar*)b;
		for(i = 0; i < n && i < m; i++)
			if(p[i] != q[i])
				return p[i] < q[i] ? -1 : 1;
		return n < m ? -1 : n > m ? 1 : 0;
	}
	n = wosize(a);
	m = wosize(b);
	if(n != m)
		return n < m ? -1 : 1;
	for(i = 0; i < n; i++){
		c = compare(((value*)a)[i], ((value*)b)[i]);
		if(c != 0)
			return c;
	}
	return 0;
}

/* arrays: a block of tag 0, as a tuple; the empty one (and a
 * negative size's, which OCaml refuses) static, as
 * OCaml's atom: a block of no field has no room for the collector's
 * forwarding address */
static value empty_array[2];

value
ml_array_make(value n, value v)
{
	value a;
	value i;

	n = n >> 1;
	if(n <= 0)
		return (value)&empty_array[1];
	push(v);
	a = ml_alloc(n, 0);
	v = pop();
	for(i = 0; i < n; i++)
		((value*)a)[i] = v;
	return a;
}

value
ml_array_length(value a)
{
	return wosize(a) * 2 + 1;
}

static value*
index(value a, value i)
{
	i = i >> 1;
	if(i < 0 || i >= wosize(a))
		fatal("Fatal error: out-of-bound access in array or string\n");
	return (value*)a + i;
}

value
ml_array_get(value a, value i)
{
	return *index(a, i);
}

value
ml_array_set(value a, value i, value v)
{
	*index(a, i) = v;
	return 1;
}

// a value's hash, for TinyLibCore/Hashtbl.ml: its integers, its
// strings' bytes, its blocks' tags and fields, as OCaml's Hashtbl.hash
// walks one, ten values at most; never an address, which the collector
// changes (a closure is its tag alone)
static unsigned
hash(value v, value *budget)
{
	unsigned h;
	value n;
	value i;
	value t;
	uchar *p;

	if(*budget <= 0)
		return 0;
	*budget = *budget - 1;
	if(v & 1)
		return (unsigned)(v >> 1) * 0x9e3779b1;
	t = ((value*)v)[-1] & 255;
	h = t;
	if(t == 252){
		n = length(v);
		p = (uchar*)v;
		for(i = 0; i < n; i++)
			h = (h ^ p[i]) * 16777619;
		return h;
	}
	if(t == 247)
		return h;
	n = wosize(v);
	for(i = 0; i < n && *budget > 0; i++)
		h = h * 31 + hash(((value*)v)[i], budget);
	return h;
}

value
ml_hash(value v)
{
	value budget;

	budget = 10;
	return ((hash(v, &budget) & 0x3fffffff) << 1) | 1;
}

// two integers compared here, before compare's frame of eight locals
// (old: 100 instructions for min 3 4, the prelude's min being
// polymorphic; a sound's sample clamped by min and max was 175 of them)
value
ml_compare(value a, value b)
{
	if(a & b & 1)
		return a < b ? -1 : a == b ? 1 : 3;
	return compare(a, b) * 2 + 1;
}

value
ml_equal(value a, value b)
{
	if(a & b & 1)
		return a == b ? 3 : 1;
	return compare(a, b) == 0 ? 3 : 1;
}

/* stdout: ocaml-light's channel, a buffer written when full, flushed
 * by print_newline and at exit, lost on an uncaught exception */
static uchar obuf[4096];
static long olen;

/* all of the buffer, in as many writes as it takes: a pipe of
 * tiny-kernel's takes 512 bytes at a time, and a write says how many
 * it took (old: one write, and in a pipe what was over 512 lost) */
static void
writeall(void)
{
	long done, k;

	for(done = 0; done < olen; done += k)
		if((k = write(1, obuf + done, olen - done)) <= 0)
			break;
	olen = 0;
}

static void
outc(value c)
{
	if(olen == 4096)
		writeall();
	obuf[olen] = c;
	olen++;
}

static void
flush(void)
{
	writeall();
}

value
ml_print_string(value s)
{
	value n;
	value i;

	n = length(s);
	for(i = 0; i < n; i++)
		outc(((uchar*)s)[i]);
	return 1;
}

value
ml_print_char(value c)
{
	outc(c >> 1);
	return 1;
}

value
ml_print_newline(value u)
{
	outc('\n');
	flush();
	return u;
}

value
ml_exit(value n)
{
	flush();
	exit(n >> 1);
	return 1;
}

/* an uncaught exception, as ocaml-light's printexc.c prints it: its
 * name, then its integer and string arguments (a single tuple's
 * fields, as Match_failure's) */
static char ebuf[256];
static long elen;

static void
eadd(char *s, value n)
{
	value i;

	for(i = 0; i < n && elen < 255; i++){
		ebuf[elen] = s[i];
		elen++;
	}
}

value
ml_uncaught(value exn)
{
	char buf[24];
	value b;
	value v;
	value i;
	value start;
	value name;

	name = ((value*)((value*)exn)[0])[0];
	eadd((char*)name, length(name));
	if(wosize(exn) >= 2){
		b = exn;
		start = 1;
		v = ((value*)exn)[1];
		if(wosize(exn) == 2 && (v & 1) == 0 && (((value*)v)[-1] & 255) == 0){
			b = v;
			start = 0;
		}
		eadd("(", 1);
		for(i = start; i < wosize(b); i++){
			if(i > start)
				eadd(", ", 2);
			v = ((value*)b)[i];
			if(v & 1)
				eadd(buf + digits(v >> 1, buf), 24 - digits(v >> 1, buf));
			else if((((value*)v)[-1] & 255) == 252){
				eadd("\"", 1);
				eadd((char*)v, length(v));
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
	return 1;
}

/* the heap and the value stack: the includer's memory; then the
 * program's toplevel */
void
ml_run(value *stack, value *space0, value *space1, value words, value initial)
{
	vbase = stack;
	maxheap = words;
	size = initial;
	if(size < 16)
		size = 16;
	if(size > maxheap)
		size = maxheap;
	from = space0;
	other = space1;
	hp = from;
	limit = from + size;
	ml_vsp = vbase;
	ml_start(vbase);
}

/* Marshal: a value as bytes and back, in OCaml's format (its small
 * header: the magic number, the data's length, the blocks, their words
 * on 32 and on 64 bits; then the value depth first, a code each: an
 * integer, a string, a block and its fields, or a block met before, so
 * what is shared stays shared), the format lib_core's Marshal.ml writes
 * for mini-ml: a value written by the host's tiny-ml (OCaml's Marshal)
 * and by tiny-kernel's ml is the same bytes, when its blocks are. No
 * float, no custom block, no closure.
 *
 * Writing goes twice over the value, once to count the bytes, then
 * into the string made of that size: nothing is allocated meanwhile,
 * so nothing moves. A block met has its header marked (bit 8, its
 * number above it), the header kept in the trail, which is the
 * collector's other half, free between two collections; the headers
 * are put back at the end. Reading makes every block in one allocation
 * of the words the header says (as OCaml's intern), so no collection
 * happens while the blocks are filled; its table of the blocks read is
 * in the other half too. */
static value *trail;
static value ntrail;
static uchar *mout;     /* the bytes written, or 0: only counted */
static value mlen;
static value mwords32;
static value mwords64;
static value msharing;  /* 0: No_sharing asked (OCaml's: each copy
			 * written anew, no block counted) */

static void
mbyte(value b)
{
	if(mout)
		mout[mlen] = b;
	mlen++;
}

/* n's low bytes, the high one first */
static void
mput(value n, value bytes)
{
	value i;

	for(i = bytes - 1; i >= 0; i--)
		mbyte((n >> (8 * i)) & 255);
}

static void
mint(value n)
{
	if(n >= 0 && n < 64)
		mbyte(0x40 + n);
	else if(n >= -128 && n < 128){
		mbyte(0x00);
		mput(n, 1);
	}
	else if(n >= -32768 && n < 32768){
		mbyte(0x01);
		mput(n, 2);
	}
	else {
		mbyte(0x02);
		mput(n, 4);
	}
}

static void
extern_value(value v)
{
	value *p;
	value h;
	value n;
	value tag;
	value i;
	value len;
	value ago;

	for(;;){
		if(v & 1){
			mint(v >> 1);
			return;
		}
		p = (value*)v;
		h = p[-1];
		if(msharing && (h & 0x100)){
			ago = ntrail - (h >> 10);
			if(ago < 256){
				mbyte(0x04);
				mput(ago, 1);
			} else if(ago < 65536){
				mbyte(0x05);
				mput(ago, 2);
			} else {
				mbyte(0x06);
				mput(ago, 4);
			}
			return;
		}
		n = h >> 10;
		tag = h & 255;
		if(n == 0){
			mbyte(0x80 + tag);
			return;
		}
		if(msharing){
			if((ntrail + 1) * 2 > maxheap)
				fatal("Fatal error: Marshal.to_string: too many blocks\n");
			trail[2 * ntrail] = v;
			trail[2 * ntrail + 1] = h;
			p[-1] = (ntrail << 10) | 0x100 | tag;
			ntrail++;
		}
		if(tag == 252){
			len = n * W - 1 - ((uchar*)p)[n * W - 1];
			if(len < 32)
				mbyte(0x20 + len);
			else if(len < 256){
				mbyte(0x09);
				mput(len, 1);
			} else {
				mbyte(0x0A);
				mput(len, 4);
			}
			for(i = 0; i < len; i++)
				mbyte(((uchar*)p)[i]);
			mwords32 = mwords32 + 2 + len / 4;
			mwords64 = mwords64 + 2 + len / 8;
			return;
		}
		if(tag >= 247)
			fatal("Fatal error: Marshal.to_string: a closure, a float or a custom block\n");
		if(tag < 16 && n < 8)
			mbyte(0x80 + tag + n * 16);
		else {
			mbyte(0x08);
			mput(n * 1024 + tag, 4);
		}
		mwords32 = mwords32 + 1 + n;
		mwords64 = mwords64 + 1 + n;
		for(i = 0; i < n - 1; i++)
			extern_value(p[i]);
		/* (the last field in this loop: a long list is no deep stack) */
		v = p[n - 1];
	}
}

/* the value counted (out 0) or written into out; the headers put back */
static void
extern_pass(value v, uchar *out)
{
	value i;

	trail = other;
	ntrail = 0;
	mout = out;
	mlen = 20;
	mwords32 = 0;
	mwords64 = 0;
	extern_value(v);
	for(i = 0; i < ntrail; i++)
		((value*)trail[2 * i])[-1] = trail[2 * i + 1];
}

value
ml_marshal_to_string(value v, value flags)
{
	value s;
	value l;

	/* No_sharing, the flags' first constructor: 0, an integer */
	msharing = 1;
	for(l = flags; (l & 1) == 0; l = ((value*)l)[1])
		if(((value*)l)[0] == 1)
			msharing = 0;
	extern_pass(v, 0);
	push(v);
	s = string_alloc(mlen);
	v = pop();
	extern_pass(v, (uchar*)s);
	/* the header, now that its numbers are known */
	mlen = 0;
	mput(0x8495A6BE, 4);
	mput(length(s) - 20, 4);
	mput(ntrail, 4);
	mput(mwords32, 4);
	mput(mwords64, 4);
	return s;
}

/* Reading */
static uchar *min;
static value mpos;
static value *mobj;
static value nobj;
static value *mnext;   /* where the next block's header goes */
static value unfinished;

static value
mget(value bytes)
{
	value n;
	value i;

	n = 0;
	for(i = 0; i < bytes; i++){
		n = (n << 8) | min[mpos];
		mpos++;
	}
	return n;
}

static value
msigned(value bytes)
{
	value n;

	n = mget(bytes);
	if(bytes < 4 && (n >> (8 * bytes - 1)) != 0)
		n = n - (1 << (8 * bytes));
	return n;
}

static value
mstring(value len)
{
	value *b;
	value w;
	value i;

	w = len / W + 1;
	b = mnext + 1;
	b[-1] = (w << 10) | 252;
	b[w - 1] = 0;
	for(i = 0; i < len; i++)
		((uchar*)b)[i] = min[mpos + i];
	((uchar*)b)[w * W - 1] = w * W - 1 - len;
	mpos = mpos + len;
	mnext = b + w;
	mobj[nobj] = (value)b;
	nobj++;
	return (value)b;
}

static value intern_value(void);

/* a block of n fields: all but its last read, unfinished set */
static value
mblock(value tag, value n)
{
	value *b;
	value i;

	if(n == 0)
		return (value)&empty_array[1];
	b = mnext + 1;
	b[-1] = (n << 10) | tag;
	mnext = b + n;
	for(i = 0; i < n; i++)
		b[i] = 1;
	mobj[nobj] = (value)b;
	nobj++;
	for(i = 0; i < n - 1; i++)
		b[i] = intern_value();
	unfinished = 1;
	return (value)b;
}

/* the next item: a value, or a block whose last field is still to read */
static value
intern_item(void)
{
	value code;

	unfinished = 0;
	code = min[mpos];
	mpos++;
	if(code >= 0x80)
		return mblock(code & 15, (code >> 4) & 7);
	if(code >= 0x40)
		return (code & 63) * 2 + 1;
	if(code >= 0x20)
		return mstring(code & 31);
	if(code == 0x00)
		return msigned(1) * 2 + 1;
	if(code == 0x01)
		return msigned(2) * 2 + 1;
	if(code == 0x02)
		return msigned(4) * 2 + 1;
	if(code == 0x04)
		return mobj[nobj - mget(1)];
	if(code == 0x05)
		return mobj[nobj - mget(2)];
	if(code == 0x06)
		return mobj[nobj - mget(4)];
	if(code == 0x08){
		code = mget(4);
		return mblock(code & 255, code >> 10);
	}
	if(code == 0x09)
		return mstring(mget(1));
	if(code == 0x0A)
		return mstring(mget(4));
	fatal("Fatal error: Marshal.from_string: what this runtime does not read\n");
	return 1;
}

static value
intern_value(void)
{
	value v;
	value last;
	value b;

	v = intern_item();
	b = v;
	while(unfinished){
		last = intern_item();
		((value*)b)[wosize(b) - 1] = last;
		b = last;
	}
	return v;
}

value
ml_marshal_from_string(value s, value ofs)
{
	value words;
	value *chunk;

	ofs = ofs >> 1;
	min = (uchar*)s + ofs;
	mpos = 0;
	if(mget(4) != 0x8495A6BE)
		fatal("Fatal error: Marshal.from_string: bad object\n");
	mpos = 12;
	words = mget(4);
	if(words * 2 > maxheap)
		fatal("Fatal error: Marshal.from_string: too many blocks\n");
	if(words > 0){
		push(s);
		chunk = (value*)ml_alloc(words - 1, 0);
		s = pop();
		mnext = chunk - 1;
	}
	min = (uchar*)s + ofs;
	mpos = 20;
	mobj = other;
	nobj = 0;
	return intern_value();
}

/* SHA-1: the digest of a string, 20 bytes, in C on the machine's words
 * of 32 bits (old: TinyLibCore's Sha1 in ML, a word as two halves of
 * 16, as tiny-ml's integers have 31: 2.6 KB a second on tiny-kernel,
 * hours of tiny-build's digests in tiny-kernel's build of itself) */
static value sha_h[5];
static value sha_w[80];
static uchar sha_last[128];

/* a block of 64 bytes; a rotation left by n written out, x << n | x >>
 * (32 - n), the high bits that >> (arithmetic) brings masked off (tiny-c
 * has no macro with parameters, and a call each was a third of the
 * time) */
static void
sha_block(uchar *p)
{
	value x;
	value a;
	value b;
	value c;
	value d;
	value e;
	value f;
	value k;
	value t;
	value temp;

	for(t = 0; t < 16; t++)
		sha_w[t] = (p[4 * t] << 24) | (p[4 * t + 1] << 16) | (p[4 * t + 2] << 8) | p[4 * t + 3];
	for(t = 16; t < 80; t++){
		x = sha_w[t - 3] ^ sha_w[t - 8] ^ sha_w[t - 14] ^ sha_w[t - 16];
		sha_w[t] = (x << 1) | ((x >> 31) & 1);
	}
	a = sha_h[0];
	b = sha_h[1];
	c = sha_h[2];
	d = sha_h[3];
	e = sha_h[4];
	for(t = 0; t < 80; t++){
		if(t < 20){
			f = (b & c) | (~b & d);
			k = 0x5A827999;
		} else if(t < 40){
			f = b ^ c ^ d;
			k = 0x6ED9EBA1;
		} else if(t < 60){
			f = (b & c) | (b & d) | (c & d);
			k = 0x8F1BBCDC;
		} else {
			f = b ^ c ^ d;
			k = 0xCA62C1D6;
		}
		temp = ((a << 5) | ((a >> 27) & 31)) + f + e + k + sha_w[t];
		e = d;
		d = c;
		c = (b << 30) | ((b >> 2) & 0x3FFFFFFF);
		b = a;
		a = temp;
	}
	sha_h[0] = sha_h[0] + a;
	sha_h[1] = sha_h[1] + b;
	sha_h[2] = sha_h[2] + c;
	sha_h[3] = sha_h[3] + d;
	sha_h[4] = sha_h[4] + e;
}

value
ml_sha1_string(value s)
{
	value n;
	value i;
	value rest;
	value total;
	value bits;
	value r;
	uchar *p;

	sha_h[0] = 0x67452301;
	sha_h[1] = 0xEFCDAB89;
	sha_h[2] = 0x98BADCFE;
	sha_h[3] = 0x10325476;
	sha_h[4] = 0xC3D2E1F0;
	n = length(s);
	p = (uchar*)s;
	for(i = 0; i + 64 <= n; i = i + 64)
		sha_block(p + i);
	/* the rest, a 1 bit, zeros, the length in bits: one block or two */
	rest = n - i;
	for(total = 0; total < 128; total++)
		sha_last[total] = 0;
	for(total = 0; total < rest; total++)
		sha_last[total] = p[i + total];
	sha_last[rest] = 128;
	total = rest + 9 <= 64 ? 64 : 128;
	bits = n * 8;
	sha_last[total - 4] = (bits >> 24) & 255;
	sha_last[total - 3] = (bits >> 16) & 255;
	sha_last[total - 2] = (bits >> 8) & 255;
	sha_last[total - 1] = bits & 255;
	sha_block(sha_last);
	if(total == 128)
		sha_block(sha_last + 64);
	r = string_alloc(20);
	for(i = 0; i < 5; i++){
		((uchar*)r)[4 * i] = (sha_h[i] >> 24) & 255;
		((uchar*)r)[4 * i + 1] = (sha_h[i] >> 16) & 255;
		((uchar*)r)[4 * i + 2] = (sha_h[i] >> 8) & 255;
		((uchar*)r)[4 * i + 3] = sha_h[i] & 255;
	}
	return r;
}
