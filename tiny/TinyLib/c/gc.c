/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A part of mini-ml's runtime: runtime.c includes it. */

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

/* Both halves have been written after two collections, so a program
 * holds twice its heap: mini-ld built by mini-ml 267 MB to link
 * mini-rm, where 54 MB are alive (OCaml's holds 136), and sixty such
 * links at once, which is ix built by ix, do not fit in a machine of
 * 16 GB (GitHub's: make test-fixpoint there).
 * Tried, worked, and not kept: the half just emptied given back to the
 * system at the end of a collection (Linux's madvise, MADV_DONTNEED, on
 * its pages above what the next collection will copy there, for a heap
 * of 16 MB a half or more: a game's frames paid nothing). That link
 * 192 MB where it was 264, half a second of page faults in six, the
 * same bytes, on arm and arm64. But it is one system's call (not Plan 9's, not a kernel's),
 * conditionals in the collector for it, and the problem it was for is
 * the build's, solved there: a program links the units of the stdlib
 * it uses (mkconfig's STDOBJS, a library), no longer all of them. */
static value space0[MAXHEAP];
static value space1[MAXHEAP];
static value vstack[STACK];
static value *from;             /* the heap: from..ml_limit, allocated up to ml_hp */
static value *other;
/* (not static: mini-ml's code takes a block from the heap itself, Gen's
 * alloc_in_place, and calls ml_alloc when there is no room) */
value *ml_hp;
value *ml_limit;
static value size;
static value *lo;               /* the collector's: the space collected, */
static value *hi;
static value *next;             /* and where the next copy goes */
static value collections;       /* how many there were */

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
/* (TinyLib: one, the program's: no thread, no kernel) */
#define STACKS 1
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
	hi = ml_limit;
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
		/* (a unit named by the start and not linked: mini-ld's weak) */
		if(roots == nil)
			continue;
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
	ml_hp = next;
	collections++;
}

/* Gc.set's space_overhead, OCaml's name for it: how much more than what
 * is alive the heap is let to be, in hundredths of it. 100, the heap
 * twice what is alive, is what this collector always did; a program
 * that makes much and keeps little (a game: a frame's floats) asks for
 * more, and is collected that much less often: each collection copies
 * all that is alive. */
static value overhead = 100;

/* if less than half is free after (the overhead's share), the heap
 * grows, up to its halves
 * old: while((ml_hp - from + need) * 2 > size && size < MAXHEAP)
 * (tried, and not kept: a half grown to just what is alive and its
 * overhead, where doubling leaves it up to twice that: mini-ld's link
 * of mini-rm 5% less memory, 16% longer, a collection coming sooner) */
static void
gc(value need)
{
	collect();
	while((uvlong)(ml_hp - from + need) * (100 + overhead) / 100 > (uvlong)size && size < MAXHEAP)
		size = size * 2;
	if(size > MAXHEAP)
		size = MAXHEAP;
	ml_limit = from + size;
	if(ml_hp + need > ml_limit)
		fatal("Fatal error: out of memory\n");
}

value
ml_alloc(value n, value tag)
{
	value *p;

	if(ml_hp + n + 1 > ml_limit)
		gc(n + 1);
	p = ml_hp + 1;
	p[-1] = (n << 10) | tag;
	ml_hp = p + n;
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
