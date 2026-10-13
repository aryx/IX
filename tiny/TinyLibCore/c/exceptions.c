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
