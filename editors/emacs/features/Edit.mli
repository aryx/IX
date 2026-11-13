(* The commands that change the text at the point. This is efuns'
 * Edit, with its names. *)

(* [insert_string frame s] inserts s at the point, and puts the point
 * after it *)
val insert_string : Efuns.frame -> string -> unit

(* inserts the key typed, which is a character: this is what a key
 * bound to nothing else does (Keymap.any_char) *)
val self_insert_command : Efuns.action

(* inserts a new line (RET), or a tab (TAB) *)
val insert_return : Efuns.action
val insert_tab : Efuns.action

(* deletes the character at the point (C-d), or the one before it
 * (DEL) *)
val delete_char : Efuns.action
val delete_backspace_char : Efuns.action

(* takes back the last command's changes, then those of the command
 * before (C-_, C-x u); a word typed counts as one command *)
val undo : Efuns.action
