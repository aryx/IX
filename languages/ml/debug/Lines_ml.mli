(* The .ml's lines in the object (plan_debugger.md, stage 1b), from
 * Gen's and Emit's "// line n" in the assembly, one before each
 * function (its body's line) and one where a statement starts on
 * another line (Ir.Line: a sequence's part, a let's, a condition, a
 * branch, a clause's tests): each item the line of the last mark
 * above it, and the history the .ml from its first line to the one
 * after its last, what mini-ld -g makes the pc/line table of. No line
 * of a .ml (the start's text, its functions all the compiler's): no
 * history. *)

(* [add caps file name text obj]: obj, the assembly text's, with file's
 * lines, the file named name in the history *)
val add : < Cap.open_in; .. > -> Fpath.t -> string -> string -> Asm.obj -> Asm.obj

(* file's path from ix's root (apps/rio/Rio.ml: the directory above it
 * with lib_core/units.txt), as the card's /src has it (plan_debugger.md,
 * stage 5b: a trace's line of code); as given outside ix *)
val source : < Cap.open_in; Cap.readdir; .. > -> Fpath.t -> string
