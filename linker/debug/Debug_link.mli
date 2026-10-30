(* What the linker keeps of its objects for a debugger (plan_debugger.md),
 * apart from the linking: Link calls it as it reads an object, CLI
 * before the data's layout, and Symtab writes the tables from it.
 *
 *     an object's history  -> File symbols, a function's Hist autos
 *     n+4(FP), n-8(SP)     -> a function's Param and Local autos
 *     its acid declarations -> the data .acid (-g): mini-acid runs it
 *
 * lookup is Link's, a name's symbol (version 0). *)

(* an object's history, its paths as File symbols' numbers (5l's
 * addhist) *)
val history : (string -> Program.sym) -> 'm Program.t -> Asm.obj -> Program.auto list

(* an object's functions' parameters and locals (5l's inopd), the
 * history in its first function (histtoauto) *)
val autos : Program.auto list -> 'm Program.prog option array -> unit

(* the declarations of every object, each once, as the data .acid
 * (decision 14 of plan_debugger.md); before the data's layout *)
val acid_data : (string -> Program.sym) -> 'm Program.t -> unit
