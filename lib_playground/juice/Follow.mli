(* Follow: a value that goes after a target that moves.

   A tween (Tween.mli) knows its end from the start. A camera following
   the player, a health bar draining after a hit, a pair of eyes
   following a ball: their target moves while they go, so they can't be
   a curve of the time -- they are a state, stepped each frame towards
   wherever the target is now. There are two ways, the simple one and
   the better one, as everywhere in this repository.

   The simple one closes a fraction of the gap each frame. Everyone
   writes it first, [x += (target - x) * 0.1]; its flaw is that 0.1 a
   frame is a different speed at 30 and at 144 frames a second. Written
   with the time, the fraction is 1 - e^(-rate dt), and [smooth] is the
   same whatever the frame rate: it is an exponential decay towards the
   target, which is 63% of the way after 1/rate seconds. It never
   overshoots, which is its limit: it starts at full speed and has no
   weight -- it follows like a string, not like a thing.

   The better one is a spring. The value has a velocity, which is
   pulled towards the target and slowed by damping, like a mass on a
   spring in a bath:

     acceleration = w^2 (target - value) - 2 z w velocity,   w = 2 pi f

   Two numbers say how it behaves, and they are the ones to think in
   (t3ssel8r, "Giving Personality to Procedural Animations using Math",
   2022; the mass-spring-damper of any mechanics course): the frequency
   [f], which is how fast it answers (in Hz), and the damping [z]. A
   damping of 1 is critical: the value goes as fast as it can without
   overshooting (Unity's SmoothDamp, after Game Programming Gems 4,
   2004). Below 1 it overshoots and settles, which reads as alive;
   above 1 it is sluggish.

     value
       |      z = 0.5        .--.
     1 |- - - - - - - - - -.'- - '--.____ - - - - - - -   target
       |               .-'   z = 1  ___.----------------
       |            .-'     __.---''
       |         .-'   _.-''
       |      .-'  _.-'
     0 +-----''--''--------------------------------> time

   It is stepped like the physics engine: the velocity first, then the
   value with the new velocity (semi-implicit Euler,
   physics/2d/Integrate.mli).

   Worked example (checked by the tests), from 0 to a target of 1 at 60
   frames a second. [chase] at 2 Hz, critically damped, is at 0.830
   after a quarter second and 95% of the way at 0.40 s (frame 24), and
   it never goes past 1. At a damping of 0.5, it overshoots to 1.142;
   the continuous answer is e^(-pi z / sqrt (1 - z^2)) = 16.3% too far,
   and stepping by frames loses some of it. [smooth] at a rate of 10 is
   at 0.632 after 0.1 s, exactly 1 - e^-1, at any frame rate.

   Honest about scale: t3ssel8r's version has a third number, the
   response, which makes a follower anticipate (start the wrong way,
   like [back] in Ease.mli); it is left out here. And at 60 frames a
   second the step stays stable up to about 19 Hz (w dt < 2); a
   follower that fast is a jump anyway. *)
(* ix: copied from libs/juice/Follow.mli in the author's playground,
 * with its optional arguments made required *)

(* a value on its way, and its velocity *)
type t = { value : float; velocity : float }

(* [at x] is a value at [x], still *)
val at : float -> t

(* [chase ?frequency ?damping ~dt target t] is [t] [dt] seconds later,
 * pulled towards [target] by the spring (frequency 2 Hz and damping 1
 * by default) *)
(* (ix: the two were optional: 2 and 1) *)
val chase : frequency:float -> damping:float -> dt:float -> float -> t -> t

(* [smooth ~rate ~dt target x] is the simple way: it moves [x] closer to
 * [target] by 1 - e^(-rate dt) of the gap *)
val smooth : rate:float -> dt:float -> float -> float -> float
