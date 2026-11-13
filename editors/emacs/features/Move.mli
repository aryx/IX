(* The commands that move the point. This is efuns' Move, with its
 * names. *)

(* move by a character (C-f, C-b) *)
val move_forward : Efuns.action
val move_backward : Efuns.action

(* move by a line (C-n, C-p), to the column that the first of several
 * such moves left from, or as near to it as each line allows *)
val forward_line : Efuns.action
val backward_line : Efuns.action

val beginning_of_line : Efuns.action
val end_of_line : Efuns.action

(* move by a word (M-f, M-b); a word is letters and digits *)
val forward_word : Efuns.action
val backward_word : Efuns.action

(* move to the text's ends (M-<, M->) *)
val begin_of_file : Efuns.action
val end_of_file : Efuns.action
