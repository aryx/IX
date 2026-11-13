(* Multiplayer: a game for several players, on one computer or several.

   Evan's playground has a [computer]: your keyboard, your mouse. A
   game for two needs one more idea, the *player*: the players hold
   everyone's input, where [computer] holds only yours. So a multiplayer
   game's [update] gets the list of players, each with their keyboard,
   and never reads the computer's:

     let update computer players model =
       let pilot n = (List.nth players n).keyboard in
       { model with wedge = fly (pilot 0) model.wedge; needle = fly (pilot 1) model.needle }

     let app = Multiplayer.game ~players:2 view update initial_model

   The same game then runs in several ways, chosen by a flag
   (Playground.flags), without a line of it changing:

   - [net=local] (the default): both players are on one keyboard, as in
     Spacewar! in 1962. Player 0 has the arrows (and space, enter,
     shift), and player 1 has w, a, s, d, and q for its space;
   - [net=simulate]: two computers in one window, side by side. Each
     peer has its own model, and their inputs go through a fake network
     (Sim_net.mli) with [latency=] and [loss=] (milliseconds, percent;
     also [jitter=], [delay=], [seed=]). Keys change them while it
     runs: [ and ] change the latency, - and = the loss. The game
     keeps agreeing with itself under any network; the network only
     changes how late the keys answer, and whether the game stalls.
     Each half shows what that computer shows, and the checksums say
     whether the two games still agree (Checksum.mli);
   - [net=host] and [net=join]: two real computers, over UDP (natively
     only: Udp.mli), for a program granted the network. Such a program
     passes [~network:caps], from its Cap.main (only the network one of
     those capabilities is used) (plan_caps.md). Without it, these two
     modes say so on the screen, and the program's type says it can't
     reach the network. The host is player 0 and waits on port 7777
     ([port=]), on this computer only unless given [bind=0.0.0.0] (a
     LAN). The other one joins, [net=join host=192.168.1.12], and is
     player 1. Each plays with its arrows (and w, a, s, d, for a game
     with two sticks, TinyCyberSled). There is no handshake: the host
     plays its first [delay] ticks and stalls until the first inputs
     arrive;
   - [net=relay] ([host=], [port=] 8765): through a relay server
     (networking/relay/, Relay.mli), which every player connects to and
     which copies each one's packets to the others. It is the way for a
     browser to play (a web page can't listen, nor use UDP; it has
     WebSocket), and for players behind home routers. The relay numbers
     the players as they come, so a native program and a browser can
     play the same game together. (ix: this mode is not here; it gives
     an error on the screen.)

   There are four netcodes (ix: only the first three), chosen by the
   flag [netcode=] (and, in net=simulate, by the key n, which starts
   the game again with the next one, to feel the difference at the same
   latency):

   - [lockstep] (the default, Lockstep.mli): every player's input is
     applied [delay] ticks after it is read (3), on every peer, which
     waits for the late ones. The input is a byte: the arrows, space,
     enter and shift, a bit each, and a second byte for w, a, s and d
     when one of them is held (the other letters don't travel). The
     keys answer late, and a slow network slows the game;
   - [rollback] (Rollback.mli): my keys are applied at once, and the
     others' keys are guessed. When their real keys arrive, the game is
     played again from the tick where a guess was wrong. The game runs
     at full speed, with the other player snapping now and then;
   - [1997]: lockstep with no delay, which is how a first network game
     is written (send, then wait for the answer, every tick). It costs
     a trip across the network per tick, and the frame rate is capped
     by it; it is kept to be felt (TinyTronscroll's original did
     exactly this);
   - [server] (in net=simulate only, so far): a server owns the game
     (Snapshot.mli), and it is shown in the middle. The clients send
     their keys, predict their own game at once, and are corrected by
     its snapshots, 20 a second (Prediction.mli); they run a few ticks
     ahead of the server, and the mispredictions are counted. No desync
     is possible, because there is one game. The other players are
     shown predicted, not interpolated (Interpolation.mli needs the game
     to say what to draw from the past, which is a hook to come).

   Either way, the peers exchange only their inputs. It works only if
   [update] is *deterministic*: the same inputs give the same model, on
   every computer. So the [computer] it gets is cleaned of what differs
   between computers: it has no keyboard and no mouse (they are in the
   players), a fixed screen (1000 x 1000, whatever the window's size),
   the time counted in ticks (1/60 s each, never the clock), and the
   flags. Randomness must come from a seed in the model
   (Playground.random), never from Random.

   A player's [pressed] is the keys that went down this tick (their
   rising edge, which is what Scene2d.pressed gives a one-player game),
   computed from the inputs themselves, so every peer agrees on it.

   Two questions are open, and said so:
   - what a peer shows while it waits for a late input (here, the last
     model, frozen: a stall);
   - how a game's seed is shared (here, the same flags for both halves;
     over a real network, the host picks it and sends it first). *)

