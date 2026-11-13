(* Dired shows a directory as a buffer, one line for each file (C-x
 * C-f of a directory), with the keys that open what the point's line
 * names. It is Emacs's, and efuns' Dired, which reads what ls answers;
 * here the directory itself is read.
 *
 *     d            ..             RET, f   the line's file or directory opened
 *     d            core/          ^        the directory above
 *     -      2310  Config.ml      g        read again
 *                                 n, p     a line down, up
 *
 * The other characters are not typed in: each shows a message that
 * recalls RET, ^ and g.
 *
 * It is the smallest example of a mode that is a program: a text
 * made by code (the listing), a map of a few keys, and commands that
 * read the point's line to know what is meant. Buffer_menu is the
 * same shape, and so are an Emacs's mail reader and its shell.
 *
 * others:
 * Emacs's Dired (the name means "directory editor") runs ls -l and
 * keeps its output as the text, finding the name in each line's
 * columns. Here the lines are made from the directory's entries, read
 * as Ls reads them (Sys_plan9.dirread gives a record for each file,
 * with its name, its length, and whether it is a directory). *)
val mode : Efuns.major_mode

(* how a name is shown (a directory's name ends with /). At first,
 * directories are in blue; a configuration sets another way
 * (Config_pad sets the author's dircolors). *)
val color : (string -> Vt.attrs) ref

(* [open_directory frame dir] shows the directory's buffer, made or
 * read again, in the frame *)
val open_directory : Efuns.frame -> string -> unit
