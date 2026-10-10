(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The compiler's data: C's types, the trees the parser makes of
 * expressions, statements, declarators and initializers, the symbols,
 * and what the front end asks of a machine (cc.h's Type, Node, Sym;
 * sub.c's tables).
 *
 * A type's kind is a variant, [etype]; the tables that say which kinds
 * an operator takes ([tasign], [tadd]...) are predicates on the left and
 * right kinds, and the usual conversions a rule ([arith_tab]).
 *
 * The trees are ADTs, where 5c's are one Node with an op, a left and a
 * right: an [expr] is its [kind] ([Binary], [Assign], [Call]...) with
 * what the passes learn of it (its type, its complexity, its
 * addressability); the passes (Check, the back end's xcom) return new trees
 * rather than rewrite them in place. Statements, declarators and
 * initializers have their own types ([stmt], [decl], [init]); in 5c they
 * are Nodes too. Symbols and types stay mutable records: declarations
 * complete them as they come.
 *
 * One file is compiled per run, and the state is global: [lineno], the
 * symbol table [hash], the machine [mach].
 *
 * References: Ken Thompson, "Plan 9 C Compilers" (in principia's
 * compilers/docs/compiler.ms; first in Proc. Summer 1990 UKUUG
 * Conference), its section "Implementation": "four machine-independent
 * passes, four machine-dependent passes, and an output pass", which these
 * trees carry from one to the next; D. E. Knuth, The Art of Computer
 * Programming, vol. 3, section 6.4, for [lookup]'s table, chained
 * buckets with a cheap hash. *)

(* (No Tree.mli: the module is its types. What goes with them -- the
 * tables, the names, the symbol table, the nodes made, the diagnostics
 * -- is Tree_helpers.) *)

(* a type's kind; Tdot is a prototype's ..., Told an old-style one's
 * parameters *)
(* old: 5c's one numbering for the kinds and a declaration's words
 * (TCHAR... BAUTO...), tables as bit sets indexed by Obj.magic ranks: a
 * word could reach the typechecker, and a table any integer *)
type etype =
  | Txxx | Tchar | Tuchar | Tshort | Tushort | Tint | Tuint | Tlong | Tulong | Tvlong | Tuvlong | Tfloat | Tdouble
  | Tind | Tfunc | Tarray | Tvoid | Tstruct | Tunion | Tenum | Tdot | Told

(* storage classes, and qualifiers (GCONSTNT...) *)
type cls = Cxxx | Cauto | Cextern | Cglobl | Cstatic | Clocal | Ctypedef | Ctypestr | Cparam | Cselem | Clabel | Cexreg

(* the operators; L and Lo, Ls, Hi, Hs are the unsigned ones *)
type binop =
  | Add | Sub | Mul | Div | Mod | Lmul | Ldiv | Lmod
  | And | Or | Xor | Ashl | Ashr | Lshr
  | Eq | Ne | Lt | Le | Gt | Ge | Lo | Ls | Hi | Hs
  | Andand | Oror | Comma
[@@deriving show]

type unop = Ind | Addr | Neg | Com | Not | Pos | Cast | Preinc | Predec | Postinc | Postdec

type sym = {
  name : string;
  mutable typ : typ option;
  mutable suetag : typ option;
  mutable tenum : typ option;
  mutable macro : string option;     (* its first char is its number of arguments + 1, as mac.c *)
  mutable soffset : int;
  mutable svconst : int64;
  mutable sfconst : float;
  mutable label : label option;
  mutable lexical : int;              (* the token: a name or a keyword *)
  mutable block : int;
  mutable sueblock : int;
  mutable sclass : cls;
  mutable aused : bool;
}

and typ = {
  mutable tsym : sym option;          (* a structure element's name *)
  mutable tag : sym option;
  mutable link : typ option;
  mutable down : typ option;
  mutable width : int;
  mutable offset : int;
  mutable etype : etype;
  mutable garb : int;
}

(* a function's label: defined, and where *)
and label = { lsym : sym; mutable defined : bool; mutable lpc : int }

(* how an expression can be an instruction's operand as it is; the
 * others are computed into a register (sgen.c's addable) *)
type addr =
  | Anone
  | Aaddr_name | Aaddr_reg            (* $name, $offset(reg) *)
  | Aname | Areg | Aindreg | Aconst   (* name or stack slot; reg; offset(reg); $c *)

(* an expression: its kind, and what the passes learn of it *)
(* old: 5c's Node, an op with an optional left and right for all trees
 * (expressions, statements, declarators), rewritten in place: every
 * pass read its sides by Option.get and tested n.op, and a Node of an
 * op with the wrong sides was a runtime error *)
type expr = {
  e : kind;
  t : typ;                            (* untyped until typed *)
  line : int;
  complex : int;                      (* the registers it needs (Sethi-Ullman) *)
  addable : addr;
}

and kind =
  | Name of sym * cls * int           (* a symbol, its class, an offset *)
  | Const of int64
  | Fconst of float
  | Str of string                     (* a literal, before typing *)
  | Lstr of string                    (* L"...": its runes, 4 bytes each *)
  | Reg of int
  | Indreg of int * int               (* offset(reg) *)
  | Unary of unop * expr
  | Binary of binop * expr * expr
  | Assign of binop option * expr * expr   (* x = y, x op= y *)
  | Cond of expr * expr * expr
  | Call of expr * expr list
  | Elem of expr * sym                (* x.m, before typing *)
  | Dot of expr * int                 (* a member, at its offset, of a structure that is no l-value *)
  | Sizeof of expr
  | Sizeof_type of typ
  | Typed of expr                     (* an initializer's, typed already: not again *)

type stmt =
  | Expr of expr
  | Block of stmt list
  | If of expr * stmt * stmt option
  | While of expr * stmt
  | Dowhile of stmt * expr
  | For of stmt * expr option * stmt * stmt   (* its start, test, step and body *)
  | Switch of expr * stmt
  | Case of expr option               (* default: None *)
  | Label of label
  | Goto of label
  | Break
  | Continue
  | Return of expr option * typ       (* the function's result *)
  | Used of expr list
  | Set of expr list

(* a declarator: the type around a name *)
type decl =
  | Dnone                             (* abstract *)
  | Dname of sym
  | Dptr of int * decl                (* its qualifiers, as garb *)
  | Dfunc of decl * param list
  | Darray of decl * expr option
  | Dbit of decl * expr

and param = Pname of sym | Proto of typ * decl | Pdots

(* an initializer, whose designators are items of the list *)
type init =
  | Iexpr of expr
  | Ilist of init list
  | Iindex of expr                    (* [e] = *)
  | Ielem of sym                      (* .m = *)

(* the machine, as the front end sees it: widths and alignment
 * (goken's ewidth, align, maxround in each back end's swt.c and gc.h) *)
type machine = {
  thechar : char;
  sz_ind : int;
  maxalign : int;                     (* SZ_LONG on arm, SZ_VLONG on arm64 *)
  typecmplx : etype -> bool;          (* returned through a pointer *)
  typeword : etype -> bool;           (* passed in a register *)
  typeswitch : etype -> bool;
  machcap : expr option -> bool;      (* what the back end does itself *)
}
