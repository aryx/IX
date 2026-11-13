(* Declarations, as the parser meets them (dcl.c). This module:
 * - builds a declarator's type from the words before it;
 * - gives a symbol its class and offset (for a frame's autos and
 *   parameters, and for a structure's fields);
 * - turns initializers into data or assignments;
 * - handles C's scopes.
 *
 * The scopes: a symbol holds its current meaning, and a block's
 * declarations push what they hide on a stack of undos. An undo is a
 * variant: a block's mark, a name, or a tag. The end of the block
 * ([revertdcl]) pops back to its mark, restoring each one. In 5c, the
 * stack is a list of Decl records with a kind field.
 *
 * The initializers: [doinit] takes the items of Tree's [init] from a
 * cursor, where a string spread over an array's elements and an
 * expression already typed (a structure's, by isstruct) are items of
 * their own; 5c marks them in the tree, as OUSED and ODOTDOT nodes.
 *
 * A declaration is made of words, then a declarator around a name. The
 * declarator is a small tree of its own: [dodecl] walks it from the
 * outside in, wrapping the words' type at each step, and arrives at
 * the name with the type (Tree's header shows the chain it makes):
 *
 *     int *a[10];      the words: int        the declarator: *a[10]
 *
 *     Dptr                     int          a pointer to int
 *       Darray (10)            ->           an array of 10 of those
 *         Dname a                           a's type
 *
 * Where a goes depends on its class:
 * - an auto goes at the next offset below the frame's top ([stkoff]
 *   grows, and a block's end gives its room back);
 * - a parameter goes above it;
 * - a structure's element goes at the structure's next aligned offset;
 * - an external goes nowhere yet, because mini-ld places it.
 *
 * cs-history:
 * The declarator is C's own invention, and its most criticized one: it
 * is written as the expression that uses the name. *a[10] is how one
 * gets an int out of a, so int *a[10] declares a. As Dennis Ritchie
 * tells it, there are no words for pointer or array and no new syntax
 * to learn, but types must be read from the inside out, with the name
 * buried in the middle. He also reports Ravi Sethi's remark that the
 * nesting would have been lighter had * been written after its
 * operand, as [] and () are; by then it was too late. Pascal before C
 * and Go after it write the type from left to right, as it is said
 * aloud.
 *
 * References: Ken Thompson, "Plan 9 C Compilers", section "Parsing":
 * "Declarations are interpreted immediately, building a block
 * structured symbol table"; H. G. Baker, "Shallow binding in Lisp 1.5"
 * (CACM 21(7), 1978), the same trick at run time: a value cell holds
 * the current binding, and a stack holds the shadowed ones (here, the
 * symbol's fields and the undos); Dennis Ritchie, "The Development of
 * the C Language" (HOPL-II, 1993), its sections on the declarations'
 * syntax and on what he would do otherwise. *)

(* where a function's name and its parsed body go: to the code
 * generator *)
val on_function : (Tree.sym -> Tree.stmt -> unit) ref

(* the line of the function being defined, the line of its head. The
 * line table gives it to the function's instructions that have a
 * function's line, not yet a statement's. *)
val fnline : int ref

(* the line of the last name the lexer read. fnline takes it from here,
 * so that a function's line is its name's, not that of the { read
 * after it. *)
val nameline : int ref

(* the back end's function that writes an initializer's data (swt.c's
 * gextern), set by the command (CLI) *)
val gextern : (Tree.sym -> Tree.expr -> int -> int -> unit) ref

(* the state that the parser shares (cc.h's globals): the frame's size,
 * the block, the last declarator's type, the words' type and class, a
 * structure's elements (the last first), the function and its first
 * parameter, an enum's types *)
val stkoff : int ref
val autobn : int ref
val lastdcl : Tree.typ option ref
val lasttype : Tree.typ option ref
val lastclass : Tree.cls ref
val lastfield : int ref
val elems : Tree.typ list ref
val taggen : int ref
val firstarg : Tree.sym option ref
val firstargtype : Tree.typ option ref
val thisfn : Tree.typ option ref
val en_tenum : Tree.typ option ref
val en_cenum : Tree.typ option ref

(* where a value is aligned: at an element's start and end, at a
 * structure's end, for the frame's first parameter (a structure's
 * result's address), at a parameter's start and end, and for an
 * auto *)
type align = Ael1 | Ael2 | Asu2 | Aarg0 | Aarg1 | Aarg2 | Aaut3

(* i rounded up for t, as op says *)
val align : int -> Tree.typ -> align -> int
val round : int -> int -> int
val maxround : int -> int -> int

(* a declaration's words, in the order C allows them anywhere *)
type word =
  | Char | Short | Int | Long | Signed | Unsigned | Float | Double | Void
  | Auto | Static | Extern | Typedef | Typestr | Register | Const | Volatile

val type_words : word list

(* the qualifiers the words say, as Tree's garb *)
val simpleg : word list -> int

(* the class the words say *)
val simplec : word list -> Tree.cls

(* the type the words say: int by default, and long long is a vlong *)
val simplet : word list -> Tree.typ

(* t qualified by the words *)
val garbt : Tree.typ -> word list -> Tree.typ

(* a local static, as a global symbol of its own *)
val mkstatic : Tree.sym -> Tree.sym

(* declares the name of d, whose type d builds around t, of class c,
 * and gives it to f (xdecl, adecl, pdecl, edecl; or none). It returns
 * the symbol declared. *)
val dodecl :
  (Tree.cls -> Tree.typ -> Tree.sym option -> unit) option -> Tree.cls -> Tree.typ -> Tree.decl -> Tree.sym option

(* the declaration of an auto, a parameter, an external, and a
 * structure's element *)
val adecl : Tree.cls -> Tree.typ -> Tree.sym option -> unit
val pdecl : Tree.cls -> Tree.typ -> Tree.sym option -> unit
val xdecl : Tree.cls -> Tree.typ -> Tree.sym option -> unit
val edecl : Tree.cls -> Tree.typ -> Tree.sym option -> unit

(* links the elements by down, which makes a structure's body *)
val chain : Tree.typ list -> Tree.typ option

(* computes the offsets of a structure's elements, and its width *)
val sualign : Tree.typ -> unit

(* a typedef's type, copied for a variable so that its incomplete
 * arrays are its own *)
val tcopy : Tree.typ option -> Tree.typ option

(* a tag's type, in block bn (0 means the one in scope) *)
val dotag : Tree.sym -> Tree.etype -> int -> Tree.typ

(* declares an enumerator, with the value given or else the next one *)
val doenum : Tree.sym -> Tree.expr option -> unit

(* the start of a block; and its end, which restores what the block
 * hid and returns its volatiles, to be USED *)
val markdcl : unit -> unit
val revertdcl : unit -> Tree.expr list

(* gives the parameters their offsets; ~declared is true after their
 * old-style declarations *)
val argmark : Tree.decl -> declared:bool -> unit

(* a label, defined (true) or used (false); labels are forgotten at
 * the function's end *)
val dcllabel : Tree.sym -> bool -> Tree.label

(* the initializer of s, of type t at offset o: assignments for an
 * auto, or data for a static (by gextern) *)
val doinit : Tree.sym -> Tree.typ option -> int -> Tree.init -> Tree.expr list

(* an auto's initialization, where v is the width of its array before
 * the initializer. The array is zeroed first when the initialization
 * is partial (dcl.c's contig). *)
val contig : Tree.sym -> Tree.expr list -> int -> Tree.stmt list
