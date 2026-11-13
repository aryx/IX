(* mini-emacs's configuration is OCaml, compiled with the editor:
 * there is no file of options read at the start, and no Lisp. Here are
 * the editor's keys, which are Emacs's (efuns' config/default_config
 * is the same list), and the modes. The colors are in Highlight.
 *
 *     "C-x C-s", Multi_buffers.save_buffer;
 *
 * is one line of it (each line is given to Keymap.add_global_key).
 * Reading this file's .ml is reading the editor's manual, with each
 * key beside the function that does it.
 *
 * others:
 * Emacs reads ~/.emacs at its start, a Lisp program that binds keys
 * and sets variables with the same functions that the editor's own
 * files use. vi reads a list of its : commands, and most editors of
 * today read a file of settings (JSON). The first way makes the user
 * a programmer of the editor. It is kept here, with the compiler in
 * the interpreter's place (Start.mli says what that costs): Config_pad
 * is the author's .emacs. *)

(* a file's mode, chosen by the end of its name, for the languages ix
 * has *)
val modes : unit -> unit

(* the keys bound in the editor's map *)
val keys : unit -> unit
