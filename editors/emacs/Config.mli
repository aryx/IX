(* mini-emacs's configuration: OCaml, compiled with it (no file of
 * options read at the start, no Lisp). Here the editor's keys, Emacs's
 * (efuns' config/default_config is the same list), and the modes. The
 * colors are Highlight's.
 *
 *     "C-x C-s", Multi_buffers.save_buffer;
 *
 * is a line of it (each given to Keymap.add_global_key): reading
 * this file's .ml is reading the editor's manual, each key beside
 * the function that does it.
 *
 * others:
 * Emacs reads ~/.emacs at its start, a Lisp program that binds keys
 * and sets variables with the same functions the editor's own files
 * use; vi reads a list of its : commands; most editors of today a
 * file of settings (JSON). The first makes the user a programmer of
 * the editor and is kept here, with the compiler in the interpreter's
 * place (Start.mli says what that costs): Config_pad is the author's
 * .emacs. *)

(* a file's mode by its name's end: the languages ix has *)
val modes : unit -> unit

(* the keys bound in the editor's map *)
val keys : unit -> unit
