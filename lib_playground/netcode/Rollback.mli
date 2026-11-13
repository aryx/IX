(* Rollback: guess the others' keys, and fix it afterwards.

   Lockstep's input delay (Lockstep.mli) is what a fighting game can't
   have: 50 ms between your thumb and your fighter is a different game.
   Rollback (GGPO, Tony Cannon, 2006) applies your input *at once*, and
   *predicts* the others' inputs: it guesses that they are still doing
   what they did last tick, which is right most of the time, since keys
   stay held for many ticks. When
   a real input arrives and contradicts the guess, the peer goes back
   and plays the ticks again, with the truth:

     tick:          10    11    12    13     B's real input for 11
     A computed:    m10   m11'  m12'  m13'   arrives at tick 13, and
                           |                 differs from the guess
     A redoes:             m11   m12   m13   m10 restored, 11 to 13
                                             replayed -- in one frame

   The costs move from *delay* to *CPU and correctness*. Up to a round
   trip's worth of ticks are replayed every frame, and the other player
   visibly *snaps* when a guess was wrong, which players forgive far
   more than lag on their own hands.

   Saving the models to go back to is the part that is hard in C++
   (GGPO asks the game to serialize its whole state, every frame) and
   free here: Elm's models are immutable values, so saving one is
   keeping it, in a list, with its unchanged parts shared. The whole
   technique is then the bookkeeping below:

   - [saved] keeps, for each tick not yet *confirmed*, the model before
     it and the inputs it was played with (some of them guessed);
   - each frame, the peer goes back to the earliest saved tick whose
     guesses now differ from real inputs: its model is restored, and
     every tick since is replayed (with the guesses refreshed from what
     is known now);
   - a tick is confirmed once all its inputs are real (and it was played
     with them). Only then is its model final, the same on every peer,
     and handed to [on_confirm], for the checksums of desync detection
     (a guessed model would differ between peers, and mean nothing);
   - at most [max_ahead] ticks are guessed in a row (8, GGPO's usual
     cap). Beyond that, the peer stalls as lockstep would, so that a
     peer that has heard nothing for a second doesn't replay a second of
     game every frame.

   The inputs travel as Inputs.mli says, exactly as lockstep's.

   Worked example (checked by the tests, with Sim_net as the network):
   two and three peers play 1,000 ticks, under latency, jitter, 10% loss
   and duplication. Every confirmed model is the model of the same
   inputs applied on one machine: in the end, the guesses never show.
   At 100 ms, lockstep (with a delay of 3) plays 600 ticks in some 1,230
   frames, at half speed. Rollback plays them in 606, and pays in
   replays instead: the other player's keys change 30 times, so there
   are 30 wrong guesses, each found a network trip late (6 frames); 183
   ticks are replayed, at most 7 at once.

   References: Tony Cannon, GGPO (2006; open-sourced, MIT, 2019), and
   his "Fight the Lag!" (Game Developer, 2012); David Jefferson, "Virtual
   Time" (ACM TOPLAS, 1985) -- Time Warp, the same idea for parallel
   simulations, twenty years before. *)

(* ix: copied from libs/networking/netcode/Rollback.mli in the author's
 * playground. Its optional arguments are required here. *)

type 'model t

(* peer [me] of [players]. [update inputs model] plays one tick (the
 * inputs are by player). [on_confirm tick model] is called once per
 * tick, in order, when its model is final. [delay] is an input delay
 * added to the prediction, as some games do (1 or 2 ticks give fewer
 * rollbacks; 0 is none). [max_ahead] is the number of ticks played on
 * guesses before a stall (8 is the playground's own). ix: both are
 * optional in the playground. *)
val create :
  me:int ->
  players:int ->
  delay:int ->
  max_ahead:int ->
  update:(string array -> 'model -> 'model) ->
  on_confirm:(int -> 'model -> unit) ->
  'model ->
  'model t

(* plays one frame: it takes my input, read now, rolls back if a guess
 * was wrong, and plays the next tick (with guesses if needed), unless
 * [max_ahead] ticks are guessed already, which is a stall *)
val step : 'model t -> string -> unit

(* rolls back if a guess was wrong and makes the confirmations, without
 * playing a new tick (for a game that has ended, and for the tests) *)
val settle : 'model t -> unit

(* the model to show: the latest one, which may rest on guesses *)
val model : 'model t -> 'model

(* the next tick to play, and the first tick not yet confirmed *)
val tick : 'model t -> int
val confirmed : 'model t -> int

val packet : 'model t -> string
val receive : 'model t -> string -> unit

(* records my model's checksum after a confirmed tick (called in
 * on_confirm) *)
val checksum : 'model t -> tick:int -> int32 -> unit
val desync : 'model t -> (int * int) option

type stats = {
  stalls : int;
  rollbacks : int; (* times a guess was wrong *)
  replayed : int; (* ticks played again because of them *)
  deepest : int; (* the most ticks replayed at once *)
  dropped : int;
}

val stats : 'model t -> stats
