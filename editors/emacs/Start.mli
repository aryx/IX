(* mini-emacs started, for a host to run (a terminal, a window): the
 * configuration (Config; the author's, Config_pad, unless told not),
 * a first buffer (the file's or the directory's; with none, one of no
 * file) in a top
 * window of 24 rows by 80 columns until the host says its size. *)
val editor : Efuns.caps -> pad:bool -> string option -> Top_window.model Tui.program
