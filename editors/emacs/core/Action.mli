(* The commands by their names, which is what M-x asks for. A file of
 * commands ends with the list of its own commands, given to
 * [define_all] (efuns marks each one with [@@interactive], which a
 * preprocessor reads).
 *
 *     Action.define_all [ "forward_word", forward_word; ... ]   in Move
 *     M-x forward_w RET          Interactive asks; when only one name
 *                                starts so, that is enough
 *     find_opt "forward_word" = Some forward_word      and it is run
 *
 * A key is one name for a command, and this is the other. There are
 * more commands than keys worth remembering, and a configuration can
 * bind a key to any of them.
 *
 * others:
 * In Emacs a command is a Lisp function with an (interactive ...)
 * form in it, which says how its arguments are asked for when it is
 * called by a key: the prefix argument, the region's two ends, or a
 * string read in the minibuffer. Called from Lisp, it takes them as
 * any function does. Here a command has one argument, the frame, and
 * asks for the rest itself (Minibuffer.read). *)

val define : string -> Efuns.action -> unit
val define_all : (string * Efuns.action) list -> unit

val find_opt : string -> Efuns.action option
(* the names, sorted *)
val names : unit -> string list
