/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A part of mini-ml's runtime: runtime.c includes it. */

/*****************************************************************************/
/* The heap: two halves in the bss, Cheney's collector, and a young generation */
/*****************************************************************************/

/* a half's words, at most: 512 MB on 64 bits (a link of ix's is 200 MB
 * of blocks), 256 on 32 (it was 32: mini-ld built for arm could not
 * link itself). They are the bss: the pages not touched are not
 * memory. (A kernel gives its own, -DMAXHEAP and -DSTACK: its bss is
 * the board's memory, cleared at the start.) */
#ifndef MAXHEAP
#ifdef plan9
/* (mini-9pi's processes: 512 MB of addresses each, the stack's 8 at
 * their top: here 192 MB a half, the value stack, a large thread's
 * and the program beside. A half was 64 MB (16 M words): Hacker
 * News's comments in mini-netscape are 57.6 MB alive, the page before
 * kept besides. Memory only as a half grows to it: the author, "My pi2
 * has 1GB of memory, so no reason to limit ourselves to 64MB") */
#define MAXHEAP 50331648
#define STACK 1048576
#else
#define MAXHEAP 67108864
#define STACK 4194304           /* the value stack's */
#endif
/* and as much again past its end, pages no one touches but a recursion
 * too deep, seen at the next collection (collect); a kernel's has none */
#define GUARD STACK
#endif
/* a half's words at the start (ML_HEAP says another); it doubles when
 * less than half is free after a collection */
#ifndef HEAPSTART
#ifdef plan9
/* (4 MB on mini-9pi: a compile by mini-ml on the card collected
 * from 1 MB up, 5% of its time; 16 MB gave no more,
 * plan_self_hosting.md) */
#define HEAPSTART (1 << 20)
#else
#define HEAPSTART (1 << 18)
#endif
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
#ifdef GUARD
static value vstack[STACK + GUARD];
#else
static value vstack[STACK];
#endif
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
/* the program's machine stack's top (main's frame), for a stack
 * overflow's calls (exceptions.c's overflowed) */
static char *machine_top;
static void overflowed(char*, char*, char*);
static value top;               /* the largest half so far, in words */
static value live;              /* what was alive after the last one, in words */

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
/* (256 threads at once: a window system has one a window) */
#define STACKS 257
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

/* Threads (lib_core/concurrency's Thread, whose scheduler is OCaml's:
 * plan_rio.md). A thread is a value stack (the stacks above: 0 the
 * program's) and a machine stack, in one piece of memory: the
 * machine's grows down from its middle, the values' up from there.
 * Its context is what a switch keeps of a thread that does not run
 * (ml_swtch, the start object's: mini-ml's Gen): the machine's stack
 * pointer, where to return, the value stack's register. A new one
 * starts at thread_entry, on its own stacks, the function it runs the
 * first value of its stack (a root, as the rest). Cooperative: a
 * switch is a call, so nothing else is in a register. Not with gcc's C
 * (it keeps values in registers across a call). */
#ifndef __GNUC__
#define TSTACK (256 * 1024)	/* a thread's machine stack, in bytes */
#define TVALUES 32768		/* and its value stack, in words */
/* A large thread (Thread.create_large: mini-netscape's worker, which
 * lays out a page as the program's first thread did) has the
 * program's value stack, and a machine stack as large in bytes:
 * TVALUES was a List.map over Hacker News's page, past the end of the
 * memory, a fault (bugs/ix.md; 47 KB of the machine's used for 128 KB
 * of values). Each stack has a guard as large as itself on the side
 * it grows to, as the program's value stack (vstack's): pages no one
 * touches but an overflow, seen by collect. A thread's memory:
 *
 *   | guard | machine stack <- | -> value stack | guard |
 *
 * Addresses, not memory: a page is the system's at its first touch. */
#define LVALUES STACK
static value thread_context[STACKS][3];
static char *thread_memory[STACKS];
static char thread_used[STACKS];
/* each one's memory made large, its machine stack's bytes and its value stack's words */
static char thread_large[STACKS];
static value thread_machine[STACKS];
static value thread_values[STACKS];
extern void ml_swtch(value**);
extern value callback(value, value);
static void fatal(char*);
static void *m_alloc(value);

static void
thread_entry(void)
{
	callback(stack_base[stack_now][0], Val_unit);
	fatal("Fatal error: a thread's function returned\n");	/* (Thread.create's ends by Thread.exit) */
}

