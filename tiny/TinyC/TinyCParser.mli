type storage = Auto | Static | Extern | Typedef
type var = { vty : TinyCTypes.ty; where : TinyCTree.place; }
val toks : TinyCLexer.token array ref
val pos : int ref
val locs : TinyCLexer.loc array ref
val peek : unit -> TinyCLexer.token
val next : unit -> TinyCLexer.token
val accept : string -> bool
val expect : string -> unit
val globals : (string, var) Hashtbl.t
val typedefs : (string, TinyCTypes.ty) Hashtbl.t
val scopes : (string, var) Hashtbl.t list ref
val frame : int ref
val result : TinyCTypes.ty ref
val data : Buffer.t
val sym : string -> string
type datum = Bytes of string | Value of int * int64 | Address of string
val datum : string -> int -> datum -> unit
val word : int64 -> string
val globl : string -> int -> unit
val base_type : unit -> storage * TinyCTypes.ty
val declarator3 : TinyCTypes.ty -> string * TinyCTypes.ty * string list
val assign_expr : unit -> TinyCTree.expr
val block : unit -> TinyCTree.stmt

