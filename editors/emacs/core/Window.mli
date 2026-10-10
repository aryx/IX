(* The windows: a screen's rectangle given to a frame, or split in two
 * for two windows, side by side (HComb) or one over the other
 * (VComb), again and again. The tree is all there is: each frame has
 * its place, given from the top by [place] when the tree or the
 * screen changes (efuns' windows have theirs, and a link upward).
 *
 *     C-x 2, then C-x 3 in the upper frame, on a screen of 80 by 23:
 *
 *     VComb (HComb (WFrame a, WFrame b), WFrame c)
 *
 *     +---------+---------+      place gives a 40 columns by 11 rows
 *     | a       | b       |      at 0, 0; b 39 by 11 at 41, 0 (a
 *     +---------+---------+      column between them, the bar's);
 *     | c                 |      c 80 by 12 at 0, 11
 *     +-------------------+
 *
 * C-x 0 on b: [remove] gives VComb (WFrame a, WFrame c), a taking
 * the place of both.
 *
 * others:
 * The screen shared without overlap, each split a half: a tiling.
 * It is what an editor wants (nothing hides text) and what acme does
 * with columns; mini-rio's windows, placed by the mouse and one over
 * the other, are the other kind (mini-emacs runs in one). *)

(* its frames, from the left and the top *)
val frames : Efuns.window -> Efuns.frame list

(* [replace window frame by]: the tree with by where the frame was;
 * [remove window frame]: without the frame, the window beside it
 * taking the place of both (None: it was the only one). Not_found if
 * the frame is not in the tree (the minibuffer's). *)
val replace : Efuns.window -> Efuns.frame -> Efuns.window -> Efuns.window
val remove : Efuns.window -> Efuns.frame -> Efuns.window option

(* [place window x y width height]: the rectangle shared out to the
 * frames, two windows a half each (side by side, a column between
 * them is left for a bar) *)
val place : Efuns.window -> int -> int -> int -> int -> unit
