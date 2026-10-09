(* Dired: a directory as a buffer, a line a file (C-x C-f of a
 * directory), and the keys that open what the point's line names.
 * Emacs's, and efuns' Dired, which reads ls's answer; here the
 * directory is read.
 *
 *     d            ..             RET, f   the line's file or directory opened
 *     d            core/          ^        the directory above
 *     -      2310  Config.ml      g        read again
 *                                 n, p     a line down, up
 *
 * The other characters do nothing there: the text is not typed in. *)
val mode : Efuns.major_mode

(* how a name is shown (a directory's ends with /): directories in
 * blue at first; a configuration sets another (Config_pad: the
 * author's dircolors) *)
val color : (string -> Vt.attrs) ref

(* [open_directory frame dir]: its buffer, made or read again, in the frame *)
val open_directory : Efuns.frame -> string -> unit
