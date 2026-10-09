/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* TinyLib: languages/ml/runtime/'s, the part the tiny programs need, for
 * Linux on arm64, over libc.c here (tiny/TinyLib/README.md). */
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

/* (a word each: a long is 32 bits for mini-cc, a pointer would lose its half) */
#define ux _syscall6
#include "libc.c"        /* TinyLib's C library, the functions */

extern void ml_start(value*);
extern void ml_raise(value);
extern value ml_callback(value, value);
extern double ml_fsqrt(double);
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

/* The runtime's parts, a file each, in this order: a part may use what
 * is before it. One C file for the compiler all the same (the static
 * functions and the heap's size, a -D, are the whole runtime's). */
#include "gc.c"          /* the heap: two halves, Cheney's collector */
#include "strings.c"     /* strings and bytes */
#include "exceptions.c"  /* the predefined exceptions, raising from C, the uncaught one */
#include "compare.c"     /* compare and hash */
#include "arrays.c"      /* arrays, Obj, Callback */
#include "io.c"          /* the channels */
#include "sys.c"         /* Sys: files, the arguments, commands, signals */
#include "floats.c"      /* floats */
#include "ints.c"        /* Int32 and Int64 */
#include "unix.c"        /* Unix: a system call by its number */

/*****************************************************************************/
/* Not yet: the others below */
/*****************************************************************************/

/* the stdlib's other externals, which a unit's closure of its externals
 * names (Lower's Iexternal): each fails when called. The list is the
 * stdlib's non-% primitives this file doesn't define (the
 * floats' functions, Gc, and some of Sys) */
/* by Linux's numbers: chdir, and clock_gettime of the process's
 * processor time (the clock 2), its seconds and nanoseconds a word each */

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
	ml_hp = from;
	ml_limit = from + size;
	ml_vsp = vstack;
	ml_stack(0, vstack);
	push(ml_string("index out of bounds"));
	bound_exn = ml_alloc(2, 0);
	Field(bound_exn, 0) = (value)(caml_exn_Invalid_argument + 1);
	Field(bound_exn, 1) = pop();
	ml_start(vstack);
	exit(0);
}
