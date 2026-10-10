(* The minibuffer: a question asked on the screen's last line, and its
 * answer typed in a buffer of one line, with every command of the
 * editor (a word killed, a file's name yanked): Emacs's idea, and
 * efuns' Minibuffer and Select. The buffer's own map has the keys that
 * end it: RET, the answer given; C-g, no answer.
 *
 *     Find file: editors/em_          TAB: what is typed made longer,
 *     Find file: editors/emacs/_      as far as the names that start
 *     Find file: editors/emacs/ [Config.ml Config.mli core/ ...]
 *                                     with it agree; then they are said
 *
 * One question at a time: a command that asks while one is asked
 * fails.
 *
 * A command that asks does not wait: [read] makes the frame, binds
 * RET in its buffer's map to a function that calls [action] with the
 * answer, and returns; the answer comes later, as a key like any
 * other (Top_window.mli says why). So C-x C-f is two commands, the
 * one that asks and the one RET runs.
 *
 * others:
 * A question is where most programs stop being themselves: a dialog
 * box with an editing of its own, poorer than the program's.
 * mini-turbopascal's is so (Turbo_menus.input_key: a character,
 * Backspace, Enter, Escape), as Turbo Pascal's was. vi asks on its
 * last line too, with ex's line editing and not vi's. Emacs's
 * answer, a buffer like the others, costs one frame more and gives
 * completion, the kill ring and the search in every question. *)

(* [create frame prompt]: the minibuffer's frame, the keys now its
 * own; its buffer's map is for the caller to bind in (C-g is bound) *)
val create : Efuns.frame -> string -> Efuns.frame

(* the cursor shown is not the minibuffer's but the asking frame's: a
 * search, which moves that frame's point as one types *)
val cursor_back : Efuns.frame -> unit

(* the minibuffer gone, the keys back to the frame that asked, which
 * is returned *)
val kill : Efuns.frame -> Efuns.frame

(* [read frame prompt initial complete action]: asked; at RET, action
 * on the frame that asked and the answer. complete: of what is typed,
 * the answers that start with it (TAB) *)
val read : Efuns.frame -> string -> string -> (string -> string list) -> (Efuns.frame -> string -> unit) -> unit

(* a complete for [read]: the names of a list; and none *)
val among : string list -> string -> string list
val no_completion : string -> string list

(* [yes_or_no frame question action]: action if "yes" is answered; if
 * [y_or_n] is set, the key y is the answer, with no RET (Emacs's
 * y-or-n-p in yes-or-no-p's place) *)
val yes_or_no : Efuns.frame -> string -> Efuns.action -> unit
val y_or_n : bool ref