(* ix: copied from playground/apis/Multiplayer.mli in the author's
 * playground, with its optional arguments made required (network: None
 * for a program not granted it; split: false). The network capability
 * is one that can fork too (Transport.mli), and there is no
 * netcode=server nor net=relay.
 *
 * On mini-9pi the network is the UDP of /net (Udp, in
 * lib_networking/tcp). A host there waits on all its addresses,
 * whatever bind= says, and a board has its address by itself
 * (kernels/9pi/conf/boot.rc says which). On two boards joined by a
 * cable, here are the flags, quoted for rc:
 *
 *     tronscroll 'net=host'
 *     tronscroll 'net=join' 'host=192.168.9.1'
 *
 * A checksum is the sum of Marshal's bytes, which is the same on two
 * programs only when the same compiler built them. So a game between
 * OCaml's program on Linux and mini-ml's program on a board plays, but
 * says DESYNC. *)

type player = {
  id : int; (* 0 to players - 1 *)
  keyboard : Playground.keyboard; (* the keys held this tick *)
  pressed : Playground.keyboard; (* the keys that went down this tick *)
}

type 'model state

(* In [game ~players view update model], [view computer n model] draws
 * what player n sees (the real computer: its screen, its time), and
 * [update computer players model] is one tick, with everyone's input *)
(* With [split], in net=local, each player sees their own view, side by
 * side (a split screen); by default, only player 0's view is shown, for
 * a game whose screen is the same for everyone *)
val game :
  network:< Cap.network ; Cap.fork ; .. > option ->
  split:bool ->
  players:int ->
  (Playground.computer -> int -> 'model -> Playground.shape list) ->
  (Playground.computer -> player list -> 'model -> 'model) ->
  'model ->
  ('model state Playground.game, Playground.msg) Playground.app

(* the pieces of [game] that don't draw, for Multiplayer3d.mli, which
 * draws the same modes in 3D *)

(* the state before the first frame, which reads the flags *)
val initial : 'model -> 'model state

(* [update_state network ~players update] runs one frame of the mode the
 * flags chose (the game's ticks, the network's packets). [network] is
 * how a transport is opened: the function that [granted] returns, or
 * None. *)
val granted : < Cap.network ; Cap.fork ; .. > option -> (Transport.role -> (Transport.t, string) result) option

val update_state :
  (Transport.role -> (Transport.t, string) result) option ->
  players:int ->
  (Playground.computer -> player list -> 'model -> 'model) ->
  Playground.computer ->
  'model state ->
  'model state

(* what a mode shows:
 * - whose game is on each screen, with a label (net=simulate's
 *   "computer 0: tick ...");
 * - a background behind several screens;
 * - whether the screens are the columns of net=simulate (rather than a
 *   split screen);
 * - the network's lines of status, as 2D shapes at the bottom of a
 *   1000 x 1000 screen (y -440 to -470) *)
type 'model screen = { player : int; model : 'model; label : string option }

type 'model layout = {
  screens : 'model screen list;
  background : Playground.color option;
  columns : bool;
  status : Playground.shape list;
}

val layout : split:bool -> players:int -> 'model state -> 'model layout
