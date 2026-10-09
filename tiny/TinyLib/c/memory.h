/* ocaml-light's memory.h, over mini-ml's runtime (mlvalues.h says how):
 * a C function's own values, for a collector that moves them. A
 * function that allocates, or calls ML, while it holds values declares
 * its parameters with CAMLparam and its locals with CAMLlocal (once
 * each), and returns with CAMLreturn; a store in a block is a store
 * (no generations: nothing to remember). */
struct caml__roots_block {
	struct caml__roots_block *next;
	value *v[3];
};
extern struct caml__roots_block *local_roots;
void ml_root(struct caml__roots_block *b, value *v0, value *v1, value *v2);

#define CAMLparam0() struct caml__roots_block *caml__frame = local_roots
#define CAMLparam1(a) CAMLparam0(); struct caml__roots_block caml__p; ml_root(&caml__p, &a, nil, nil)
#define CAMLparam2(a, b) CAMLparam0(); struct caml__roots_block caml__p; ml_root(&caml__p, &a, &b, nil)
#define CAMLlocal1(a) value a = Val_unit; struct caml__roots_block caml__l; ml_root(&caml__l, &a, nil, nil)
#define CAMLlocal2(a, b) value a = Val_unit, b = Val_unit; struct caml__roots_block caml__l; ml_root(&caml__l, &a, &b, nil)
#define CAMLreturn(x) { local_roots = caml__frame; return (x); }
#define CAMLreturn0 { local_roots = caml__frame; return; }

#define Store_field(b, i, v) (Field(b, i) = (v))
#define modify(fp, v) (*(fp) = (v))
