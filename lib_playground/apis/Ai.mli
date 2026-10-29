(* Game AI for the playground: what an enemy wants, in one line.

   Five families, in the order a game meets them: steering (a
   character that moves by wanting to go somewhere), ways through a
   map, an opponent for a turn game, what a character is doing (a mode
   and what changes it), and a bot -- a mind that plays through the
   same inputs as the player. Underneath each is a module of [ai/],
   where the algorithm is written out with its diagram and its
   references; up here there are only verbs and values, and no search,
   queue, tree or seed is ever named.

   In ix, the ways through a map and a bot's aim only, what mini-doom's
   monsters ask (the ix: line below). *)

(* ix: the author's playground's playground/apis/Ai.mli; its ways through a map, and aim_error of its bots; not its steering, its opponent, its state machine, nor the rest of its bots (lib_playground/ai/README.md); its optional arguments said, the defaults the comments give: diagonal false, settle 30 *)

open Playground

(*****************************************************************************)
(* {1 Ways through a map} *)
(*****************************************************************************)
(* A way from one tile to another, over whatever grid the game already
   has -- a Tilemap, an array of arrays, a function. The game says
   which tiles can be walked and nothing else: no graph to build, no
   frontier, no queue (Pathfind.mli has all three written out).

     let step = Ai.way ~walkable:(free level) ~diagonal:false monster.cell door

   Tiles are (column, row) in the game's own numbering, and nothing
   here knows where a tile is on screen. *)

(* [way ~walkable from to_]: the shortest way, [from] excluded and
 * [to_] included, or [] if there is none (or [to_] cannot be walked).
 * Four neighbours; [diagonal] adds the corners, at their honest price
 * of sqrt 2 steps. *)
val way : walkable:(int * int -> bool) -> diagonal:bool -> int * int -> int * int -> (int * int) list

(* [way_over ~cost from to_]: the same, where some ground is slower
 * than other ground -- [cost] is what entering a tile is worth, at
 * least 1 (a road 1, mud 3), and infinity for a tile that cannot be
 * entered at all. The cheapest way is not the shortest one: it goes
 * around the swamp. *)
val way_over : cost:(int * int -> number) -> diagonal:bool -> int * int -> int * int -> (int * int) list

(* Where fifty monsters all want the same door, fifty searches are
   forty-nine too many: one search from the door outward gives every
   tile the way to go, and each monster only reads its own tile. Build
   it when the map changes, not when a monster moves. *)
type flow

val flow : walkable:(int * int -> bool) -> diagonal:bool -> int * int -> flow

(* [next_step f tile]: the neighbour to walk to, None on the goal
 * itself and on a tile the goal cannot be reached from *)
val next_step : flow -> int * int -> (int * int) option

(* [steps_to_go f tile]: what it costs from there, for drawing the
 * field as colours (and None off it) *)
val steps_to_go : flow -> int * int -> number option

(*****************************************************************************)
(* {1 A bot's aim} *)
(*****************************************************************************)

(* [aim_error ~spread ~seen_for ~seed ()]: how far off its aim is, in
 * the game's own unit: [spread] when a target appears, halving every
 * [settle] frames (30) it stays in sight. A smooth wobble of
 * [seen_for] and [seed], not a random number, so a game replays the
 * same. *)
val aim_error : spread:number -> settle:number -> seen_for:int -> seed:int -> unit -> number
