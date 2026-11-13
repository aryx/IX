(* Squash and stretch: a thing that flattens when it lands and
   stretches when it springs back, while its area is kept.

   It is the first of Disney's twelve principles (Thomas and Johnston,
   The Illusion of Life, 1981), and the first exercise of every
   animation student: the bouncing ball, then the half-full flour sack.
   A ball that stays round when it hits the floor looks like a billiard
   ball on stone -- hard, heavy, dead; the same ball flattening for a
   tenth of a second reads as rubber, and as *hitting* something.

   There are two ideas, and each one is a function below.

   Keep the area. A ball squashed to 60% of its height and no wider
   looks like it shrank; squashed and widened by as much, it looks like
   the same ball under a force. A shape k times taller is made k times
   narrower:

         k = 1          k = 0.6              k = 1.15
                                              ___
         .--.                                /   \
        /    \       .----------.           |     |
        \    /       '----------'           |     |
         '--'                                \___/

       40 x 40        66.7 x 24            34.8 x 46
                (the same area: 1600 = 66.7 x 24 = 34.8 x 46)

   The landing is a curve. The ball is flat at the moment it lands
   (1 − [amount] of its height), then goes back up, past round (a
   stretch), and settles. This is the elastic curve of Ease.mli,
   out_elastic, read as the height. Its overshoot is the stretch, so no
   second rule is needed for it.

   Worked example (checked by the tests), with [amount] 0.4. At landing
   the height is 0.6, so the width is 1/0.6 = 1.667: a 40-pixel ball is
   66.7 wide and 24 tall. At 5% of the time it is 0.859 tall, and at
   10% it is 1.1 (stretched). It is tallest, 1.149, at 13%; at half the
   time it is 1.006, nearly round again; at the end it is exactly 1.

   Honest about scale: a real ball squashes against the surface it
   hits, in the direction it hits. Here the squash is always vertical,
   about the point the ball stands on (the caller chooses which point
   that is), and the stretch in flight along the velocity (a comet's
   tail) is left out. *)
(* ix: copied from libs/juice/Squash.mli in the author's playground *)

(* [keep_area k] returns the (horizontal, vertical) scales of a shape
 * that is taller by [k], which are [(1 / k, k)] *)
val keep_area : float -> float * float

(* [landing ~amount p] returns the height, as a factor, at [p] of the
 * time after landing (from 0 to 1). The height is 1 − [amount] at 0,
 * springs back past 1, and is exactly 1 at 1. *)
val landing : amount:float -> float -> float
