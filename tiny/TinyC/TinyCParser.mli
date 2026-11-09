(* tiny-c's parser: C's declarations, statements and expressions read
 * from the tokens, recursive descent, the tree built typed as it reads
 * (TinyCTree's functions); and the globals' data, written in the
 * assembly's DATA. TinyC.ml reads the file's declarations with it.
 * Read TinyCTree.mli first. *)

type storage = Auto | Static | Extern | Typedef

(* a name's type and place *)
type var = { vty : TinyCTypes.ty; where : TinyCTree.place; }

(* the tokens, the position of the next, and each token's file and line *)
val toks : TinyCLexer.token array ref
val pos : int ref
val locs : TinyCLexer.loc array ref
val peek : unit -> TinyCLexer.token
val next : unit -> TinyCLexer.token
(* the next token if it is that punctuation *)
val accept : string -> bool
val expect : string -> unit

(* the names: the globals, the typedefs, the current function's scopes
 * (innermost first), its locals' size and its result's type *)
val globals : (string, var) Hashtbl.t
val typedefs : (string, TinyCTypes.ty) Hashtbl.t
val scopes : (string, var) Hashtbl.t list ref
val frame : int ref
val result : TinyCTypes.ty ref

(* the DATA and GLOBL of the globals *)
val data : Buffer.t
(* a piece of a global's initial value: bytes, an integer of a size,
 * an address *)
type datum = Bytes of string | Value of int * int64 | Address of TinyCTypes.sym
(* [datum g off d]: d in g's data, at that offset *)
val datum : TinyCTypes.sym -> int -> datum -> unit
(* [globl g n]: g's label and data in data, n bytes *)
val globl : TinyCTypes.sym -> int -> unit

(* a declaration's storage and base type (int, struct s...); then a
 * declarator's name, type, and its parameters' names, for a function *)
val base_type : unit -> storage * TinyCTypes.ty
val declarator3 : TinyCTypes.ty -> string * TinyCTypes.ty * string list
val assign_expr : unit -> TinyCTree.expr
(* a function's body *)
val block : unit -> TinyCTree.stmt
