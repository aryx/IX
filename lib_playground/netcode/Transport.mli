(* Transport: where a peer's packets go, whatever carries them.

   Lockstep (Lockstep.mli) makes packets and reads packets; it doesn't
   care how they travel. Sim_net carries them inside one program, and
   networking/unix/Udp.mli carries them between two computers; a
   browser would need WebSockets and a relay
   (plan_networking_teaching.md, phase 5). This module is what they
   have in common, for Multiplayer.mli: send to the other side, take
   what arrived, and say how it goes. It is a record of functions, so
   that the pure libraries can use a transport that a platform opens
   (the sockets belong to the operating system).

   (ix: the one transport here is UDP, the Udp of lib_networking/tcp.
   It is a socket on Linux and a conversation of /net/udp on Plan 9,
   the two behind one interface, so [connect] calls it and no platform
   installs anything. The host can be given only by its address.)

   Over UDP, two players play, one on each side. Through a relay
   (Relay.mli), any number can play: the relay forwards each packet to
   all the others, and says which player you are, which you learn once
   connected. *)

(* ix: copied from libs/networking/protocols/Transport.mli in the author's
 * playground. There is no relay and no TLS. A program calls connect; no
 * platform installs it. *)

type t = {
  send : string -> unit; (* a packet to the other side (dropped if it isn't known yet) *)
  receive : unit -> string list; (* the packets arrived since last time, never waiting *)
  status : unit -> string; (* for the screen: "hosting on 127.0.0.1:7777, waiting for a player" *)
  player : unit -> int option; (* which player I am, once known *)
}

(* how to find the other side *)
type role =
  | Host of { bind : string; port : int } (* wait for a player on this address and port *)
  | Join of { host : string; port : int } (* play with the host there *)
  | Relay of { host : string; port : int } (* play through the relay there: not in ix, so an Error *)

(* opens a transport over UDP, or returns an Error saying why it could
 * not (a port taken, no network, a relay asked for). It takes Cap.fork
 * because on Plan 9 the transport is read by a process of its own
 * (Udp.mli). *)
val connect : < Cap.network ; Cap.fork ; .. > -> role -> (t, string) result
