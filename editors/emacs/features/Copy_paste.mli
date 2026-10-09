(* The mark, and the kill ring: what is taken out of a text is kept,
 * to be put back elsewhere. efuns' Copy_paste, and its names.
 *
 * The region is the text between the point and the buffer's mark. A
 * kill right after another, at the same place, is added to it: three
 * C-k are one piece to yank. *)

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
