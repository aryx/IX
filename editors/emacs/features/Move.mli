(* The commands that move the point. efuns' Move, and its names. *)

(* a character (C-f, C-b) *)
val move_forward : Efuns.action
val move_backward : Efuns.action

(* a line (C-n, C-p): to the column the first of several such moves
 * left, as near as each line has it *)
val forward_line : Efuns.action
val backward_line : Efuns.action

val beginning_of_line : Efuns.action
val end_of_line : Efuns.action

(* a word (M-f, M-b): letters and digits *)
val forward_word : Efuns.action
val backward_word : Efuns.action

(* the text's ends (M-<, M->) *)
val begin_of_file : Efuns.action
val end_of_file : Efuns.action
