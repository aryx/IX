(* A multiplication by a constant as shifts, adds and subtracts (5c's
 * mul.c): at most three operations, found by a search, with a table of
 * hints for the numbers the search misses. arm's barrel shifter makes
 * each operation one instruction.
 *
 *     x * 7      SLL $3,R0,R3;  SUB R0,R3,R0          8x - x
 *     x * 10     SLL $2,R0,R4;  ADD R4,R0,R0;         (4x + x) * 2
 *                SLL $1,R0,R0
 *     x * 100    MOVW $100,R2;  MUL R2,R0             no program short
 *                                                     enough: multiplied
 *
 * (mini-cc -S, x in R0; in this listing a shift and the operation
 * that uses it are two lines.)
 *
 * cs-history:
 * It is an old trade. A multiplier was the slow instruction of the
 * machines these compilers were first written for, many cycles
 * where a shift or an add is one, and a constant times a variable
 * is common: an index times the size of an array's element. Robert
 * Bernstein (1986) put it as a search for the cheapest chain of
 * shifts, adds and subtracts. Today's multipliers take a few
 * cycles and the gain is small; compilers still do the short cases.
 *
 * References: R. Bernstein, "Multiplication by integer constants"
 * (Software -- Practice and Experience, 1986), the classic statement of
 * the problem, as a search for the cheapest chain. *)

(* the program of v's multiplication, if one is short enough *)
val mulcon0 : int -> string option
