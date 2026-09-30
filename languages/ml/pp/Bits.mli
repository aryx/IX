(* mlpp's bit fields (plan_ml_bootstrap.md, decision 2): a 32-bit word
 * written as its encoding's diagram, the most significant bit first,
 * the fields separated by blanks:
 *
 *   c:4 000 01 signed:b acc:b s:b rdhi:4 rdlo:4 rs:4 1001 rm:4
 *
 * - name:n    n bits, bound to name (an int)
 * - name:sn   the same, sign-extended
 * - name:b    one bit, bound to name as a bool
 * - 0110      bits that must be those, as many as the digits; an x
 *             a bit that doesn't matter (1xx0)
 * - _:n       n bits that don't matter
 *
 * The widths must make 32. Every constant written stays below 2^30, so
 * the code means the same where an int has 32 bits (js_of_ocaml:
 * machine/Bits.mli). *)

exception Error of string

(* [%bits "..."] as a pattern on the word w: the test of its fixed bits
 * ("" if none), and each field's name and value *)
val pattern : string -> string -> string * (string * string) list

(* [%bits "..."] as an expression: the fields' variables shifted in *)
val expr : string -> string
