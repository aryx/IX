(* What goes with Tree's types: the tables of the kinds (which
 * operator takes which kinds), the names, the symbol table, the
 * functions that make nodes and types, and the diagnostics. Tree has
 * the types alone. *)
open Tree

(* the sets of kinds, named by the initials of their members, as in
 * sub.c: typechlp is char, short, long (of each sign) and pointer *)
val typei : etype -> bool
val typeu : etype -> bool
val typesuv : etype -> bool
val typeilp : etype -> bool
val typechl : etype -> bool
val typechlv : etype -> bool
val typechlvp : etype -> bool
val typechlp : etype -> bool
val typev : etype -> bool
val typefd : etype -> bool
val typeaf : etype -> bool
val typesu : etype -> bool

(* whether an operator takes a left and a right operand of these kinds
 * (sub.c's tables) *)
val tasign : etype -> etype -> bool
val tasadd : etype -> etype -> bool
val tadd : etype -> etype -> bool
val tsub : etype -> etype -> bool
val tmul : etype -> etype -> bool
val tand : etype -> etype -> bool
val trel : etype -> etype -> bool
val tcast : etype -> etype -> bool
val tfunct : 'a -> etype -> bool
val tindir : 'a -> etype -> bool
val tdots : 'a -> etype -> bool
val tnot : 'a -> etype -> bool
val targ : 'a -> etype -> bool

(* the type of l op r (sub.c's tab: double op float is float) *)
val arith_tab : etype -> etype -> etype

(* the integral promotion, Plan 9's, which is unsigned preserving *)
val promote : etype -> etype

val cname : cls -> string

(* a type's qualifiers, as bits *)
val gconstnt : int
val gvolatile : int

val binop_name : binop -> string
val unop_name : unop -> string

(* whether an operator is a relation, Eq ... Hs *)
val is_rel : binop -> bool

val mach : machine option ref
val m : unit -> machine

(* the width of each kind; a pointer's width is the machine's *)
val ewidth : etype -> int

(* a conversion that makes no code (txt.c's ncast) *)
val ncast : etype -> etype -> bool

(* a constant truncated and extended as a value of the type *)
val convvtox : int64 -> etype -> int64

(* the line being read, and the one diagnosed *)
val lineno : int ref
val nearln : int ref

val typ : etype -> typ option -> typ
val copytyp : typ -> typ

(* the type of an expression before typing, or of an undeclared name *)
val untyped : typ

(* the basic types, one of each kind, made by init_types *)
val ty : etype -> typ
val init_types : unit -> unit

(* an untyped expression at the line being read; mk_typed makes one of
 * type t (for another line, write { (mk e) with line }) *)
val mk : kind -> expr
val mk_typed : typ -> kind -> expr

(* a name node for s, of type t and class c, at offset off *)
val name_of : sym -> typ -> cls -> int -> expr

(* a node for s, as it is declared now *)
val name_node : sym -> expr

(* a constant of type t *)
val const_node : typ -> int64 -> expr

val et : expr -> etype

(* a type's link, which is sure to be there: a pointer's, an array's... *)
val link : typ -> typ

(* the symbol table, and the symbol of a name, made if it is new *)
val nhash : int
val hash : sym list array
val lookup : string -> sym

(* an error, which stops the run: at a line (error_at), or at an
 * expression's line, or else at the line diagnosed (diag) *)
exception Error of string
val error_at : int -> ('a, unit, string, 'b) format4 -> 'a
val diag : expr option -> ('a, unit, string, 'b) format4 -> 'a

(* gives its elements to a structure that is known only by its tag *)
val snap : typ -> unit

(* a kind's name, as 5c's dumps write it: INT, IND... *)
val tname : etype -> string

(* whether two types are the same, to dcl.c's depth; same compares two
 * types that are there *)
val sametype : typ option -> typ option -> bool
val same : typ -> typ -> bool

val show_type : typ option -> string

(* whether an expression is an operand as it is, needing no
 * instruction *)
val addressable : expr -> bool

val is_const : expr -> bool

(* the offset of a name or offset(reg) moved by d *)
val plus : expr -> int -> expr

(* List.map, applied left to right, because the passes have effects *)
val map_lr : ('a -> 'b) -> 'a list -> 'b list
