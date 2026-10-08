/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A part of mini-ml's runtime: runtime.c includes it. */

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
