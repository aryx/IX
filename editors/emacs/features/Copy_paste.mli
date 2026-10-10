(* The mark, and the kill ring: what is taken out of a text is kept,
 * to be put back elsewhere. efuns' Copy_paste, and its names.
 *
 * The region is the text between the point and the buffer's mark. A
 * kill right after another, at the same place, is added to it: three
 * C-k are one piece to yank.
 *
 *     the text "one two three", the point after "one "
 *     M-d M-d           the ring:  "two three"        one piece, of two kills
 *     C-a C-k                      "one "  "two three"
 *     C-y               inserts "one "
 *     M-y               "two three" in its place
 *
 * "Right after" is not asked of the last command's name, as Emacs
 * does: a kill remembers the text's version and the point it left,
 * and the next one follows it if it finds them so. A kill backward
 * (M-DEL) is added before the piece, so that the piece reads as the
 * text did.
 *
 * terminology:
 * Kill and yank are Emacs's words for what everyone else calls cut
 * and paste (the words of Larry Tesler's editors at Xerox PARC in
 * the 1970s, which the Macintosh made everyone's), and
 * M-w, copy, is "kill-ring-save". vi says delete and put, and its
 * yank is the copy, not the paste. Plan 9 says snarf for the copy,
 * and keeps what was snarfed in a file, /dev/snarf, the window
 * system's.
 *
 * design:
 * A ring, not one place: a second kill does not lose the first,
 * which is the usual accident with one clipboard. The ring here is
 * the editor's own; it is not the window system's, so what is killed
 * is not pasted in another window. *)

(* the mark set where the point is (C-@, which is Control-Space), and
 * the two exchanged (C-x C-x) *)
val mark_at_point : Efuns.action
val point_at_mark : Efuns.action

(* the region killed (C-w), or copied to the ring (M-w) *)
val kill_region : Efuns.action
val copy_region : Efuns.action

(* to the line's end, or its newline when at the end (C-k); a word
 * forward (M-d), backward (M-DEL) *)
val kill_end_of_line : Efuns.action
val kill_forward_word : Efuns.action
val kill_backward_word : Efuns.action

(* the last piece killed inserted (C-y: yank); right after, the one
 * before in its place (M-y), and so on around the ring *)
val insert_killed : Efuns.action
val insert_next_killed : Efuns.action
