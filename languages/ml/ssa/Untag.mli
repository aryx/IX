(* An integer not tagged inside a function (plan_ml_speed.md, stage 2):
 * an SSA value that is n in its register, not 2n+1, where the tag would
 * be taken off again by what reads it. mini-ml's int is tagged (Lower,
 * Gen: 2n+1, the collector's way of telling it from a pointer), and
 * each operation pays for it: x + y is an ADD and a SUB, a byte read a
 * load then a shift and an OR, a byte stored a shift then the store.
 * mini-doom's span, its pixel's 35 instructions, 11 of them the tags.
 *
 * The untagged: what reads a byte (ByteGet, its result 0 to 255); x asr
 * k by a constant (one shift of the tagged x by k + 1, where tagged it
 * is a shift and an OR); x land c, x untagged, c a constant at least 0;
 * x + y, x - y, x lsl k of untagged values. Only when the value's bits
 * are known small enough that no wrap can happen: a tagged int is 31
 * bits on arm, 63 on arm64, and a register's sum of two of them may be
 * past that, where the tagged sum wrapped; such a sum would then
 * compare, shift and divide otherwise. So each untagged value has a
 * bound (a byte 8 bits, x asr 16 on arm 14, x land 63 6, a sum one
 * more than its operands'), and past 30 (62) it stays tagged. A loop's
 * counter, a sum of a tagged value: tagged, as before.
 *
 * Read as they are: by an untagged value's operation; as a byte's
 * index or the byte stored; by a tagged value plus or minus one (an ADD
 * or SUB of the register shifted by 1: t + 2n is the tagged sum).
 * Wherever else (stored, passed, compared, returned, a phi's operand)
 * it is tagged once after its definition (Tag, two instructions).
 *
 *     let pixel flat (x : int) = Char.code (Bytes.unsafe_get flat ((x asr 16) land 63))
 *
 *     mini-ml -dssa:
 *     v3 = (Ir.Op Ir.Asr) v2 v16     ; untagged, 14 bits
 *     v4 = (Ir.Op Ir.And) v3 v17     ; untagged, 6 bits
 *     v5 = (Ir.ByteGet false) v1 v4  ; untagged, 8 bits
 *     v6 = tag v5
 *     ret v6
 *
 * An untagged value is a word the collector must not read: in a
 * register it is not read; past a safepoint it goes to memory, and so
 * to a slot of the machine stack (Alloc's Dmem, a double's), not the
 * value stack. Not in a function with a handler (its values in memory
 * at each raise), which stays as it was.
 *
 * others:
 * ocamlopt keeps ints tagged in registers, but its Cmm folds the tags
 * of an expression where it can (untag_int of tag_int, the decrement
 * of a sum into the next operation: add_int and its Caddi), and its
 * instruction selection does the rest. MLton and SML/NJ have untagged
 * 32-bit words by type (Word32), their int tagged or not by the
 * program's whole representation analysis.
 *
 * References: OCaml's asmcomp/cmm_helpers.ml (untag_int, add_int);
 * Andrew Appel, "Compiling with Continuations" (1992), chapter 4 (the
 * representations of SML/NJ's data). *)

(* on, unless mini-ml -tagged-ints *)
val on : bool ref

(* the function's untagged values found (fn.raws), with what reads them
 * as words tagged, its code rewritten in place; bits: an int's (31 on
 * arm, 63 on arm64) *)
val func : bits:int -> Ssa.func -> Ssa.func
