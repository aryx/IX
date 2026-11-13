(* The author's own configuration, as in his ~/.emacs and his efuns'
 * config/pad.ml. It is OCaml, compiled with the program, and used
 * unless mini-emacs is started with -q. Someone else's configuration
 * would be a file like this one, called in its place. It sets:
 *
 * - The colors: wheat on DarkSlateGray; a keyword is orange, a number
 *   yellow, punctuation cyan, an operator blue, a comment gray, a
 *   string green... (codemap's colors, "pad taste"). They are given by
 *   their red, green and blue, for a terminal of today.
 * - A file's name in a directory is colored by what the file is (his
 *   dircolors.el): a directory is blue, a source yellow, an interface
 *   golden, an object gray, a document turquoise...
 * - Keys: M-g goes to a line by its number, M-C-l shows the buffer
 *   shown before, and M-<down> and M-<up> move a line and scroll the
 *   text by one line too.
 * - y answers yes, and the compiler's files are not proposed when a
 *   file's name is completed.
 *
 * Some of his keys have nothing for them in mini-emacs: M-RET
 * (compile), C-n as the next error, M-1 to M-5 (a shell), and the keys
 * a terminal cannot send: C-TAB, C-M-TAB, C-!. *)
val config : unit -> unit
