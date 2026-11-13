(* The commands that change the text near the point into another form
 * of itself. This is efuns' Transform, with Emacs's keys. *)

(* puts the word after the point in capitals (M-u), in small letters
 * (M-l), or makes its first letter a capital (M-c). Only ASCII's
 * letters change. *)
val upcase_word : Efuns.action
val downcase_word : Efuns.action
val capitalize_word : Efuns.action

(* exchanges the two characters around the point, and puts the point
 * after them (C-t): teh, with the point after e, becomes the. At a
 * line's end, it exchanges the two characters before the point. *)
val transpose_chars : Efuns.action

(* makes the point's paragraph (the lines around it, up to a blank
 * one) again, as lines of 70 columns at most, each starting as the
 * first line does (M-q) *)
val fill_paragraph : Efuns.action

(* goes to a line asked for by its number (M-g g) *)
val goto_line : Efuns.action
