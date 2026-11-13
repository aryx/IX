(* The mark, and the kill ring: what is taken out of a text is kept,
 * to be put back elsewhere. This is efuns' Copy_paste, with its names.
 *
 * The region is the text between the point and the buffer's mark. A
 * kill right after another, at the same place, is added to the
 * other's piece: three C-k make one piece to yank.
 *
 *     the text "one two three", the point after "one "
 *     M-d M-d           the ring:  "two three"        one piece, of two kills
 *     C-a C-k                      "one "  "two three"
 *     C-y               inserts "one "
 *     M-y               "two three" in its place
 *
 * "Right after" is not found from the last command's name, as Emacs
 * does. Instead, a kill remembers the text's version and the point it
 * left, and the next kill follows it if it finds them unchanged. A
 * kill backward (M-DEL) is added before the piece, so that the piece
 * reads as the text did.
 *
 * terminology:
 * Kill and yank are Emacs's words for what everyone else calls cut
 * and paste (the words of Larry Tesler's editors at Xerox PARC in
 * the 1970s, which the Macintosh made everyone's), and M-w, the copy,
 * is "kill-ring-save". vi says delete and put, and its yank is the
 * copy, not the paste. Plan 9 says snarf for the copy, and keeps what
 * was snarfed in a file of the window system, /dev/snarf.
 *
 * design:
 * It is a ring, not one place, so a second kill does not lose the
 * first, which is the usual accident with one clipboard. The ring
 * here is the editor's own and not the window system's, so what is
 * killed cannot be pasted in another window. *)

(* [mark_at_point] sets the mark where the point is (C-@, which is
 * Control-Space), and [point_at_mark] exchanges the two (C-x C-x) *)
val mark_at_point : Efuns.action
val point_at_mark : Efuns.action

(* kills the region (C-w), or copies it to the ring (M-w) *)
val kill_region : Efuns.action
val copy_region : Efuns.action

(* kills to the line's end, or the newline when the point is at the
 * end (C-k); kills a word forward (M-d), or backward (M-DEL) *)
val kill_end_of_line : Efuns.action
val kill_forward_word : Efuns.action
val kill_backward_word : Efuns.action

(* inserts the last piece killed (C-y, a yank). Right after it, M-y
 * puts the piece before in its place, and so on around the ring. *)
val insert_killed : Efuns.action
val insert_next_killed : Efuns.action
