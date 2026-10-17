/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* A part of mini-ml's runtime: runtime.c includes it. */

/*****************************************************************************/
/* Arrays, Obj */
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

/* (the compiler's own call, for a block it makes: no external names it) */
value
obj_block(value tag, value n)
{
	value b, i;

	b = ml_alloc(Long_val(n), Long_val(tag));
	for(i = 0; i < Long_val(n); i++)
		Field(b, i) = Val_unit;
	return b;
}
