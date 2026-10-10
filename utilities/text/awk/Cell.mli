(* awk's cells: the symbol table and the arrays (tran.c), a cell's
 * value as a number or as a string, and the record with its fields
 * (lib.c's half that the values cannot do without: reading $3 splits
 * the record, assigning it makes the record anew when it is read).
 *
 * A value is a number, a string, or both. What a program writes is
 * one or the other (9, "10"); what it reads, a field or a line of
 * getline, is a string that is also a number when it looks like one.
 * Two values are compared as numbers only when both are numbers:
 *
 *     echo 10 9 | awk '{ print ($1 < $2), ($1 "" < $2 "") }'
 *     0 1         the fields: 10 < 9 is false; made strings by the
 *                 "" joined to them, "10" < "9" is true
 *     awk 'BEGIN { x = "10"; y = 9; print (x < y) }'
 *     1           x is a string, whatever it looks like
 *
 * design:
 * This is what lets a program go without declarations when its data
 * is text: 1969 read from a file adds as a number and prints as it
 * was written, with no conversion said. The cost is that an
 * expression's type is known only when it runs, value by value, and
 * that the rule above must be learned. The languages after awk chose
 * a side: Perl two sets of operators (< and lt), Python an error
 * when a number meets a string. POSIX's name for a string that may
 * be a number is a numeric string.
 *
 * The symbol table is one array among the others: a variable's name
 * is a string that indexes it, as a program's own arrays are indexed
 * (tran.c's symtab and its Array). *)

(* awk's FATAL: the message; and its SYNTAX, for the program's text *)
exception Fatal of string
exception Syntax of string

(* awk's WARNING: said (the command line sets how), and the program goes on *)
val warning : (string -> unit) ref

(* {2 Tables} *)

val table : unit -> Ast.table
val lookup : Ast.table -> string -> Ast.cell option
(* the name's cell, made with those contents when it is not there *)
val install : Ast.table -> string -> Ast.contents -> Ast.cell
val remove : Ast.table -> string -> unit
(* each cell in the table's order, as for (k in a) goes *)
val iter : Ast.table -> (Ast.cell -> unit) -> unit

(* the program's names *)
val symtab : Ast.table
(* a variable never assigned: the empty string and 0 at once *)
val unset : Ast.contents
val temp : Ast.value -> Ast.cell
val of_float : float -> Ast.value
val of_string : string -> Ast.value
(* a string that is also a number if it looks like one (a field, an
 * argument, an element split makes) *)
val of_input : string -> Ast.value

(* the cells awk itself reads *)
val fs : Ast.cell
val rs : Ast.cell
val ofs : Ast.cell
val ors : Ast.cell
val convfmt : Ast.cell
val subsep : Ast.cell
val nf : Ast.cell
val nr : Ast.cell
val fnr : Ast.cell
val filename : Ast.cell
val rstart : Ast.cell
val rlength : Ast.cell
(* the empty constant conditions are compared with *)
val null : Ast.cell
val zero : Ast.cell

(* {2 Values} *)

(* a string's number, if the whole of it is one (spaces after it
 * aside): strtoll's with base 0, so 0x1A is 26 and 010 is 8, or a
 * float's *)
val to_number : string -> float option
(* the number at the start of a text, and where it ends *)
val number_prefix : string -> (float * int) option

(* the cell's value as it is now: which of its number and its string
 * are valid *)
val value : Ast.cell -> Ast.value
val getfval : Ast.cell -> float
val getsval : Ast.cell -> string
val setfval : Ast.cell -> float -> unit
val setsval : Ast.cell -> string -> unit
(* the cell's array, the cell made one if it was never used *)
val array : Ast.cell -> Ast.table

(* {2 The record} *)

(* a new record: its fields are split when one is asked for, by the FS
 * that was there when the last record was read (remember_fs) *)
val set_record : string -> unit
(* the input's end, as the C leaves it for END: the record read last is
 * emptied (its number, if it was one, stays), but not a record the
 * program assigned; the fields are those of what is left *)
val end_of_input : unit -> unit
val remember_fs : unit -> unit
(* $n's cell; a field past NF is empty and does not change NF *)
val field : int -> Ast.cell
(* the fields split now (NF asks) *)
val build_fields : unit -> unit
