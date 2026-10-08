(* An item as text, in the syntax the assembler reads: MOVW $1026, R3;
 * x+4(SB); R1<<2(R2); TEXT f<>(SB), 0, $16.
 *
 * Written by hand, not derived ([@@deriving show], as the compilers'
 * dumps are), and not in a compat/ directory, because this text is not
 * a debugging dump nor a reference's format to compare with: it is
 * what a user reads and what a program parses.
 * - The linker's messages name the instruction they refuse with it
 *   (linker/Arm, Arm64: "x.s:12: illegal combination: MOVW $1026, R3").
 *   A derived printer would say (Asm.Ins { Asm.op = "MOVW"; ... }).
 * - mini-ld -v lists the program with it, an address and a word a
 *   line, and kernels/9pi/tests/perf/pcprof.py reads that listing to
 *   name the functions of a profile.
 * So the syntax is the source's, and these printers are its grammar
 * the other way. *)

(* an item: TEXT f(SB), 0, $16; DATA x+0(SB)/4, $1; an instruction *)
val show_item : Asm.item -> string

(* an operand: R3, $42, x+4(SB), R1<<2(R2), [R0,R1] *)
val show_operand : Asm.operand -> string

(* a place: n-4(SP), f+0(SB), 8(R1) *)
val show_mem : Asm.mem -> string

(* the same on a formatter: what a derived printer calls for a place
 * in its type (mini-cc's -dir) *)
val pp_mem : Format.formatter -> Asm.mem -> unit
