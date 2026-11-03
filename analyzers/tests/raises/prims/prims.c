/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */

/* a runtime's primitives, as languages/ml/runtime's: what each raises,
 * against Prims.ml's [@@raise] (bugs/raises.dl) */
typedef long value;

value caml_exn_Sys_error[2];
value caml_exn_Not_found[2];
value caml_exn_Failure[2];

static void raise_with(value *e, char *msg) { }
static void raise_const(value *e) { }
static void failwith(char *msg) { raise_with(caml_exn_Failure, msg); }
/* a wrapper, its argument the exception */
static void sys_error(value *e) { raise_with(e, "sys"); }

value my_open(value s) { if(s == 0) raise_with(caml_exn_Sys_error, "open"); return 0; }
value my_find(value k) { if(k == 0) raise_const(caml_exn_Not_found); return 0; }
value my_len(value s) { return 1; }
value my_parse(value s) { if(s == 0) failwith("parse"); return 0; }
value my_rename(value s) { if(s == 0) sys_error(caml_exn_Sys_error); return 0; }
