(* The buffers' menu: the editor's buffers as a buffer, a line each
 * (C-x C-b), RET on a line shows its buffer. Emacs's, and efuns'
 * Buffer_menu.
 *
 *     .*      Text.ml         5310    editors/emacs/core/Text.ml
 *
 * a dot for the buffer the menu was asked from, a star for one
 * modified, its name, its text's length, its file. *)
val mode : Efuns.major_mode
val list_buffers : Efuns.action
