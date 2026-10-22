(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See World.mli *)

type player = {
  mutable x : float;
  mutable y : float;
  mutable z : float;
  mutable angle : float;
  mutable momx : float;
  mutable momy : float;
  mutable momz : float;
  mutable floorz : float;
  mutable ceilingz : float;
  mutable viewheight : float;
  mutable deltaviewheight : float;
  mutable viewz : float;
  mutable bob : float;
  mutable turnheld : int;
  mutable keys : int list;
}

(* a door: up to its top, then waiting, then down (dir 1, 0, -1) *)
type door_kind = Raise (* and close after *) | Open | Close

type door = {
  dsector : Level.sector;
  dkind : door_kind;
  mutable ddir : int;
  topheight : float;
  dspeed : float;
  mutable dcount : int;
}

(* a lift: down, waiting, up (status -1, 0, 1); done at its top *)
type plat = { psector : Level.sector; low : float; high : float; pspeed : float; mutable status : int; mutable pcount : int }

type floor_move = { fsector : Level.sector; dest : float; fspeed : float; fdir : int }

type light_kind = Flash | Strobe | Glow | Flicker

type light = {
  lsector : Level.sector;
  lkind : light_kind;
  minlight : int;
  maxlight : int;
  darktime : int;
  brighttime : int;
  mutable lcount : int;
  mutable gdir : int;
}

(* a switch that turns back: which of its side's textures, to what *)
type button = { bside : Level.side; where : int (* 0 top, 1 middle, 2 bottom *); texture : int; mutable btimer : int }

type thinker = { mutable alive : bool; what : what }
and what = Door of door | Plat of plat | Floor of floor_move | Light of light | Button of button

type t = {
  level : Level.t;
  textures : Textures.t;
  player : player;
  things : Things.mobj list;
  by_sector : Things.mobj list array; (* the things by their sectors' numbers *)
  mutable tic : int;
  mutable thinkers : thinker list;
  mutable message : string;
  mutable message_tics : int;
  mutable exited : bool;
  mutable secrets : int;
}

(* p_local.h and d_player.h's numbers *)
let radius = 16.
let height = 56.
let viewheight = 41.
let maxstep = 24.
let friction = 0.90625
let stopspeed = 1. /. 16.
let maxmove = 30.
let userange = 64.
let maxbob = 16.
let pi = 4. *. atan 1.

(* the lights' generator: Lehmer's, as the playground's; not id's table *)
let seed = ref 1
let random () : int = seed := (!seed * 16807) mod 2147483647; !seed land 255

let say (t : t) (msg : string) : unit = t.message <- msg; t.message_tics <- 4 * 35

(*****************************************************************************)
(* The sectors around *)
(*****************************************************************************)

let neighbours (t : t) (s : Level.sector) : Level.sector list =
  List.filter_map
    (fun (k : int) ->
      let l = t.level.lines.(k) in
      match (Level.line_sector t.level l 0, Level.line_sector t.level l 1) with
      | Some a, Some b -> if a == s then Some b else if b == s then Some a else None
      | _ -> None)
    s.lines

(* P_FindLowestCeilingSurrounding, P_FindLowestFloorSurrounding,
 * P_FindMinSurroundingLight *)
let lowest_ceiling (t : t) (s : Level.sector) : float = List.fold_left (fun (m : float) (n : Level.sector) -> Float.min m n.ceiling) 32767. (neighbours t s)
let lowest_floor (t : t) (s : Level.sector) : float = List.fold_left (fun (m : float) (n : Level.sector) -> Float.min m n.floor) s.floor (neighbours t s)
let min_light (t : t) (s : Level.sector) (max : int) : int = List.fold_left (fun (m : int) (n : Level.sector) -> min m n.light) max (neighbours t s)

let tagged (t : t) (tag : int) : Level.sector list = List.filter (fun (s : Level.sector) -> s.tag = tag) (Array.to_list t.level.sectors)

(* a sector already moving (id's specialdata) *)
let busy (t : t) (s : Level.sector) : thinker option =
  List.find_opt
    (fun (th : thinker) ->
      th.alive && match th.what with Door d -> d.dsector == s | Plat p -> p.psector == s | Floor f -> f.fsector == s | _ -> false)
    t.thinkers

let add (t : t) (w : what) : unit = t.thinkers <- t.thinkers @ [ { alive = true; what = w } ]
