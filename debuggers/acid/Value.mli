(* acid's values (principia's acid.h: Store, List, Value). A value is
 * an integer, a float, a string, a list, or code (for eval), and each
 * has its format. The format is a letter that says how the value
 * prints and how many bytes it takes in memory: X is a word in
 * hexadecimal, D a word in decimal, b a byte, s a string, a an address
 * shown as a symbol and an offset... A constant is W (8 bytes,
 * hexadecimal), and a result takes the format of its left operand, so
 * that a pointer stays a pointer through arithmetic: p+4 is printed as
 * p is, and p++ adds what p's format says (8 for W, 4 for X or D, 1
 * for b).
 *
 * The lists are acid's: they are linked cells, changed in place by
 * append and +, as in acid (so a variable's list grows where it is).
 * The integers are 64 bits (acid's vlong), whatever the machine that
 * runs mini-acid. *)

type t = Ast.value

val int : char -> int64 -> t
val string : string -> t
val list : t list -> t
val empty : t

(* the list's values, in order *)
val elements : Ast.cell option -> t list

(* acid's typenames: integer, float, string, list, code *)
val type_name : t -> string

(* how many bytes the format takes in memory (fsize; 0 for none) *)
val size : char -> int

(* whether a value is true, as acid's fbool says: not 0 and not empty *)
val truth : t -> bool

(* acid's equality (oeq, which uses listcmp for lists) *)
val equal : t -> t -> bool

(* a value as print prints it (patom, blprint); [symbol] names an
 * address for the a and A formats ("0x..." when there are no
 * symbols) *)
val show : symbol:(int64 -> string) -> t -> string

(* the instruction at an address, for the i format: [!das core addr]
 * reads it from the process (core) or from the program's file. Proc
 * sets it, using Das. It returns None when the instruction can't be
 * read. *)
val das : (bool -> int64 -> string option) ref

(* the formats print and fmt know (acid's vfmt) *)
val formats : string
