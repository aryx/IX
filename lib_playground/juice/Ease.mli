(* Easing: how a thing gets from here to there, not only where it goes.

   A curve is a function from [0, 1] to numbers, which is 0 at 0 and 1
   at 1: it maps the time gone, as a fraction, to the way gone, as a
   fraction. The
   straight line, [linear], is what a program does when nobody thought
   about it -- a box that starts at full speed and stops dead, like a
   machine. Everything else is a choice of how it starts and stops:

      way                                  way
     1 |              ___.               1 |        .----___
       |          _--'                     |     .-'
       |       _-'                         |   .'
       |    _-'   linear: a machine        |  /    out_quad: fast, then
       | _-'                               | /     slowing, as a thrown
     0 +'------------------> time        0 +/-----------------> time
       0                     1             0                     1

   Disney's animators called it "slow in and slow out" (Thomas and
   Johnston, The Illusion of Life, 1981): nothing that weighs anything
   starts or stops instantly, so a drawing that does looks wrong before
   you can say why. Robert Penner wrote the curves down as equations for
   Flash (2002), with the names everyone still uses; every tween library
   since (jQuery's, CSS's, Unity's DOTween, Godot's Tween) copies them.

   Each of Penner's families comes in three: [in] (it starts slow, and
   is a curve of its own), [out] (it ends slow) and [in_out] (both).
   Only the [in] one needs
   writing. The [out] one is the [in] one run backwards -- turned half a
   turn around the middle of the square:

     out f t = 1 - f (1 - t)

   and the [in_out] one is the [in] one squeezed into the first half,
   followed by the [out] one squeezed into the second. So here each
   family is its [in] curve, and [out] and [in_out] are two functions
   that apply to any curve, including one you write yourself.

   The families, as their [in] curves:

     quad     t^2                  the gentlest
     cubic    t^3                  more marked
     sine     1 - cos (t pi/2)     a quarter of a cosine: the softest
     back     (s+1) t^3 - s t^2    goes back a little before going
     elastic  a sine, growing      a spring let go (the other way:
                                   wobbles and settles)
     bounce   a ball's bounces     backwards: they grow

   There is also [smoothstep], 3t^2 - 2t^3 (Perlin's, used in shaders),
   which is close to [in_out cubic] but gentler.

   Worked example (checked by the tests). At t = 0.5, [quad] is 0.25:
   a quarter of the way at half the time; [out quad] is 0.75. The [s]
   of [back] is Penner's 1.70158, a number that looks arbitrary and is
   not: it is the one that makes [out back] overshoot by exactly 10% --
   up to 1.1, at t = 0.58, then back to 1. A button that pops in with it
   grows 10% too big and settles, which reads as "alive"; with [s] = 0
   it is just [cubic].

   Honest about scale: these are the curves of a tween, which covers the
   same distance in the same time whatever happens. A thing that must react
   while it moves (follow a moving target, be pushed) needs a state
   stepped every frame -- a spring -- not a curve. *)
(* ix: copied from libs/juice/Ease.mli in the author's playground *)

(* a curve, from [0, 1] (time) to how far along (0 at 0, 1 at 1; [back]
 * and [elastic] go outside [0, 1] in between) *)
type t = float -> float

val linear : t

(* the families, as their [in] curves *)
val quad : t
val cubic : t
val sine : t
val back : t
val elastic : t
val bounce : t

val smoothstep : t

(* [out f] is [f] run backwards, which ends slow where [f] starts slow;
 * [out (out f)] is [f] again *)
val out : t -> t

(* [in_out f] is [f] on the first half and [out f] on the second *)
val in_out : t -> t

(* every curve, by its usual name ("in_quad", "out_quad", "in_out_quad",
 * ..., "linear", "smoothstep"), for a demo or a menu *)
val all : (string * t) list
