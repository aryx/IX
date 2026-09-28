(* mini-asm: the assembler. Reads a .s file, writes its object, the
 * instructions as they are (Asm). Its usage: [help] in CLI.ml, what
 * mini-asm -h prints. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
