(* Latex_math: mathematics, as far as words go. Letters are in italic,
 * what is raised and lowered is a size smaller, and there are the
 * symbols that the PDF's fonts have, with a word for the others
 * (Latex_names.symbols). There is no fraction, no bar over a root, and
 * nothing built in two dimensions, because the books have 352 lines
 * with a $ and none of these (docs/plans/done/plan_typesetting.md,
 * stage 6, is the real thing). *)

(* what is between two $, inside the paragraph *)
val math : Latex_state.t -> string -> unit

(* the same, on a line of its own, in the middle *)
val display : Latex_state.t -> string -> unit
