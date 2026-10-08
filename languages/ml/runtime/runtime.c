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

#ifdef plan9
/* Plan 9's status is a string: none for 0, else the number's digits
 * (as rc's exit 3; the libc's exit says "error" for all) */
static void
exit_status(int n)
{
	char buf[16];

	if(n == 0)
		exits(nil);
	snprint(buf, sizeof buf, "%d", n);
	exits(buf);
}
#define exit exit_status
#endif

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
#include "md5.c"         /* Digest: MD5 */
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
value
sys_chdir(value name)
{
#ifdef plan9
	if(chdir((char*)Bytes(name)) < 0)
#else
	if(ux(W == 8 ? 49 : 12, (value)Bytes(name), 0, 0, 0, 0, 0) < 0)
#endif
		raise_with(caml_exn_Sys_error, (char*)Bytes(name));
	return Val_unit;
}

value
sys_time(value unit)
{
	value t[2];

#ifdef plan9
	/* Plan 9's /dev/cputime: the process's milliseconds in its own
	 * code, then in the kernel's (two of six numbers of 12 bytes);
	 * 0 where the file is not */
	char buf[64];
	int fd, n;

	t[0] = t[1] = 0;
	fd = open("/dev/cputime", OREAD);
	if(fd >= 0){
		n = read(fd, buf, sizeof buf - 1);
		close(fd);
		if(n > 12){
			buf[n] = 0;
			n = atoi(buf) + atoi(buf + 12);
			t[0] = n / 1000;
			t[1] = (n % 1000) * 1000000;
		}
	}
#else
	ux(W == 8 ? 113 : 263, 2, (value)t, 0, 0, 0, 0);
#endif
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
