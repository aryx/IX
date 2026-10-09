(* The author's own configuration, as his ~/.emacs and his efuns'
 * config/pad.ml: OCaml, compiled with the program and used unless
 * mini-emacs is started with -q. Another's would be a file as this
 * one, called in its place.
 *
 * - The colors: wheat on DarkSlateGray; a keyword orange, a number
 *   yellow, punctuation cyan, an operator blue, a comment gray, a
 *   string green... (codemap's colors, "pad taste"). They are colors by
 *   their red, green and blue: for a terminal of today.
 * - A file's name in a directory by what it is (his dircolors.el: a
 *   directory blue, a source yellow, an interface golden, an object
 *   gray, a document turquoise...).
 * - Keys: M-g a line by its number, M-C-l the buffer shown before,
 *   M-<down> and M-<up> a line with the text scrolled one too.
 * - y for yes; the compiler's files not proposed when a file's name is
 *   completed.
 *
 * Of his keys, what mini-emacs has nothing for: M-RET (compile), C-n as
 * the next error, M-1 to M-5 (a shell), and what a terminal cannot
 * say: C-TAB, C-M-TAB, C-!. *)
val config : unit -> unit
