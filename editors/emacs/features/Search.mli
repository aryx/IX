(* The commands that search, and replace. efuns' Search, and its names.
 *
 * {b An incremental search} (C-s, C-r) looks as one types: each
 * character typed in the minibuffer moves the frame's point to the
 * next place the whole of it is found (the cursor shown is there).
 *
 *     C-s, C-r      the next place, the one before; with nothing typed
 *                   yet, the last search's string again
 *     DEL           a character less, searched from where one started
 *     RET           the point stays there
 *     C-g           the point back where one started
 *
 * (Another command does not end the search as in Emacs: it works in
 * the minibuffer.) What is typed is the text itself; in the regexp
 * commands a regular expression, Regex's: egrep's syntax, not Emacs's.
 * A capital and a small letter are not the same.
 *
 * {b A replacement} asks a string and what replaces it, from the
 * point to the text's end; query_replace asks at each place: y, n,
 * ! (this one and the rest), q. What replaces is the text itself (no
 * \1 for a group). *)

val isearch_forward : Efuns.action
val isearch_backward : Efuns.action
val isearch_forward_regexp : Efuns.action
val isearch_backward_regexp : Efuns.action

val replace_string : Efuns.action
val query_replace_string : Efuns.action
val replace_regexp : Efuns.action
val query_replace_regexp : Efuns.action
