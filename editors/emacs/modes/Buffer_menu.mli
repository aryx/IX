(* The buffers' menu shows the editor's buffers as a buffer, one line
 * for each (C-x C-b), and RET on a line shows its buffer. It is
 * Emacs's, and efuns' Buffer_menu.
 *
 *     .*      Text.ml         5310    editors/emacs/core/Text.ml
 *
 * A line has a dot for the buffer the menu was asked from, a star for
 * a buffer modified, then the buffer's name, its text's length, and
 * its file. *)
val mode : Efuns.major_mode
val list_buffers : Efuns.action
