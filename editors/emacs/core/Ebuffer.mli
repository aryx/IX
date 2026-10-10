(* A buffer: a text, the file it is of (or none), its keys and its
 * modes. efuns' Ebuffer; "E" as Buffer is the standard library's.
 *
 * A buffer is not a file: it is the file's bytes read once, changed
 * in memory, and written back when asked (C-x C-s); "modified" is
 * the text's version being another than when it was read or written.
 * And it is not a frame: no frame, one or several may show it.
 *
 * reframe:
 * Everything shown is a buffer. A directory's list (Dired), the list
 * of the buffers (Buffer_menu), the answer typed to a question (the
 * Minibuffer's one line) are each a text in a buffer with a map of
 * its own, so that moving, searching, killing and yanking work in
 * all of them with no code written for it: a file's name is yanked
 * into the minibuffer, a directory is searched with C-s. What makes
 * each what it is are the few keys its mode binds (Keymap). This is
 * Emacs's economy, and the reason a new tool in it (a shell, a mail
 * reader) is first a buffer.
 *
 * plan9-is-cleaner:
 * Plan 9's acme goes one step further in the same direction: a
 * window's text is a file (its body, its tag, under /mnt/acme), so
 * what extends the editor is any program that reads and writes
 * them, in any language, where an Emacs's extensions are functions
 * inside it. *)

(* the mode of a buffer that has no other *)
val fundamental_mode : Efuns.major_mode

(* [create name filename text]: a buffer of the editor's, its name
 * made its own (a second foo.ml is foo.ml<2>); [make]: a buffer the
 * editor does not know (the minibuffer's) *)
val create : string -> string option -> Text.t -> Efuns.buffer
val make : string -> string option -> Text.t -> Efuns.buffer

(* the buffer's mode changed: its minor modes none, then what the mode
 * sets (its hooks) *)
val set_major_mode : Efuns.buffer -> Efuns.major_mode -> unit

(* [colors buf start lines]: by the buffer's mode, the colors of the
 * lines from start's on, that many of them at least; None for a mode
 * that has none. With them, the number of start's line among those
 * given: the highlighter is asked a part of the text that begins
 * before (Ebuffer.ml says where and why), and again only when the text
 * has changed or lines are asked that it was not given.
 * [whole]: the whole text given, the simple way. *)
val colors : Efuns.buffer -> int -> int -> (Efuns.colors * int) option
val whole : bool ref

(* no longer one of the editor's *)
val kill : Efuns.buffer -> unit

val find_buffer_opt : string -> Efuns.buffer option

(* the buffer of a file: the one that has it already, or the file
 * read; a file that is not there is an empty buffer, made when saved.
 * Its mode is the one the editor has for its name's end (edt_modes). *)
val read : < Cap.open_in ; .. > -> string -> Efuns.buffer

(* written to its file; Failure if it has none, Sys_error if it
 * cannot be *)
val save : < Cap.open_out ; .. > -> Efuns.buffer -> unit

(* the editor's buffers' names, the last shown first *)
val names : unit -> string list

(* changed since it was read or saved *)
val modified : Efuns.buffer -> bool
