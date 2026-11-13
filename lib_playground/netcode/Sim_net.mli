(* Sim_net: a network in one program, as bad as you want, from a seed.

   The most useful module of networking/ never touches a socket
   (notes_networking.md section 3). Every peer runs in one process; a
   packet sent is put in flight with the time it will arrive, and a
   peer receives the packets whose time has come. Between the two, the
   module does what the Internet does to packets, each effect drawn
   from a seed:

     send at t  --->  lost?  (probability [loss])
                      late:  t + latency + a uniform [0, jitter)
                      twice? (probability [duplication]; the copy has
                              its own delay)
     receive at now: the packets arrived by [now], in arrival order

   Reordering is not a knob of its own: it is what jitter does to
   packets sent close together: when two are sent 1/60 s apart with 50
   ms of jitter, the second often overtakes the first, as on a real
   network (the tests count how often).

   It is three tools in one. For teaching, you play both sides in one
   window and see what the other player sees, with keys adding latency
   or loss. For testing, a protocol runs in make test, without sockets,
   ports or flakiness: "after 1000 ticks, every peer's model is the
   same, under any latency and loss" is a unit test (phase 2). For
   debugging, a desync that happens once an hour on a LAN happens every
   time, with a seed to paste in a bug report. The same seed gives the
   same packets lost and the same delays: the network is deterministic
   like the games.

   Packets are bytes (strings): a protocol has to serialize its
   messages (Wire.mli), as it will on a real socket.

   Worked example (checked by the tests): 10,000 packets with a loss of
   10% lose 1,000 give or take 90 (three standard deviations, sqrt
   (10000 x 0.1 x 0.9) = 30); with 30 ms of latency and 20 ms of jitter,
   none arrives before 30 ms, none after 50 ms, and they take 40 ms on
   average; with no jitter, none is reordered.

   References: Gabriel Gambetta, "Fast-Paced Multiplayer" (2014), whose
   demos have the latency sliders this module is the keyboard version
   of; Linux's netem (2005), the same knobs for real sockets (tc qdisc
   add dev lo root netem delay 30ms 20ms loss 10%). *)

(* ix: copied from libs/networking/netcode/Sim_net.mli in the author's
 * playground *)

type config = {
  latency : float; (* seconds, one way *)
  jitter : float; (* seconds: an extra delay, uniform in [0, jitter) *)
  loss : float; (* probability, 0 to 1 *)
  duplication : float; (* probability, 0 to 1 *)
}

(* no latency, no loss: a packet arrives at the time it is sent *)
val perfect : config

type t

(* a network between any peers (numbered by the caller), whose
 * randomness comes from [seed] *)
val create : seed:int -> config -> t

(* the knobs, which can be changed while it runs (by the debug keys) *)
val config : t -> config
val set_config : t -> config -> unit

(* [send net ~now ~src ~dst bytes] puts a packet in flight *)
val send : t -> now:float -> src:int -> dst:int -> string -> unit

(* takes out of the network the packets for [dst] that arrived by
 * [now], as (sender, bytes), in the order they arrived *)
val receive : t -> now:float -> int -> (int * string) list

type stats = {
  sent : int;
  lost : int;
  duplicated : int;
  delivered : int;
  reordered : int; (* arrived after a packet sent later between the same two peers *)
}

val stats : t -> stats
