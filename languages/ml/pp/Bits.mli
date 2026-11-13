(* mlpp's bit fields (plan_ml_bootstrap.md, decision 2). A 32-bit word
 * is written as the diagram of its encoding, with the most significant
 * bit first and the fields separated by blanks:
 *
 *   c:4 000 01 signed:b acc:b s:b rdhi:4 rdlo:4 rs:4 1001 rm:4
 *
 * - name:n    n bits, bound to name (an int)
 * - name:sn   the same, sign-extended
 * - name:b    one bit, bound to name as a bool
 * - 0110      bits that must be those, as many as the digits; an x
 *             is a bit that doesn't matter (1xx0)
 * - _:n       n bits that don't matter
 *
 * The widths must add up to 32. Every constant written stays below
 * 2^30, so that the code means the same where an int has 32 bits
 * (js_of_ocaml: see machine/core/Bits.mli).
 *
 * Here is what is written for it, as mini-ml -pp outputs it (the
 * fields are those of an ARM data-processing instruction, cut
 * short):
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
 * As an expression, [%bits "c:4 0000 ... rn:4"] is the fields masked,
 * shifted and joined by lor, which encodes an instruction. The lxor
 * and the subtraction extend the sign without a test: bit 11 is
 * flipped, then its weight is taken off.
 *
 * It is for the emulators (the Arm32 and Arm64 of mini-5i and
 * mini-qemu), whose decoders are a match with one clause for each
 * instruction. Each clause is the row of the processor's manual, which
 * draws an encoding as boxes of bits from 31 to 0, and it can be
 * checked against the manual by eye. Written by hand, the same decoder
 * is the shifts and masks above, where a 21 written for a 20 is a bug
 * that no compiler sees.
 *
 * others:
 * C has bit fields in a struct, and decoders seldom use them for this,
 * because the order of the fields in the word is the compiler's choice
 * and there is no matching on the constant ones. Erlang has the whole
 * idea, as its syntax for binaries (a pattern of fields with their
 * widths, made for network protocols), and OCaml has it as a ppx,
 * bitstring, modeled on Erlang's. This one is smaller than either: it
 * handles one word of 32 bits, with no byte order, and does nothing at
 * run time. *)

exception Error of string

(* [%bits "..."] as a pattern on the word w: the test of its fixed bits
 * ("" if there are none), and each field's name and value *)
val pattern : string -> string -> string * (string * string) list

(* [%bits "..."] as an expression: the fields' variables, shifted into
 * place *)
val expr : string -> string
