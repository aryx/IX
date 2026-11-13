(* What the linker keeps of its objects for a debugger
 * (plan_debugger.md), apart from the linking itself. Link calls it as it
 * reads an object, CLI calls it before the data's layout, and Symtab
 * writes the tables from what it keeps.
 *
 *     an object's history    -> File symbols, a function's Hist autos
 *     n+4(FP), n-8(SP)       -> a function's Param and Local autos
 *     its acid declarations  -> the data .acid (-g), which mini-acid runs
 *
 * The [lookup] argument is Link's lookup of a name's symbol, with
 * version 0. *)

(* An object's history, with its paths given as the numbers of File
 * symbols (5l's addhist). *)
val history : (string -> Program.sym) -> 'm Program.t -> Asm.obj -> Program.auto list

(* Records the parameters and locals of an object's functions (5l's
 * inopd), and puts the history in the first function (histtoauto). *)
val autos : Program.auto list -> 'm Program.prog option array -> unit

(* Puts the declarations of every object, each once, in the data as
 * .acid (decision 14 of plan_debugger.md). It runs before the data's
 * layout. *)
val acid_data : (string -> Program.sym) -> 'm Program.t -> unit
