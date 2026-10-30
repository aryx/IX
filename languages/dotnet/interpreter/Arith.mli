(* What the instructions do to numbers (ECMA-335, Partition III,
 * 1.5, its tables of operands): `add` and its family, the comparisons,
 * the conversions, on the machine's tagged values.
 *
 *     add          int32   int64   float     (binop)
 *       int32      int32     -       -       the two must agree: the
 *       int64        -     int64     -       IL is typed by its stack,
 *       float        -       -     float     and the verifier checks it
 *
 * An int32 is an Int32.t everywhere (plan_dotnet.md, decision 6): on
 * arm an OCaml int has 31 bits, and Fib's 47th number must wrap as
 * .NET's does. The unsigned operations (div.un, clt.un) go through
 * int64; `.un` on floats means unordered: true if one is a NaN.
 * A division by zero throws DivideByZeroException, int32's smallest
 * divided by -1 OverflowException, as the x86 and arm machines .NET
 * runs on would trap or not (arm does not: .NET checks). *)

open Value

val i4 : int -> value
val bool_v : bool -> value
(* brtrue's: a number not zero, a reference not null *)
val truthy : value -> bool
val int_of : value -> int
(* an int32 seen unsigned *)
val u32 : int32 -> int64

(* a comparison: None if unordered (a NaN); references by identity *)
val compare_values : bool -> value -> value -> int option
(* a conditional branch's test, .un or not *)
val test : Il.cmp -> bool -> value -> value -> bool

val binop : Il.binop -> value -> value -> value
(* conv.*: to the kind, .ovf checked, .un its source unsigned *)
val conv : Il.kind -> bool -> bool -> value -> value
