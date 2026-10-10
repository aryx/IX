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
 * The other characters do nothing there: the text is not typed in.
 *
 * It is the smallest example of a mode that is a program: a text
 * made by code (the listing), a map of a few keys, and commands that
 * read the point's line to know what is meant. Buffer_menu is the
 * same shape, and so are an Emacs's mail reader and its shell.
 *
 * others:
 * Emacs's Dired (the name is "directory editor") runs ls -l and
 * keeps its output as the text, finding the name in each line's
 * columns. Here the lines are made from the directory's entries,
 * read as Ls reads them (Sys_plan9.dirread: a record a file, its
 * name, its length, whether it is a directory). *)
val mode : Efuns.major_mode

(* how a name is shown (a directory's ends with /): directories in
 * blue at first; a configuration sets another (Config_pad: the
 * author's dircolors) *)
val color : (string -> Vt.attrs) ref

(* [open_directory frame dir]: its buffer, made or read again, in the frame *)
val open_directory : Efuns.frame -> string -> unit
