(* The commands that change the text at the point. efuns' Edit, and
 * its names. *)

(* [insert_string frame s]: s at the point, the point after it *)
val insert_string : Efuns.frame -> string -> unit

(* the key typed, a character, inserted: what a key bound to nothing
 * else does (Keymap.any_char) *)
val self_insert_command : Efuns.action

(* a new line (RET), a tab (TAB) *)
val insert_return : Efuns.action
val insert_tab : Efuns.action

(* the character at the point (C-d), the one before it (DEL) *)
val delete_char : Efuns.action
val delete_backspace_char : Efuns.action
