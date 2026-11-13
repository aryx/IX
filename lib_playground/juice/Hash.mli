(* Random numbers that are the same every time: each one is a hash of a
   seed and a number.

   Juice wants randomness -- where a shake goes, which way a spark
   flies -- but not a random game: the same seed must give the same
   shake and the same sparks, in a replay, in a golden frame test, and
   in the browser as natively. So there is no global [Random], and no
   generator state hidden somewhere. There is only a function, from a
   seed and a point (a lattice point of the noise, the next draw of a
   burst) to a number in [-1, 1], which is unrelated to the numbers of
   its neighbours.

   It is Park and Miller's "minimal standard" generator (1988),
   x -> 16807 x mod (2^31 - 1). The hash takes a few steps of it from
   the seed and the point, and computes them by Schrage's method
   (1979), so that no product reaches 2^31:

     16807 x mod m  =  16807 (x mod q) - r (x / q)      (+ m if negative)
                       q = m / 16807 = 127773,  r = m mod 16807 = 2836

   That matters here: OCaml's ints have 63 bits natively and 32 in a
   browser (js_of_ocaml), and a hash whose products overflowed would
   give different numbers on the two, so a shake or a burst would differ
   on the web. A first version started the generator from the seed and
   the point and took three steps. Neighbouring points then came out
   correlated (-0.15), because the generator is linear; an xor of the
   high bits between the steps (x lxor (x lsr 13)) brings the
   correlation down to 0.002.

   Worked example (checked by the tests): [hash ~seed:1] is -0.1084 at
   0, 0.5113 at 1, and 0.5300 at 2.

   Honest about scale: the hash uses 20 bits of the point (it wraps
   after 1048576) and 10 bits of the seed (1024 seeds). It is a
   generator for effects, not for statistics or cards (Cards.mli has
   Microsoft's generator, because a deal number must reproduce
   Microsoft's deal exactly). *)
(* ix: copied from libs/juice/Hash.mli in the author's playground. It
 * computes on floats and Int32, for a machine whose ints have 31
 * bits. *)

(* [hash ~seed i] is a number in [-1, 1], the same for the same seed and
 * point, and unrelated to the numbers of its neighbours *)
val hash : seed:int -> int -> float

(* [unit ~seed i] is the same number, in [0, 1] *)
val unit : seed:int -> int -> float
