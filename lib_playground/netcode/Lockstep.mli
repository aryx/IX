(* Lockstep: send the inputs, simulate everywhere.

   This is the oldest way to play a game on several computers (Doom,
   1993; Age of Empires, 1997), and the one Elm's architecture is shaped
   for. A
   game's model is a function of its inputs: the first model, then each
   tick's inputs folded through update. So nobody sends the game --
   every peer computes it, from the same first model and the same
   inputs, and the peers only exchange their inputs: a few bytes a
   tick, whatever the size of the world (1,500 archers on a 28.8k
   modem).

       tick:      0    1    2    3    4    5
       peer A:    -    -    -    a3   a4   a5    each peer simulates tick
       peer B:    -    -    -    b3   b4   b5    n only once it has every
                  \___________/                  player's input for n
                   delay = 3: known by all
                   in advance (no input)

   **Input delay.** Waiting for the other peer's input of *this* tick
   would stall every frame (a packet takes time), so an input read at
   tick t applies at tick t + delay: it is sent at once, and has
   [delay] ticks to arrive before anyone needs it. The first [delay]
   ticks have no input, for everybody. The game answers the keys
   [delay] frames late, for every player, always. That is the price,
   which strategy games never notice and fighting games refuse (they
   use rollback, plan_networking_teaching.md phase 4).
   With a delay of 3 (50 ms at 60 ticks a second), a network faster
   than that one way never stalls. On a slower one the game waits,
   which is a *stall*, and the slowest peer sets everybody's pace.

   **No delay at all** is how a first network game is written (the
   author's tronscroll, 1997: send my state, then block until the
   answer comes, every frame): each tick waits for the others' input
   of that same tick, so every tick costs a trip across the network,
   and the frame rate is capped by it -- at 100 ms, about 8 ticks a
   second. A delay of 0 does exactly that: my input of the tick is sent
   first, and then the tick waits. Input delay is the fix: you pay the
   trip once, not every tick.

   The inputs travel as Inputs.mli says: each packet carries every
   input not yet acknowledged, so a lost packet costs nothing, and the
   checksums of the models, so that a desync is caught.

   Worked example (checked by the tests, with Sim_net as the network):
   two and three peers play 1,000 ticks each, their inputs drawn from a
   seed, under latency, jitter, 10% loss and duplication. Every peer
   computes the same model at every tick, the model of the same inputs
   applied on one machine. With a delay of 3, 30 ms of latency never
   stalls. 100 ms (6 frames) stalls about every other frame: 600 ticks
   take some 1,230 frames, so the game runs at half speed, with 3 ticks
   of delay for 6 frames of travel. With no delay, 100 ticks take some
   700 frames, 7 frames a tick, which is 1997's frame rate. A game whose
   update reads something only one peer has (a disagreement injected at
   tick 500) is caught at the first checksum after it.

   References: Paul Bettner and Mark Terrano, "1500 Archers on a 28.8:
   Network Programming in Age of Empires and Beyond" (GDC 2001); John
   Carmack's Doom (1993) network code, peer-to-peer lockstep over IPX;
   Glenn Fiedler, "Deterministic Lockstep" (gafferongames.com, 2014). *)

(* ix: copied from libs/networking/netcode/Lockstep.mli in the author's
 * playground *)

type t

(* peer [me] of [players] (numbered 0 to players - 1), whose inputs are
 * applied [delay] ticks after they are read *)
val create : me:int -> players:int -> delay:int -> t

(* the next tick to simulate (0 at the start) *)
val tick : t -> int

(* [step peer mine]: if every player's input for the next tick is
 * known, returns that tick's inputs, by player, schedules [mine] (read
 * now) for [delay] ticks later, and counts the tick done. Returns None
 * if an input is missing: that is a stall, and you try again next
 * frame. *)
val step : t -> string -> string array option

(* the packet to send to every other peer, this frame *)
val packet : t -> string

(* takes a packet from another peer; garbage, or a packet about another
 * game, is dropped *)
val receive : t -> string -> unit

(* records the checksum of my model after [tick] (the game computes it
 * with Checksum.of_model). It is sent in my next packets and compared
 * with theirs. *)
val checksum : t -> tick:int -> int32 -> unit

(* the first disagreement seen: the tick, and the peer whose checksum
 * differed from mine *)
val desync : t -> (int * int) option

type stats = { stalls : int; dropped : int; inputs_sent : int }

val stats : t -> stats
