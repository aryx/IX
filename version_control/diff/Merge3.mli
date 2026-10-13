(* Three-way merge of files: principia's merge3 (9front's), which
 * git/merge runs on each file both sides changed.
 *
 * Two diffs from the base, one to each side; their changes taken in
 * base order. A change only one side made is taken; two changes whose
 * base ranges overlap are widened to the same range, and taken once if
 * their new text is the same, or else written as a conflict:
 *
 *   <<<<<<<<<< ours.c
 *   our lines
 *   ========== original
 *   the base's lines
 *   ========== theirs.c
 *   their lines
 *   >>>>>>>>>>
 *
 * (ten characters, and the base section always, where diff3 -m and
 * git write seven and no base.) One quirk is kept: the base lines
 * before a change the second side made are bounded by the first
 * side's length (the C's fetch compares its Biobuf with the first
 * diff's).
 *
 * design:
 * Why three. With two versions that differ, a line in one and not
 * in the other was added here or removed there: one cannot tell.
 * With the version both came from, each side's diff from it says
 * who changed what, and what one side alone changed is taken
 * without asking. In a history the base is found, not given: the
 * common ancestor of the two commits (Query's @). The merge is of
 * lines and knows nothing of the language: two changes that do not
 * touch are joined though the program may no longer compile, and
 * two that touch are a conflict though they may agree in meaning.
 *
 * References: diff3(1), Unix's program for the same; S. Khanna,
 * K. Kunal and B. Pierce, "A Formal Investigation of Diff3" (2007),
 * for what such a merge does and does not promise. *)

(* the merged text, and whether it has a conflict *)
val merge : left:Diff.file -> base:Diff.file -> right:Diff.file -> string * bool
