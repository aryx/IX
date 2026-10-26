(* Latex_math: mathematics, as far as words go -- letters in italic,
 * what is raised and lowered a size smaller, the symbols the PDF's
 * fonts have and a word for the others (Latex_names.symbols). No
 * fraction, no root's bar, nothing built in two dimensions: the
 * books have 352 lines with a $ and none of these
 * (docs/plans/done/plan_typesetting.md, stage 6, is the real thing). *)

(* what is between two $, in the paragraph *)
val math : Latex_state.t -> string -> unit

(* the same on a line of its own, in its middle *)
val display : Latex_state.t -> string -> unit
