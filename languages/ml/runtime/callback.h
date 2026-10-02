/* ocaml-light's callback.h, over mini-ml's runtime (mlvalues.h here
 * says how): C calls ML. A named value's address stays the same, and
 * the collector keeps what is there up to date. */
value callback(value f, value a);
value callback2(value f, value a, value b);
value *caml_named_value(char *name);
