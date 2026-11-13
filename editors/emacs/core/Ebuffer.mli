(* A buffer is a text, the file it comes from (or none), its keys and
 * its modes. It is efuns' Ebuffer; the "E" is there because Buffer is
 * the standard library's.
 *
 * A buffer is not a file: it is the file's bytes read once, changed
 * in memory, and written back when asked (C-x C-s). A buffer is
 * "modified" when its text's version is another than when it was read
 * or written. And a buffer is not a frame: no frame, one frame or
 * several may show it.
 *
 * reframe:
 * Everything shown is a buffer. A directory's list (Dired), the list
 * of the buffers (Buffer_menu), and the answer typed to a question
 * (the Minibuffer's one line) are each a text in a buffer with a map
 * of its own. So moving, searching, killing and yanking work in all
 * of them with no code written for it: you can yank a file's name
 * into the minibuffer, or search a directory with C-s. What makes
 * each of them what it is are the few keys its mode binds (Keymap).
 * This is Emacs's economy, and the reason a new tool in it (a shell,
 * a mail reader) starts as a buffer.
 *
 * plan9-is-cleaner:
 * Plan 9's acme goes one step further in the same direction: a
 * window's text is a file (its body and its tag are files under
 * /mnt/acme). So what extends the editor is any program, in any
 * language, that reads and writes them, while an Emacs's extensions
 * are functions inside it. *)

(* the mode of a buffer that has no other mode *)
val fundamental_mode : Efuns.major_mode

(* [create name filename text] makes a buffer that the editor knows,
 * with a name made unique (a second foo.ml is named foo.ml<2>).
 * [make] makes a buffer that the editor does not know (the
 * minibuffer's). *)
val create : string -> string option -> Text.t -> Efuns.buffer
val make : string -> string option -> Text.t -> Efuns.buffer

(* changes the buffer's mode: the buffer then has no minor modes, and
 * the mode's hooks set what they set *)
val set_major_mode : Efuns.buffer -> Efuns.major_mode -> unit

(* [colors buf start lines] gives, by the buffer's mode, the colors of
 * the lines from start's line on, at least that many of them, or None
 * for a mode that has no colors. With them comes the number of
 * start's line among the lines given. The highlighter is asked for a
 * part of the text that begins before start (Ebuffer.ml says where
 * and why), and asked again only when the text has changed or when
 * lines are asked that it was not given.
 * When [whole] is set, the whole text is given, the simple way. *)
val colors : Efuns.buffer -> int -> int -> (Efuns.colors * int) option
val whole : bool ref

(* the buffer is no longer one of the editor's *)
val kill : Efuns.buffer -> unit

val find_buffer_opt : string -> Efuns.buffer option

(* the buffer of a file: the one that has it already, or else the file
 * is read. A file that is not there gives an empty buffer, and the
 * file is made when the buffer is saved. The buffer's mode is the one
 * the editor has for the end of the file's name (edt_modes). *)
val read : < Cap.open_in ; .. > -> string -> Efuns.buffer

(* writes the buffer to its file; raises Failure if it has no file,
 * and Sys_error if the file cannot be written *)
val save : < Cap.open_out ; .. > -> Efuns.buffer -> unit

(* the names of the editor's buffers, the last one shown first *)
val names : unit -> string list

(* whether the buffer changed since it was read or saved *)
val modified : Efuns.buffer -> bool
