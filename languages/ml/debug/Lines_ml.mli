(* The .ml's lines in the object (plan_debugger.md, stage 1b). They
 * come from the "// line n" marks that Gen and Emit write in the
 * assembly: one before each function (with its body's line), and one
 * where a statement starts on another line (Ir.Line: a part of a
 * sequence, a let's definition, a condition, a branch, a clause's
 * tests). Each item gets the line of the last mark above it, and the
 * history spans the .ml from its first line to the one after its
 * last. From these, mini-ld -g makes the pc/line table. When the
 * assembly has no line of a .ml (as in the start object's text, whose
 * functions are all the compiler's), there is no history. *)

(* [add caps file name text obj] is obj, the object of the assembly
 * text, with the lines of file; the history names the file name. *)
val add : < Cap.open_in; .. > -> Fpath.t -> string -> string -> Asm.obj -> Asm.obj

(* file's path from ix's root, such as apps/rio/Rio.ml, where the root
 * is the directory above the file that has lib_core/units.txt. It is
 * the path the card's /src has (plan_debugger.md, stage 5b: a trace's
 * line of code). Outside ix, the path is returned as given. *)
val source : < Cap.open_in; Cap.readdir; .. > -> Fpath.t -> string
