(* The commands that change the text near the point into another form
 * of itself. efuns' Transform, and Emacs's keys. *)

(* the word after the point in capitals (M-u), in small letters (M-l),
 * its first letter a capital (M-c); the letters ASCII's *)
val upcase_word : Efuns.action
val downcase_word : Efuns.action
val capitalize_word : Efuns.action

(* the two characters around the point exchanged, the point after
 * them (C-t): teh, the point after e, is the; at a line's end, the
 * two before it *)
val transpose_chars : Efuns.action

(* the point's paragraph (the lines around it, to a blank one) made
 * again of lines of 70 columns at most, each starting as the first
 * does (M-q) *)
val fill_paragraph : Efuns.action

(* a line asked by its number (M-g g) *)
val goto_line : Efuns.action
