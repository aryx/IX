/* ocaml-light's alloc.h, over mini-ml's runtime (mlvalues.h says how):
 * blocks made from C. A tuple's fields are not set: the C sets them
 * before it allocates again. */
value ml_alloc(value n, value tag);
value ml_string(char *s);
value create_string(value n);
value ml_string_length(value s);

#define alloc(n, tag) ml_alloc(n, tag)
#define alloc_tuple(n) ml_alloc(n, 0)
#define alloc_string(n) create_string(Val_long(n))
#define copy_string(s) ml_string(s)
#define string_length(s) Long_val(ml_string_length(s))
