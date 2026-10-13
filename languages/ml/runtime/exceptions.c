/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A part of mini-ml's runtime: runtime.c includes it. */

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

/* Where an exception came from (the author, 2026-10-13, of a window
 * that stopped answering on the Pi 2 and "Thread 5 killed on uncaught
 * exception Invalid_argument("index out of bounds")" on the console:
 * "would be good to add stack traces"). No table says which function
 * called which: the machine's stack does. It has little else in
 * mini-ml's code, whose values are on a stack of their own: a
 * function's frame there is the address its call returns to. ml_raise
 * (the generated start: Gen) keeps the stack's 16 top words, or what
 * there is up to the handler's own, before it goes to the handler;
 * here, a word of them that is an address in the program's text, just
 * after a call's instruction, is taken for one: the innermost first,
 * the call's own address said (it is in the function that called).
 * A raise in C (an index out of bounds, a failwith) has C's frames
 * first, their other words among them: one that looks like a return
 * is a line too many. An exception caught and raised again says the
 * second raise. A help to find a bug, no more.
 * scripts/where.sh says the functions, by the map mini-ld writes
 * beside a program (-map).
 * On mini-9pi always; elsewhere when ML_TRACE is in the environment
 * (the tests compare what a program that dies says). Some forty
 * instructions more a raise when it is on, 3 when not. Not with
 * gcc's C: the text is not known to start at ml_start there.
 * old, tried first: only the stack pointer kept at the raise, and the
 * stack read when the trace was asked; the handler's own calls had
 * written over all of a shallow one by then. */
#define NTRACE 16
static char tbuf[NTRACE * 18 + 2];

#ifndef __GNUC__
extern char etext[];

static int
returns(uvalue w)
{
	unsigned int ins;

	if((w & 3) != 0 || w < (uvalue)ml_start + 8 || w > (uvalue)etext)
		return 0;
	ins = *(unsigned int*)(w - 4);
	if(sizeof(value) == 8)          /* arm64: BL, BLR */
		return (ins & 0xFC000000) == 0x94000000 || (ins & 0xFFFFFC1F) == 0xD63F0000;
	/* arm: BL; what writes the PC (5l's BL (R): ADD to R14, then to the PC); BLX */
	return (ins & 0x0F000000) == 0x0B000000 || (ins & 0x0C00F000) == 0x0000F000 || (ins & 0x0FFFFFF0) == 0x012FFF30;
}
#endif

/* the trace in tbuf, as text: the addresses in hexadecimal; its length */
static int
trace(void)
{
	int len;
#ifndef __GNUC__
	char d[20];
	int i, n, s;

	len = 0;
	n = ml_tracing ? NTRACE - ml_raise_left : 0;
	for(i = 0; i < n; i++)
		if(returns((uvalue)ml_raise_words[i])){
			s = digits((uvalue)ml_raise_words[i] - 4, 16, 0, d, 20);
			tbuf[len++] = ' ';
			memmove(tbuf + len, d + s, 20 - s);
			len += 20 - s;
		}
#else
	len = 0;
#endif
	tbuf[len] = 0;
	return len;
}

/* Printexc.get_backtrace's: "" when there is none */
value
ml_raise_trace(value unit)
{
	USED(unit);
	if(trace() == 0)
		return ml_string("");
	return ml_string(tbuf);
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
	int s, tlen;

	tlen = trace();
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
	if(tlen > 0){
		write(2, "raised at:", 10);
		write(2, tbuf, tlen);
		write(2, "\n", 1);
	}
	exit(2);
	return Val_unit;
}
