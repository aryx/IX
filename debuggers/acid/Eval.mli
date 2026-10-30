(* acid's interpreter (principia's exec.c, expr.c, list.c): the
 * statements run, the expressions computed, as acid does.
 *
 * Its variables are dynamically scoped: a name is one variable, whose
 * value is a stack, a function's parameters and locals pushed on it at
 * the call and popped at its return, so a function sees its callers'
 * locals by their names. A parameter written *p gets its argument's
 * code (eval p runs it), the others its value, the arguments computed
 * one after the other, each after the parameters before it are bound.
 * A statement that is an expression prints its value at the top level
 * (not an assignment nor a call, not an empty list), not inside a
 * function. *)

exception Error of string

(* a builtin function: its arguments' values, its result (the empty
 * list for none) *)
val builtins : (string, Ast.value list -> Ast.value) Hashtbl.t

(* the memory (Proc's): [load core addr n], n bytes of the process
 * (core) or of the program's file (not core: @); Error when the
 * address is in no map. [store addr bytes] writes the process's *)
val load : (bool -> int64 -> int -> string) ref
val store : (int64 -> string -> unit) ref

(* an address as the a format says it: a symbol and an offset *)
val symbol : (int64 -> string) ref

(* a global variable set (the program's symbols, the registers, pid) *)
val set_global : string -> Ast.value -> unit

(* acid's function [name] called with [args], if it is defined (dostop's
 * stopped(pid)) *)
val call_if_defined : string -> Ast.value list -> unit

(* what is printed, until the caller writes it out *)
val out : Buffer.t

(* print's: the values printed, then a newline at the top level *)
val print : Ast.value list -> unit

(* a value as print prints it *)
val show : Ast.value -> string

(* whether a function is running (print's newline, return, local) *)
val in_function : unit -> bool

(* a top-level statement run: a statement, a definition, a complex type
 * (the parser's action: Parser.mly) *)
val toplevel : Ast.toplevel -> unit

(* what is done after each statement, not a definition (the CLI's: the
 * output written, the prompt: acid's bigstmnt's) *)
val ran : (unit -> unit) ref

(* after an error: the stacks of the functions it left (their
 * parameters and locals) popped *)
val reset : unit -> unit