value
thread_new(value large, value f)
{
	value *base;
	int i, l, machine;

	/* (a number free whose memory is of the size asked, or has none:
	 * memory is not given back, a large one not made again) */
	l = Bool_val(large);
	for(i = 1; i < STACKS && (thread_used[i] || (thread_memory[i] != nil && thread_large[i] != l)); i++)
		;
	if(i == STACKS)
		failwith("Thread.create: too many threads");
	if(thread_memory[i] == nil){
		thread_values[i] = l ? LVALUES : TVALUES;
		thread_machine[i] = l ? LVALUES * sizeof(value) : TSTACK;
		thread_memory[i] = m_alloc(2 * thread_machine[i] + 2 * thread_values[i] * sizeof(value));
		thread_large[i] = l;
	}
	thread_used[i] = 1;
	machine = 2 * thread_machine[i];
	base = (value*)(thread_memory[i] + machine);
	ml_stack(i, base);
	base[0] = f;
	stack_top[i] = base + 1;
	thread_context[i][0] = (value)(thread_memory[i] + machine - 64);
	thread_context[i][1] = (value)thread_entry;
	thread_context[i][2] = 0;
	return Val_int(i);
}

value
thread_switch(value to)
{
	value *pair[2];
	int from;

	from = stack_now;
	if(Long_val(to) == from)
		return Val_unit;
	pair[0] = thread_context[from];
	pair[1] = thread_context[Long_val(to)];
	ml_stack_switch(Long_val(to));
	ml_swtch(pair);
	return Val_unit;
}

/* a finished thread's number free again, its stack empty for the collector */
value
thread_free(value t)
{
	int i;

	i = Long_val(t);
	if(i > 0 && i < STACKS && i != stack_now){
		thread_used[i] = 0;
		ml_stack(i, stack_base[i]);
	}
	return Val_unit;
}
#endif

/* OPTIMIZATION (generations): the young generation, OCaml's minor heap.
 * Every block is made here (ml_hp and ml_limit are its), and most are
 * dead before it is full: a minor collection copies what is alive of
 * it to the half, the old generation, where it stays until a major
 * one (the halves' Cheney, as before, both generations at once). So a
 * collection copies the young survivors, not everything alive: mini-ml
 * compiling its Typing.ml spent a quarter of its instructions copying
 * the same interfaces again at each collection.
 *
 *     young: [made ... ml_hp | free ]      minor: the alive to old_hp
 *     half:  [old blocks ... old_hp | free to from + size ]
 *
 * The roots of a minor collection are the major's (the stacks, the
 * globals) and the old fields that point to a young block: each store
 * of a block in a field (Ir's SetField and SetIndex) goes through
 * ml_modify (the start object's: Gen.startup), which remembers the
 * field when the value is young and the field old, in refs. A block
 * too large for the young generation is made in the half, after a
 * minor collection (its fields then point to nothing young).
 * Off with ML_YOUNG=0, and with gcc's C (-gas: its code has no
 * barrier): every block in the half, as before.
 * old: one generation, the halves; ml_hp and ml_limit the half's
 * (young_words 0) */
#ifndef YOUNG
#define YOUNG (MAXHEAP / 16 < 1048576 ? MAXHEAP / 16 : 1048576)
#endif
static value young[YOUNG];
static value young_words;       /* 0: no young generation */
static value *old_hp;           /* the half's next free word (young_words) */
value *ml_young_lo;             /* the young generation, for ml_modify */
value *ml_young_hi;
/* the old fields remembered; when full, the last one written again
 * and refs_lost said: the next minor collection scans all the old.
 * OPTIMIZATION (refs_soon): at seven eighths of it (ml_refs_end), a
 * minor collection asked for (ml_limit at ml_hp: the next allocation
 * makes it), the table's last eighth for the stores until then
 * (ml_refs_hard). A loop that stores many blocks and makes few was a
 * scan of the whole old generation at each minor collection
 * (mini-virtuaracing's frame on arm: each float stored in an array a
 * new block, once its arithmetic made none, plan_ml_floats.md).
 * old: ml_refs_end the table's end, lost when reached */
#define REFS (YOUNG / 16 < 4096 ? 4096 : YOUNG / 16)
static value *refs[REFS];
value **ml_refs;
value **ml_refs_end;
value **ml_refs_hard;
value ml_refs_lost;
static value minors;            /* the minor collections */

/* a value's copy in to-space: an integer or a pointer outside the
 * spaces collected (lo..hi, and lo2..hi2: a major collection's young
 * generation) as is; a copied block's header is 0, its first field the
 * copy's address (every block has a field: an empty array is static) */
static value *lo2, *hi2;

