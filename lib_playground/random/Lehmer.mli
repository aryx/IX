(* Lehmer: random numbers from a formula, the same ones every time.

   A computer can't flip a coin, so games use a *pseudo*-random
   generator: a number, the *seed*, and a formula giving the next one
   from it. The sequence looks random, and is entirely determined by the
   first seed -- which is the point here: a game that keeps its seed in
   its model replays the same way (golden frames, a bug reproduced), and
   two computers given the same seed at the start draw the same numbers
   (lockstep networking, plan_networking_teaching.md). OCaml's global
   Random is the opposite: a hidden state, shared by the whole program,
   and seeded from the clock by Random.self_init.

   The formula is D. H. Lehmer's (1949, for ENIAC), multiply and take
   the remainder:

       seed' = 16807 * seed  mod  (2^31 - 1)

   with the constants Park and Miller called the *minimal standard*
   (1988): 2^31 - 1 = 2147483647 is prime and 16807 = 7^5 makes every
   seed from 1 to 2^31 - 2 come back only after all the others -- a
   period of 2,147,483,646. Seed 0 is never used (it would stay 0).

   The subtle part is computing it at all. 16807 * seed needs 46 bits;
   native OCaml's ints have 63, but in a browser (js_of_ocaml) they have
   32, and the product overflows: the same program would draw other
   numbers on the web. Schrage's trick (1979) never goes past 31 bits:
   write m = a q + r, with q = m / a = 127773 and r = m mod a = 2836
   (r < q is what makes it work), then

       a * seed  mod  m  =  a * (seed mod q)  -  r * (seed / q)
                            (plus m if that is negative)

   each product below 2^31. So both platforms give the same sequence,
   bit for bit.

   Worked example (checked by the tests): from seed 1, the sequence
   starts 16807, 282475249, 1622650073, 984943658, 1144108930, and the
   10,000th is 1043618065 -- the check value Park and Miller give,
   so that an implementation can test itself.

   One more trap, and a real one: the generator only multiplies, so
   seed 2's sequence is exactly twice seed 1's (mod m), forever, and
   seeds 1, 2, 3 -- what people type -- start nearly the same game (from
   1, the first draw is 16807 / 2^31 = 0.000008; from 2, 0.000016). So
   a seed given by a person is *scrambled* first: [scramble] hashes it
   with MurmurHash3's finalizer (Austin Appleby, 2008), three xor-shifts
   and two multiplications that make every bit of the result depend on
   every bit of the number, on Int32 so that it wraps the same way
   everywhere. Seeds 1 and 2 then start unrelated games.

   What is ours: ix's smallest machine is narrower still than a
   browser. On the 32-bit ARM of the first Raspberry Pi an OCaml int
   has 31 bits, its sign among them, and a seed, which goes up to
   2^31 - 2, does not fit in one; Schrage's products would not
   either. So here the state is a float, which holds every integer
   up to 2^53 exactly, the product 16807 * seed (under 2^45) is
   computed whole, and the remainder is taken: the same numbers as
   above on every machine, Schrage's trick left in Lehmer.ml as the
   old way.

   Where it stands: Playground's seed is this module's ([random]
   there gives a number and the next seed, for the model to keep).
   The random numbers of cryptography are another thing entirely:
   those must not be predictable, and this one must be.

   terminology:
   This kind of generator is a *linear congruential generator*, LCG:
   next = (a * seed + c) mod m. Lehmer's has c = 0 (a
   *multiplicative* one), which is why 0 is stuck and why the seeds
   are multiples of each other. C's rand() was for decades an LCG
   with a power of two for m, whose low bits repeat with a short
   period -- the last one simply alternates -- the reason old
   advice says never to take rand() % 2. BigBangWorm has one in a
   line, with the constants of the C standard's example (1103515245
   and 12345), where a line is all a worm's food needs.

   modern:
   Not a good generator by today's standards (xorshift, Marsaglia
   2003, and PCG, O'Neill 2014, are faster and pass statistical tests
   it fails), and never for cryptography; enough for a game, and the
   simplest one that is portable.

   References: D. H. Lehmer, "Mathematical methods in large-scale
   computing units" (1949); Stephen K. Park and Keith W. Miller, "Random
   Number Generators: Good Ones Are Hard to Find", Communications of the
   ACM 31(10) (1988); Linus Schrage, "A More Portable Fortran
   Random Number Generator", ACM TOMS 5(2) (1979); Knuth, The Art of
   Computer Programming, volume 2, chapter 3. *)
(* ix: the author's playground's libs/random/Lehmer.mli (docs/plans/plan_playground.md) *)

(* between 1 and 2^31 - 2 *)
(* ix: abstract (the playground's says "private int", which mini-ml has not;
 * and it is a float here, for a machine of 32 bits: Lehmer.ml says) *)
type t

(* any int made a valid seed, as is (0 and the multiples of 2^31 - 1
 * become 1): for the worked example, and a seed already drawn *)
val of_int : int -> t

(* a seed from a number a person gave (seed=1): hashed first, so that
 * neighbour numbers give unrelated sequences *)
val scramble : int -> t

(* the next seed: 16807 * seed mod (2^31 - 1), by Schrage's trick *)
val next : t -> t

(* the seed as a number in [0, 1) *)
val to_unit : t -> float

(* claude: the generator as a state that moves on at each draw, the
 * shape of the stdlib's Random.State, for code drawing many numbers
 * (a search's playouts, a network's first weights: libs/ai). Unlike
 * Random.State, the same numbers on every OCaml: Random's algorithm
 * changed in OCaml 5 (LXM), and a test's seed chosen on 4.14 drew
 * other games and other weights on 5.2. *)
type state

(* from a seed, scrambled (a person's 1 and 2 unrelated) *)
val make : int -> state

(* a number in [0, n), n > 0 *)
val int : state -> int -> int

(* a number in [0, x) *)
val float : state -> float -> float
