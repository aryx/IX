(* The .ml's lines in the object (plan_debugger.md, stage 1b), from
 * Gen's and Emit's "// line n" before each function in the assembly:
 * each item the line of its function's body, and the history the .ml
 * from its first line to the one after its last, what mini-ld -g
 * makes the pc/line table of. A line a call's, later. No line of a
 * .ml (the start's text, its functions all the compiler's): no
 * history. *)

(* [add caps file text obj]: obj, the assembly text's, with file's
 * lines *)
val add : < Cap.open_in; .. > -> Fpath.t -> string -> Asm.obj -> Asm.obj
