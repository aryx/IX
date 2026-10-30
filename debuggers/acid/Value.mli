(* acid's values (principia's acid.h: Store, List, Value): an integer,
 * a float, a string, a list, or code (eval's), each with its format,
 * a letter that says how it prints and how many bytes it is in
 * memory: X a word in hexadecimal, D a word in decimal, b a byte, s a
 * string, a an address said as a symbol and an offset... A constant is
 * W (8 bytes, hexadecimal), and a result takes its left operand's
 * format, so that a pointer stays one through arithmetic: p+4 is
 * printed as p is, and p++ adds what p's format says (8 for W, 4 for
 * X or D, 1 for b).
 *
 * The lists are acid's: cells linked, and changed in place by append
 * and +, as acid's (a variable's list grows where it is). The integers
 * are 64 bits (acid's vlong), whatever the machine running mini-acid. *)

type t = Ast.value

val int : char -> int64 -> t
val string : string -> t
val list : t list -> t
val empty : t

(* the list's values, in order *)
val elements : Ast.cell option -> t list

(* acid's typenames: integer, float, string, list, code *)
val type_name : t -> string

(* the bytes of the format in memory (fsize; 0: none) *)
val size : char -> int

(* true as acid's fbool: not 0, not empty *)
val truth : t -> bool

(* acid's equality (oeq: listcmp for lists) *)
val equal : t -> t -> bool

(* a value as print prints it (patom, blprint); [symbol] names an
 * address for the a and A formats ("0x..." without symbols) *)
val show : symbol:(int64 -> string) -> t -> string

(* the instruction at an address, the i format's: [!das core addr],
 * from the process (core) or the program's file (Proc's, by Das);
 * None when it can't be read *)
val das : (bool -> int64 -> string option) ref

(* the formats print and fmt know (acid's vfmt) *)
val formats : string
