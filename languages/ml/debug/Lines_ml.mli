(* The .ml's lines in the object (plan_debugger.md, stage 1b), from
 * Gen's and Emit's "// line n" in the assembly, one before each
 * function (its body's line) and one where a statement starts on
 * another line (Ir.Line: a sequence's part, a let's, a condition, a
 * branch, a clause's tests): each item the line of the last mark
 * above it, and the history the .ml from its first line to the one
 * after its last, what mini-ld -g makes the pc/line table of. No line
 * of a .ml (the start's text, its functions all the compiler's): no
 * history. *)

(* [add caps file text obj]: obj, the assembly text's, with file's
 * lines *)
val add : < Cap.open_in; .. > -> Fpath.t -> string -> Asm.obj -> Asm.obj
