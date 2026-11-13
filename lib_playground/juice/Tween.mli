(* A tween is a value that goes from one number to another over a given
   time, along a curve (Ease.mli), as a function of when it started.

   The word is the animators' "in-between": the master drew the key
   poses, and the in-betweeners drew the frames between them. Here the
   key poses are two numbers, and the in-between is computed:

      value
      100 |                  .------------   the end, held
          |              .-'
          |           .-'     out_quad, 0 to 100 over 2 s,
          |         /         started at 1 s
          |        /
        0 |-------'           the start, held before it begins
          +-------+-------+-------+-------> now (s)
          0       1       2       3

   There are two ways to write one. In Flash's way (ActionScript, 2002,
   and most engines since), a tween is an object, registered once, that
   changes a variable a bit every frame until it is done. It is state
   that lives outside the program's own, and it must be stopped or it
   keeps running. In Elm's way (elm-community/easing-functions), a
   tween is only a formula of the time now, and all the program keeps
   is *when it started*. The value is recomputed each frame from that,
   so there is nothing to step, nothing to stop, and a replay or a
   rewind shows the same frame at the same time. This module is Elm's
   way, which is the only one a Model-View-Update program can have
   without cheating: its model can hold a start time, not a running
   object.

   It takes three small steps, and each one is a function below:

     progress   now -> how far through the time, clamped to [0, 1]
     curve      that fraction through an Ease.t
     lerp       the result from one number to the other

   Worked example (the figure, checked by the tests): out_quad goes from
   0 to 100 over 2 s, started at 1 s. At 0.5 s it has not started, so
   the value is 0. At 2 s, halfway through the time, out_quad 0.5 =
   0.75, so the value is 75, already three quarters of the way. At 3.5 s
   it is over, and the value is 100, held.

   Honest about scale: a tween knows its end from the start. When the
   end moves while it plays (a camera following the player), use a
   spring, stepped each frame. *)
(* ix: copied from libs/juice/Tween.mli in the author's playground *)

(* [lerp a b p] is [a] at 0 and [b] at 1, on a straight line in between
 * (and beyond, because it is not clamped) *)
val lerp : float -> float -> float -> float

(* [progress ~start ~duration now] is how far through the time [now] is:
 * 0 before [start], and 1 from [start + duration] on. It is 1 at once
 * when [duration] <= 0. *)
val progress : start:float -> duration:float -> float -> float

(* [value curve a b ~start ~duration now] is the value at [now], going
 * from [a] to [b] along [curve] *)
val value : Ease.t -> float -> float -> start:float -> duration:float -> float -> float

(* [finished ~start ~duration now] tells whether the tween has reached
 * its end *)
val finished : start:float -> duration:float -> float -> bool
