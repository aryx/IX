(* An item as text, in the syntax the assembler reads: MOVW $1026, R3;
 * x+4(SB); R1<<2(R2); TEXT f<>(SB), 0, $16.
 *
 * These printers are written by hand, not derived with [@@deriving show]
 * as the compilers' dumps are, and they are not in a compat/ directory.
 * This is because their text is neither a debugging dump nor the format
 * of a reference to compare with: it is what a user reads and what a
 * program parses.
 * - The linker's messages use it to name the instruction they refuse
 *   (linker/Arm, Arm64: "x.s:12: illegal combination: MOVW $1026, R3").
 *   A derived printer would say (Asm.Ins { Asm.op = "MOVW"; ... }).
 * - mini-ld -v uses it to list the program, with an address and a word
 *   on each line, and kernels/9pi/tests/perf/pcprof.py reads that
 *   listing to name the functions of a profile.
 * So the syntax is the source's, and these printers are its grammar run
 * the other way. *)

(* an item, such as TEXT f(SB), 0, $16, or DATA x+0(SB)/4, $1, or an
 * instruction *)
val show_item : Asm.item -> string

(* an operand, such as R3, $42, x+4(SB), R1<<2(R2) or [R0,R1] *)
val show_operand : Asm.operand -> string

(* a place, such as n-4(SP), f+0(SB) or 8(R1) *)
val show_mem : Asm.mem -> string

(* [show_mem] on a formatter. A derived printer calls it for a place
 * inside its type (mini-cc's -dir). *)
val pp_mem : Format.formatter -> Asm.mem -> unit
