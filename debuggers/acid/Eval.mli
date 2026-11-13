(* acid's interpreter (principia's exec.c, expr.c, list.c). It runs the
 * statements and computes the expressions, as acid does.
 *
 * Its variables are dynamically scoped. A name is one variable, whose
 * value is a stack: a function's parameters and locals are pushed on
 * it at the call and popped at the return, so a function sees the
 * locals of its callers by their names. A parameter written *p gets
 * its argument's code (eval p runs it), and the other parameters get
 * their argument's value. The arguments are computed one after the
 * other, each one after the parameters before it are bound. A
 * statement that is an expression prints its value at the top level
 * (unless it is an assignment, a call, or an empty list), but not
 * inside a function. *)

exception Error of string

(* the builtin functions: each takes its arguments' values and returns
 * its result (the empty list for none) *)
val builtins : (string, Ast.value list -> Ast.value) Hashtbl.t

(* the memory, which Proc provides. [load core addr n] reads n bytes of
 * the process (core) or of the program's file (not core, for @); it
 * raises Error when the address is in no map. [store addr bytes]
 * writes into the process's memory. *)
val load : (bool -> int64 -> int -> string) ref
val store : (int64 -> string -> unit) ref

(* the size of the machine's address, which is what * reads for an a
 * or an A: 4 bytes on arm, 8 on arm64 (Proc's program sets it) *)
val addr_size : int ref

(* an address as the a format says it: a symbol and an offset *)
val symbol : (int64 -> string) ref

(* the address and size of f:v, which Proc provides: v is a parameter
 * or a local of f, in f's innermost frame (libmach's localaddr) *)
val local_addr : (string -> string -> int64 * int) ref

(* sets a global variable (for the program's symbols, the registers,
 * pid) *)
val set_global : string -> Ast.value -> unit

(* whether a variable has a value (for the lexer's M.x, a global of an
 * ML unit) *)
val is_set : string -> bool

(* a variable's value, with its complex type; raises Error if it has
 * none *)
val get : string -> Ast.value

(* the complex type that a variable was declared with (complex T v),
 * if there is one *)
val complex_type : string -> string option

(* a complex type's members (aggr T {...}), if T is one *)
val aggr : string -> Ast.member list option

(* calls acid's function [name] with [args], if it is defined (as
 * dostop calls stopped(pid)) *)
val call_if_defined : string -> Ast.value list -> unit

(* what is printed, kept until the caller writes it out *)
val out : Buffer.t

(* the builtin print: prints the values, then a newline at the top
 * level *)
val print : Ast.value list -> unit

(* a value as print prints it *)
val show : Ast.value -> string

(* whether a function is running (for print's newline, return, and
 * local) *)
val in_function : unit -> bool

(* runs a top-level statement: a statement, a definition, or a complex
 * type (this is the parser's action: Parser.mly) *)
val toplevel : Ast.toplevel -> unit

(* what is done after each statement that is not a definition (the
 * CLI sets it to write the output and the prompt, as acid's bigstmnt
 * does) *)
val ran : (unit -> unit) ref

(* after an error, pops the stacks of the functions the error left
 * (their parameters and locals) *)
val reset : unit -> unit
