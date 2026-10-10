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
 * machine/Bits.mli).
 *
 * What is written for it, mini-ml -pp's output (the fields here are
 * an ARM data-processing instruction's, cut short):
 *
 *     match w with
 *     | [%bits "c:4 000 0100 s:b rn:4 rd:4 imm:s12"] -> body
 *
 *     | __bits when ((__bits lsr 25) land 0x7) = 0x0
 *                && ((__bits lsr 21) land 0xf) = 0x4 ->
 *         let c = (__bits lsr 28)
 *         and s = ((__bits lsr 20) land 0x1) = 1
 *         and rn = ((__bits lsr 16) land 0xf)
 *         and rd = ((__bits lsr 12) land 0xf)
 *         and imm = (((__bits land 0xfff) lxor 0x800) - 0x800) in body
 *
 * and as an expression, [%bits "c:4 0000 ... rn:4"] is the fields
 * masked, shifted and joined by lor: an instruction encoded. The lxor and
 * the subtraction are the sign's extension without a test: bit 11
 * flipped, then its weight taken off.
 *
 * It is for the emulators (mini-5i's and mini-qemu's Arm32 and
 * Arm64), whose decoders are a match with a clause an instruction:
 * each clause is the row of the processor's manual, which draws an
 * encoding as boxes of bits from 31 to 0, and can be checked against
 * it by eye. By hand the same decoder is the shifts and masks above,
 * where a 21 written for a 20 is a bug no compiler sees.
 *
 * others:
 * C has bit fields in a struct, and decoders seldom use them for this:
 * the order of the fields in the word is the compiler's choice, and
 * there is no matching on the constant ones. Erlang has the idea
 * whole, as its syntax for binaries (a pattern of fields with their
 * widths, made for network protocols), and OCaml has it as a ppx,
 * bitstring, after Erlang's. This one is smaller than either: one
 * word of 32 bits, no bytes' order, nothing at run time. *)

exception Error of string

(* [%bits "..."] as a pattern on the word w: the test of its fixed bits
 * ("" if none), and each field's name and value *)
val pattern : string -> string -> string * (string * string) list

(* [%bits "..."] as an expression: the fields' variables shifted in *)
val expr : string -> string
