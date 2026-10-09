(* The windows: a screen's rectangle given to a frame, or split in two
 * for two windows, side by side (HComb) or one over the other
 * (VComb), again and again. The tree is all there is: each frame has
 * its place, given from the top by [place] when the tree or the
 * screen changes (efuns' windows have theirs, and a link upward). *)

(* its frames, from the left and the top *)
val frames : Efuns.window -> Efuns.frame list

(* [place window x y width height]: the rectangle shared out to the
 * frames, two windows a half each (side by side, a column between
 * them is left for a bar) *)
val place : Efuns.window -> int -> int -> int -> int -> unit
