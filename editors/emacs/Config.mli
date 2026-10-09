(* mini-emacs's configuration: OCaml, compiled with it (no file of
 * options read at the start, no Lisp). Here the editor's keys, Emacs's
 * (efuns' config/default_config is the same list), and the modes. The
 * colors are Highlight's. *)

(* a file's mode by its name's end: the languages ix has *)
val modes : unit -> unit

(* the keys bound in the editor's map *)
val keys : unit -> unit
