/* ocaml-light's mlvalues.h, for C compiled by mini-cc and linked with
 * mini-ml's code, over its runtime (runtime.c): the names ocaml-light's
 * and OCaml's have, so that C written for them says the same #include
 * <mlvalues.h>, and the directory searched (-I) says which runtime. The
 * kernels' C is the first (plan_kernel_mini_ml.md, decision 5). A value
 * is a word: an integer n as 2n+1, or a block's address. */
#ifdef __GNUC__
#include "gnu.h"
#else
#include <u.h>
#include <libc.h>
#endif

/* (for C that asks which runtime it is on: a kernel's processes) */
#define MINI_ML 1
#ifndef __GNUC__
#define NULL nil
#endif

typedef intptr value;
typedef uintptr uvalue;

#define W ((value)sizeof(value))
#define Val_long(n) ((((value)(n)) << 1) + 1)
#define Long_val(v) ((v) >> 1)
#define Val_int(n) Val_long(n)
#define Int_val(v) ((int)Long_val(v))
#define Val_unit Val_long(0)
#define Val_false Val_long(0)
#define Val_bool(b) ((b) ? Val_long(1) : Val_long(0))
#define Bool_val(v) (Long_val(v) != 0)
#define Is_int(v) (((v) & 1) != 0)

/* a block: its fields, its header the word before (the size in words
 * << 10, the tag in the low byte) */
#define Field(v, i) (((value*)(v))[i])
#define Hd(v) (((value*)(v))[-1])
#define Wosize(v) (((uvalue)Hd(v)) >> 10)
#define Tag(v) (Hd(v) & 255)
#define Closure_tag 247
/* a string's bytes, a float's double: no value in them */
#define String_tag 252
#define Bytes(v) ((uchar*)(v))
#define String_val(v) ((char*)(v))
#define Double_tag 253
#define Double_val(v) (*(double*)(v))
/* an int32 and an int64, boxed: their bits, which the collector doesn't
 * scan (a tag of 251 and above), compared and hashed by value */
#define Int32_tag 254
#define Int64_tag 255
#define Int32_val(v) (*(int*)(v))
#define Int64_val(v) (*(vlong*)(v))