static value
copy(value v)
{
	value *p, *q;
	value h, n, i;

	p = (value*)v;
	if(Is_int(v) || ((p < lo || p >= hi) && (p < lo2 || p >= hi2)))
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

/* the fields of the blocks from scan to next copied, next chasing scan
 * (Cheney's breadth first) */
static void
scan_copies(value *scan)
{
	value n, i, h;

	for(; scan < next; scan = scan + n + 1){
		h = *scan;
		n = ((uvalue)h) >> 10;
		if((h & 255) < 251)
			for(i = 1; i <= n; i++)
				scan[i] = copy(scan[i]);
	}
}

/* the roots copied: the stacks, C's values, the globals */
static void
copy_roots(void)
{
	value *v, *roots;
	value i, u;
	struct caml__roots_block *b;

#ifdef GUARD
	/* The ML code does not check the value stack's end: a recursion
	 * too deep wrote past it, over the statics that follow (stack_now,
	 * stack_roots: this scan followed an integer as a block, a crash
	 * of nowhere, mini-netscape on YouTube's style sheet; bugs/ix.md).
	 * Into the guard now, and said, by ml_vsp alone (the statics are
	 * what an overflow past the guard would have written over). A
	 * fatal error, not a Stack_overflow to catch: raised from inside an
	 * allocation. */
	if(ml_vsp > vstack + STACK && ml_vsp <= vstack + STACK + GUARD)
		overflowed("Fatal error: stack overflow (mini-ml's value stack)", (char*)&v, stack_now > 0 ? nil : machine_top);
#ifndef __GNUC__
	/* (a thread's, into one of its guards: its machine stack's is
	 * below, where this frame is) */
	if(stack_now > 0 && ml_vsp > stack_base[stack_now] + thread_values[stack_now])
		overflowed("Fatal error: stack overflow (a thread's value stack)", (char*)&v, thread_memory[stack_now] + 2 * thread_machine[stack_now]);
	if(stack_now > 0 && (char*)&v < thread_memory[stack_now] + thread_machine[stack_now])
		overflowed("Fatal error: stack overflow (a thread's machine stack)", (char*)&v, thread_memory[stack_now] + 2 * thread_machine[stack_now]);
#endif
#endif
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
}

/* the young generation empty again, nothing remembered */
static void
young_empty(void)
{
	ml_hp = young;
	ml_limit = young + young_words;
	ml_refs = refs;
	ml_refs_end = refs + REFS - REFS / 8;
	ml_refs_hard = refs + REFS;
	ml_refs_lost = 0;
}

/* a major collection: the half's blocks and the young ones copied to
 * the other half, the halves swapped */
static void
collect(void)
{
	lo = from;
	hi = young_words ? old_hp : ml_hp;
	lo2 = young_words ? young : nil;
	hi2 = young_words ? ml_hp : nil;
	next = other;
	copy_roots();
	scan_copies(other);
	other = from;
	from = lo == space0 ? space1 : space0;
	lo2 = hi2 = nil;
	if(young_words){
		old_hp = next;
		young_empty();
	}else
		ml_hp = next;
	collections++;
}

/* a minor collection: the young blocks alive copied to the half, after
 * its last; their roots the major's and the remembered fields (or every
 * old block's, when some were lost) */
static void
minor(void)
{
	value **r;
	value *start;

	lo = young;
	hi = ml_hp;
	lo2 = hi2 = nil;
	next = old_hp;
	start = old_hp;
	copy_roots();
	if(ml_refs_lost)
		scan_copies(from);
	else
		for(r = refs; r < ml_refs; r++)
			**r = copy(**r);
	scan_copies(start);
	old_hp = next;
	young_empty();
	minors++;
}

/* a store of v in a field of C's (memory.h's Store_field): ml_modify's
 * test, for C */
void
ml_store(value *field, value v)
{
	*field = v;
	if(!Is_int(v) && (value*)v >= ml_young_lo && (value*)v < ml_young_hi
	&& (field < ml_young_lo || field >= ml_young_hi)){
		if(ml_refs == ml_refs_end){
			ml_limit = ml_hp;
			if(ml_refs_end == ml_refs_hard){
				ml_refs--;
				ml_refs_lost = 1;
			}else
				ml_refs_end = ml_refs_hard;
		}
		*ml_refs++ = field;
	}
}

/* Gc.set's space_overhead, OCaml's name for it: how much more than what
 * is alive the heap is let to be, in hundredths of it. 100, the heap
 * twice what is alive, is what this collector always did; a program
 * that makes much and keeps little (a game: a frame's floats) asks for
 * more, and is collected that much less often: each collection copies
 * all that is alive. */
static value overhead = 100;

/* a major collection; if less than half is free after (the overhead's
 * share), the heap grows, up to its halves
 * old: while((ml_hp - from + need) * 2 > size && size < MAXHEAP)
 * (tried, and not kept: a half grown to just what is alive and its
 * overhead, where doubling leaves it up to twice that: mini-ld's link
 * of mini-rm 5% less memory, 16% longer, a collection coming sooner) */
static void
major(value need)
{
	value *hp;

	collect();
	hp = young_words ? old_hp : ml_hp;
	live = hp - from;
	while((uvlong)(hp - from + need) * (100 + overhead) / 100 > (uvlong)size && size < MAXHEAP)
		size = size * 2;
	if(size > MAXHEAP)
		size = MAXHEAP;
	if(size > top)
		top = size;
	if(!young_words)
		ml_limit = from + size;
	if(hp + need > from + size)
		fatal("Fatal error: out of memory\n");
}

/* OPTIMIZATION (old_reads): what Marshal reads made in the half
 * itself, not in the young generation: ml_hp and ml_limit the half's
 * between ml_old_begin and ml_old_end (Marshal.from_string's), the
 * young generation's kept aside. What is read is kept, most of it (a
 * link's objects, a unit's interfaces): made young, it was copied at
 * the next minor collection and scanned again, a block at a time
 * (OCaml's intern.c reserves the whole value in the major heap, its
 * intern_alloc). A collection meanwhile is made as without, the young
 * generation's pointers back (gc). The blocks read point only to
 * blocks read: none is remembered. */
static value old_reading;       /* how deep in Marshal's reading */
static value *young_hp, *young_limit;

static void
old_leave(void)
{
	old_hp = ml_hp;
	ml_hp = young_hp;
	ml_limit = young_limit;
}

static void
old_enter(void)
{
	young_hp = ml_hp;
	young_limit = ml_limit;
	ml_hp = old_hp;
	ml_limit = from + size;
}

value
ml_old_begin(value u)
{
	if(young_words && old_reading++ == 0)
		old_enter();
	return u;
}

value
ml_old_end(value u)
{
	if(young_words && --old_reading == 0)
		old_leave();
	return u;
}

/* need words, in the young generation (a minor collection, then a major
 * one when the half is past its size), or in the half */
static void
gc(value need)
{
	if(!young_words){
		major(need);
		return;
	}
	if(old_reading)
		old_leave();
	/* (the half holds the young survivors, at most all of it, as its
	 * memory goes to MAXHEAP: else a major collection first) */
	if(old_hp + (ml_hp - young) > from + MAXHEAP)
		major(0);
	else
		minor();
	if(old_hp + need > from + size)
		major(need);
	if(old_reading)
		old_enter();
}

/* Gc's: a collection, whichever was asked */
value gc_full_major(value u) { gc(0); if(young_words) major(0); return u; }
value gc_major(value u) { gc(0); if(young_words) major(0); return u; }
value gc_minor(value u) { gc(0); return u; }
value gc_compaction(value u) { gc(0); if(young_words) major(0); return u; }
/* (Marshal's: the blocks moved, and the addresses it kept are old) */
value gc_collections(value u) { return Val_int(collections + minors); }

value
ml_alloc(value n, value tag)
{
	value *p;

	/* (larger, the header would say another size: the collector then
	 * walks garbage; Array.make and Bytes.create raise before) */
	if((uvalue)n > Max_wosize)
		fatal("Fatal error: a block too large\n");

	if(ml_hp + n + 1 > ml_limit){
		/* a large block in the half, the young ones moved first */
		if(young_words && !old_reading && n + 1 > young_words / 2){
			gc(n + 1);
			p = old_hp + 1;
			p[-1] = (n << 10) | tag;
			old_hp = p + n;
			return (value)p;
		}
		gc(n + 1);
	}
	p = ml_hp + 1;
	p[-1] = (n << 10) | tag;
	ml_hp = p + n;
	return (value)p;
}

/* Gc.get and Gc.set: OCaml's record of four, of which the heap's size
 * (read only) and the overhead mean something here */
value
gc_get(value u)
{
	value r;

	r = ml_alloc(4, 0);
	Field(r, 0) = Val_int(size);
	Field(r, 1) = Val_int(0);
	Field(r, 2) = Val_int(overhead);
	Field(r, 3) = Val_int(0);
	return r;
}

value
gc_set(value c)
{
	overhead = Long_val(Field(c, 2));
	if(overhead < 100)
		overhead = 100;
	return Val_unit;
}

/* Gc.stat's: the collections, a half's words now and at most so far,
 * the words alive after the last collection */
value
gc_counters(value u)
{
	value r;

	r = ml_alloc(4, 0);
	Field(r, 0) = Val_int(collections);
	Field(r, 1) = Val_int(size);
	Field(r, 2) = Val_int(top > size ? top : size);
	Field(r, 3) = Val_int(live);
	return r;
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
