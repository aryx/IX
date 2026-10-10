(* What you can type into a cell, and what it means.
 *
 *   42            a number
 *   hello         text
 *   =A1+B2*2      a formula: arithmetic over other cells
 *   =SUM(A1:A9)   a function over a range of them
 *
 * The grammar, which is the one every spreadsheet has had since
 * VisiCalc (Dan Bricklin and Bob Frankston, 1979), written here as
 * the parser reads it:
 *
 *   expr    ::= term (('+' | '-') term)*
 *   term    ::= factor (('*' | '/') factor)*
 *   factor  ::= '-'? atom
 *   atom    ::= number | ref (':' ref)? | name '(' args ')' | '(' expr ')'
 *   ref     ::= letters digits          A1, B12, AA3
 *
 * Two rules in four lines, and they are what gives multiplication its
 * precedence over addition: a sum is made of products, so the parser
 * that reads a sum asks for products, and a product binds tighter by
 * being lower down. That is **recursive descent** -- one function per
 * rule, calling the function below it -- and it is the parser to know
 * first, because the grammar and the code are the same shape.
 *
 * Worked example, "=2+3*A1" with A1 holding 4:
 *
 *   expr -> term(2) '+' term(3*A1)
 *                         -> factor(3) '*' factor(A1)
 *   value = 2 + (3 * 4) = 14, and not (2+3)*4 = 20
 *
 * A1 is a *reference*, not a value: the formula says which cell to
 * read, and Sheet is what knows the answer and what to do when it
 * changes. That separation is the whole of why a spreadsheet can
 * recalculate (Sheet.mli).
 *
 * What it deliberately does not have: strings in formulas, comparison
 * and IF, absolute references ($A$1, which matter when a formula is
 * copied), sheets other than this one, and the hundreds of functions
 * a real one carries. It has the six that show what a function over
 * a range is: SUM, PRODUCT, MIN, MAX, AVERAGE, and COUNT. (Any name
 * followed by a parenthesis parses as a call: which names mean
 * something is Sheet's to say, and an unknown one is an error in the
 * cell, not here.)
 *
 * The way back, [to_string], is the grammar read the other way: a
 * tree has no parentheses, so they are put back only where the tree
 * would otherwise be read differently, a looser operator under a
 * tighter one, or anything but a tighter one on the right:
 *
 *   Binop ('*', Binop ('+', 2, 3), 4)     "(2+3)*4"
 *   Binop ('+', 2, Binop ('*', 3, 4))     "2+3*4"
 *   Binop ('-', Binop ('-', 2, 3), 4)     "2-3-4"      as it was parsed
 *   Binop ('-', 2, Binop ('-', 3, 4))     "2-(3-4)"    the right side
 *
 * The last two are why the right side is asked for one level more
 * than the left: the loops of expr and term build their trees leaning
 * left, so 2-3-4 is (2-3)-4, as at school.
 *
 * Where it stands. Sheet calls [content_of] on what is typed into a
 * cell and [refs] on the formula it gets, and computes the tree
 * itself: nothing here has a value. Sheet (its saved text) and
 * Sheet_view (the headers, the selection's name) write a cell's name
 * with [name_of_cell]. [shift] and [to_string] have no caller in
 * mini-office yet: they are the playground's TinyExcel's Fill Down.
 *
 * The other parsers of ix, for the comparison: the shell's is by
 * recursive descent too, a function a rule; the C and ML compilers,
 * awk, bc and hoc give their grammars to yacc (their Parser.mly),
 * which is the tool for a grammar of a language's size; and dc has
 * no grammar at all, since reverse Polish needs none (dc's CLI.mli):
 * "2 3 4 * +" is this module's tree already walked.
 *
 * terminology:
 * A1 and R1C1. A1 names a cell by where it is: a letter for the
 * column, a number for the row, VisiCalc's way and every sheet's
 * default since. R1C1 is Multiplan's (Microsoft, 1982), and Excel
 * still has it as an option: both are numbers, R2C3 is C2, and a
 * relative reference says how far, R[1]C[-1] being one row down and
 * one column left of the cell the formula is in. In A1 a formula
 * filled down a column is a different text in each row (=B2*C2,
 * =B3*C3: [shift]) that means the same thing; in R1C1 it is the same
 * text in every row (=RC[-2]*RC[-1]), and the meaning is what is
 * written. A1 is easier to say aloud, and won.
 *
 * evolution:
 * The spelling changed, the grammar did not. VisiCalc wrote +B2*C2,
 * starting with a sign so that the B was not taken for a label, and
 * @SUM(B2...B4); Lotus 1-2-3 kept the @ and wrote the range with two
 * dots; Excel has the = and the colon of this module, and added the
 * dollar of $A$1 that keeps a reference from moving when it is
 * copied. The playground's TinyVisiCalc and TinyLotus123 each
 * translate their spelling to this one in a few lines: a formula
 * language is a surface, not a semantics.
 *
 * others:
 * One function a level of precedence is right for two levels. A
 * language with fifteen (C) is read by one function and a table of
 * the operators' strengths instead: precedence climbing, or Vaughan
 * Pratt's "Top Down Operator Precedence" (1973), which is the same
 * loop as [expr]'s with the level made an argument.
 *
 * References: the playground's languages/formula (this file) and its
 * TinyVisiCalc, TinyLotus123 and TinyExcel, three faces on it. Dan
 * Bricklin and Bob Frankston, VisiCalc (Software Arts, 1979): its
 * reference card is the whole language on one sheet (from memory).
 * Vaughan Pratt, "Top Down Operator Precedence" (POPL 1973). *)

(* where a cell is: its column and row, both counted from 0, so A1 is
 * (0, 0) *)
type cell = int * int

type expr =
  | Number of float
  | Ref of cell
  | Range of cell * cell
  | Unary of char * expr
  | Binop of char * expr * expr
  | Call of string * expr list

(* What a cell holds, before anything is computed: [Formula] when it
 * starts with '=', [Value] for a number, [Text] for anything else --
 * which is how a spreadsheet tells "3" from "three" without asking.
 *
 * [Invalid] is the fifth, and it is there rather than as a failure
 * because of what a spreadsheet has to do with a formula that does
 * not parse: keep it. The text stays in the cell, to be corrected,
 * and the cell shows an error -- so "it does not parse" is a thing a
 * cell can hold, and not a reason to refuse what was typed. *)
type content =
  | Formula of expr
  | Invalid of string
  | Value of float
  | Text of string
  | Blank

(* [content_of s]: what typing [s] into a cell means. Anything can be
 * typed into a cell, so this cannot fail. *)
val content_of : string -> content

(* [parse s]: the formula in [s] (without its leading '='), for the
 * tests and for anybody wanting the tree *)
val parse : string -> (expr, string) result

(* which cells an expression reads, a range counted as every cell in
 * it: what Sheet builds its dependency graph out of *)
val refs : expr -> cell list

(* "A1", "BC12": how a cell is written and read. A column is base 26
 * with no zero, which is why the column after Z is AA and not BA. *)
val name_of_cell : cell -> string
val cell_of_name : string -> cell option

(* [to_string e]: the formula written back out, with the parentheses
 * it needs and no others -- so that a cell keeps text a person can
 * read after the program has changed it *)
val to_string : expr -> string

(* [shift (dc, dr) e]: every reference moved by that many columns and
 * rows. This is what copying a formula does, and it is the whole of
 * why spreadsheets are useful: fill =B2*C2 down a column and each row
 * gets its own =B3*C3, =B4*C4 -- one formula written once, for a
 * table of any height.
 *
 * VisiCalc had it as /R (replicate, 1979), asking cell by cell
 * whether each reference should move ("N or R?"); Excel made it Fill
 * Down and Fill Right, and made moving the default.
 *
 * Which is exactly where **$A$1** comes from, and it is not here: a
 * reference that must *not* move when the formula is copied -- a tax
 * rate in one corner, read by every row -- needs a way to say so, and
 * the dollar is it. Without absolute references, filling a formula
 * that reads a fixed cell gives nonsense, and that is the one thing
 * to know about this function's limits. *)
val shift : int * int -> expr -> expr
