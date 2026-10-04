(* What goes with Tree's types: the tables of the kinds (which
 * operator takes which), the names, the symbol table, the nodes and
 * the types made, the diagnostics. Tree is the types alone. *)
open Tree

(* the sets of kinds, named by their members' initials as sub.c's:
 * typechlp is char, short, long (of each sign) and pointer *)
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

(* the integral promotion: Plan 9's, unsigned preserving *)
val promote : etype -> etype

val cname : cls -> string

(* a type's qualifiers, as bits *)
val gconstnt : int
val gvolatile : int

val binop_name : binop -> string
val unop_name : unop -> string

(* Eq ... Hs *)
val is_rel : binop -> bool

val mach : machine option ref
val m : unit -> machine

(* the machine's widths: a pointer's is its *)
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

(* an expression's type before typing, or an undeclared name's *)
val untyped : typ

(* the basic types, one of each: made by init_types *)
val ty : etype -> typ
val init_types : unit -> unit

(* an expression at the line being read, untyped; mk_typed of type t
 * (another line: { (mk e) with line }) *)
val mk : kind -> expr
val mk_typed : typ -> kind -> expr

(* a name of s, of type t and class c, at off *)
val name_of : sym -> typ -> cls -> int -> expr

(* s as it is declared now *)
val name_node : sym -> expr

(* a constant of type t *)
val const_node : typ -> int64 -> expr

val et : expr -> etype

(* a type's link, sure to be there: a pointer's, an array's... *)
val link : typ -> typ

(* the symbol table, and a name's symbol, made if new *)
val nhash : int
val hash : sym list array
val lookup : string -> sym

(* an error, which stops the run: at a line, at an expression's (or the
 * line diagnosed) *)
exception Error of string
val error_at : int -> ('a, unit, string, 'b) format4 -> 'a
val diag : expr option -> ('a, unit, string, 'b) format4 -> 'a

(* a structure known only by its tag given its elements *)
val snap : typ -> unit

(* the same type, to dcl.c's depth; of two types there *)
(* a kind's name, as 5c's dumps say it: INT, IND... *)
val tname : etype -> string

val sametype : typ option -> typ option -> bool
val same : typ -> typ -> bool

val show_type : typ option -> string

(* an operand as it is, needing no instruction *)
val addressable : expr -> bool

val is_const : expr -> bool

(* the offset of a name or offset(reg) moved by d *)
val plus : expr -> int -> expr

(* List.map, left to right: the passes have effects *)
val map_lr : ('a -> 'b) -> 'a list -> 'b list
