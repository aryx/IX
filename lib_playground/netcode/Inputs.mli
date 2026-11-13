(* Inputs: every player's input, tick by tick, as the peers exchange them.

   This is what lockstep (Lockstep.mli) and rollback (Rollback.mli)
   share. Each peer knows some inputs: its own, as soon as they are
   read, and the others', as their packets arrive. This table holds what
   it knows, by (tick, player). The two architectures differ only in
   what they do with a tick whose inputs aren't all known yet: lockstep
   waits, and rollback guesses.

   **Loss, without stalling forever.** Each packet carries every input
   of mine the other side hasn't acknowledged yet, and acknowledges
   what I have of theirs (the highest tick up to which I have them
   all). A lost packet costs nothing: the next one carries the same
   inputs again. That is reliability built over an unreliable network.
   It is TCP's idea in a few lines, without TCP's wait for the lost
   packet (the inputs after it are carried too).

   **Desyncs.** Determinism can break (a clock read, an unseeded
   Random, notes_networking.md section 8), and then the games drift
   apart silently. So each peer sends the checksum of its model
   (Checksum.mli) at the ticks the game chooses (every second), and the
   first one that differs is reported, with its tick and its peer.

   The packet, in Wire's bytes (Wire.mli):

     01                     the type: inputs
     from                   varint, the sender
     n, (player, ack)*n     what I have of each other player: all up to
                            tick ack (zigzag: -1 is nothing yet)
     first, count, input*   my inputs for the ticks first, first+1, ...
     0 | 1 tick hi lo       my latest checksum, if any (two u16s)

   The worked examples are those of the two architectures, in their
   tests. *)

(* ix: copied from libs/networking/netcode/Inputs.mli in the author's
 * playground *)

type t

(* the table of peer [me] of [players] (numbered 0 to players - 1). The
 * inputs of the first [delay] ticks are known by all, and are empty (no
 * key held). *)
val create : me:int -> players:int -> delay:int -> t

val me : t -> int
val players : t -> int

(* adds my input for a tick, read now *)
val add_mine : t -> tick:int -> string -> unit

(* a player's input for a tick, if it is known *)
val find : t -> tick:int -> int -> string option

(* the tick up to which every input of [player] is known (-1 when none
 * is known yet) *)
val known_upto : t -> int -> int

(* the packet to send to every other peer, this frame *)
val packet : t -> string

(* takes a packet from another peer; garbage, or a packet of my own, is
 * dropped *)
val receive : t -> string -> unit

(* records the checksum of my model after [tick]. It is sent in my next
 * packets and compared with theirs. *)
val checksum : t -> tick:int -> int32 -> unit

(* the first disagreement seen: the tick, and the peer whose checksum
 * differed from mine *)
val desync : t -> (int * int) option

(* the packets dropped, and the inputs sent (a resent input is counted
 * again) *)
val dropped : t -> int
val inputs_sent : t -> int
