(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Specials.mli *)

open World

(*****************************************************************************)
(* The lines *)
(*****************************************************************************)

(* a key's thing numbers: a card and a skull of each colour *)
let has_key (t : t) (colour : string) : bool =
  let cards = match colour with "blue" -> [ 5; 40 ] | "yellow" -> [ 6; 39 ] | _ -> [ 13; 38 ] in
  List.exists (fun (k : int) -> List.mem k t.player.keys) cards

(* EV_DoDoor, EV_VerticalDoor: [manual] the line's back sector, else
 * the line's tagged sectors *)
let do_door (t : t) (l : Level.line) (kind : door_kind) (speed : float) (manual : bool) : unit =
  let start (s : Level.sector) : unit =
    match busy t s with
    | Some { what = Door d; _ } when manual ->
        (* (used again: it turns back) *)
        if kind = Raise then d.ddir <- (if d.ddir = -1 then 1 else -1)
    | Some _ -> ()
    | None ->
        let dir = if kind = Close then -1 else 1 in
        add t (Door { dsector = s; dkind = kind; ddir = dir; topheight = lowest_ceiling t s -. 4.; dspeed = speed; dcount = 0 }) in
  if manual then Option.iter start (Level.line_sector t.level l 1) else List.iter start (tagged t l.tag)

let do_plat (t : t) (l : Level.line) (speed : float) : unit =
  List.iter
    (fun (s : Level.sector) ->
      if busy t s = None then
        add t (Plat { psector = s; low = Float.min (lowest_floor t s) s.floor; high = s.floor; pspeed = speed; status = -1; pcount = 0 }))
    (tagged t l.tag)

let do_floor_lowest (t : t) (l : Level.line) : unit =
  List.iter
    (fun (s : Level.sector) -> if busy t s = None then add t (Floor { fsector = s; dest = lowest_floor t s; fspeed = 1.; fdir = -1 }))
    (tagged t l.tag)

(* P_ChangeSwitchTexture: the front side's SW1 made SW2; back after a
 * second when the switch can be used again *)
let switch (t : t) (l : Level.line) (again : bool) : unit =
  let side = t.level.sides.(l.front) in
  let turn (where : int) (get : Level.side -> int) (set : int -> unit) : unit =
    match Textures.switch_of t.textures (get side) with
    | Some other ->
        if again then add t (Button { bside = side; where; texture = get side; btimer = 35 });
        set other
    | None -> () in
  turn 0 (fun (s : Level.side) -> s.top) (fun (k : int) -> side.top <- k);
  turn 1 (fun (s : Level.side) -> s.middle) (fun (k : int) -> side.middle <- k);
  turn 2 (fun (s : Level.side) -> s.bottom) (fun (k : int) -> side.bottom <- k)

(* P_UseSpecialLine and P_CrossSpecialLine together: a line's special,
 * [used] or crossed; a W1 or S1 one is then no more. The doors' speed
 * is 2 a tic (VDOORSPEED), the blazing ones' 8; the lifts' 4 *)
let line_special (t : t) (l : Level.line) (used : bool) : unit =
  let once () : unit = l.special <- 0 in
  let locked (colour : string) (f : unit -> unit) : unit =
    if has_key t colour then f () else say t (Printf.sprintf "You need a %s key to open this door" colour) in
  match (used, l.special) with
  (* DR, D1: the door the line is on *)
  | true, 1 -> do_door t l Raise 2. true
  | true, 26 -> locked "blue" (fun () -> do_door t l Raise 2. true)
  | true, 27 -> locked "yellow" (fun () -> do_door t l Raise 2. true)
  | true, 28 -> locked "red" (fun () -> do_door t l Raise 2. true)
  | true, 117 -> do_door t l Raise 8. true
  | true, 31 -> do_door t l Open 2. true; once ()
  | true, 32 -> locked "blue" (fun () -> do_door t l Open 2. true; once ())
  | true, 33 -> locked "red" (fun () -> do_door t l Open 2. true; once ())
  | true, 34 -> locked "yellow" (fun () -> do_door t l Open 2. true; once ())
  | true, 118 -> do_door t l Open 8. true; once ()
  (* switches: S1 once, SR again *)
  | true, 103 -> do_door t l Open 2. false; switch t l false; once ()
  | true, 63 -> do_door t l Raise 2. false; switch t l true
  | true, 62 -> do_plat t l 4.; switch t l true
  | true, 21 -> do_plat t l 4.; switch t l false; once ()
  | true, 123 -> do_plat t l 8.; switch t l true
  | true, 23 -> do_floor_lowest t l; switch t l false; once ()
  | true, (11 | 51) -> switch t l false; t.exited <- true
  (* walked over: W1 once, WR again *)
  | false, 2 -> do_door t l Open 2. false; once ()
  | false, 3 -> do_door t l Close 2. false; once ()
  | false, 4 -> do_door t l Raise 2. false; once ()
  | false, 86 -> do_door t l Open 2. false
  | false, 90 -> do_door t l Raise 2. false
  | false, 10 -> do_plat t l 4.; once ()
  | false, 88 -> do_plat t l 4.
  | false, 120 -> do_plat t l 8.
  | false, 38 -> do_floor_lowest t l; once ()
  | false, (52 | 124) -> t.exited <- true
  | _ -> ()

(*****************************************************************************)
(* The thinkers *)
(*****************************************************************************)

type moved = Ok | Crushed | Pastdest

(* T_MovePlane: a sector's floor (or ceiling) [speed] toward [dest];
 * back where it was if the player is in the way *)
let move_plane (t : t) (s : Level.sector) (speed : float) (dest : float) (floor : bool) (dir : int) : moved =
  let get () : float = if floor then s.floor else s.ceiling in
  let set (v : float) : unit = if floor then s.floor <- v else s.ceiling <- v in
  let last = get () in
  let past = if dir < 0 then last -. speed < dest else last +. speed > dest in
  set (if past then dest else if dir < 0 then last -. speed else last +. speed);
  (* (a floor going down, a ceiling going up never crush) *)
  if (floor && dir > 0) || ((not floor) && dir < 0) then begin
    if not (Collision.change_sector t) then begin
      set last;
      ignore (Collision.change_sector t);
      Crushed
    end
    else if past then Pastdest
    else Ok
  end
  else begin
    ignore (Collision.change_sector t);
    if past then Pastdest else Ok
  end

let think (t : t) (th : thinker) : unit =
  match th.what with
  | Door d -> (
      match d.ddir with
      | 0 ->
          d.dcount <- d.dcount - 1;
          if d.dcount <= 0 then d.ddir <- -1
      | 1 -> (
          match move_plane t d.dsector d.dspeed d.topheight false 1 with
          | Pastdest -> if d.dkind = Raise then begin d.ddir <- 0; d.dcount <- 150 end else th.alive <- false
          | _ -> ())
      | _ -> (
          match move_plane t d.dsector d.dspeed d.dsector.floor false (-1) with
          | Pastdest -> th.alive <- false
          (* (the player under it: back up) *)
          | Crushed -> d.ddir <- 1
          | Ok -> ()))
  | Plat p -> (
      match p.status with
      | 1 -> (
          match move_plane t p.psector p.pspeed p.high true 1 with
          | Crushed -> p.pcount <- 105; p.status <- -1
          | Pastdest -> th.alive <- false
          | Ok -> ())
      | -1 -> ( match move_plane t p.psector p.pspeed p.low true (-1) with Pastdest -> p.pcount <- 105; p.status <- 0 | _ -> ())
      | _ ->
          p.pcount <- p.pcount - 1;
          if p.pcount <= 0 then p.status <- (if p.psector.floor = p.low then 1 else -1))
  | Floor f -> ( match move_plane t f.fsector f.fspeed f.dest true f.fdir with Pastdest -> th.alive <- false | _ -> ())
  | Light l -> (
      let s = l.lsector in
      match l.lkind with
      | Flash ->
          l.lcount <- l.lcount - 1;
          if l.lcount <= 0 then
            if s.light = l.maxlight then begin s.light <- l.minlight; l.lcount <- (random () land l.darktime) + 1 end
            else begin s.light <- l.maxlight; l.lcount <- (random () land l.brighttime) + 1 end
      | Strobe ->
          l.lcount <- l.lcount - 1;
          if l.lcount <= 0 then
            if s.light = l.minlight then begin s.light <- l.maxlight; l.lcount <- l.brighttime end
            else begin s.light <- l.minlight; l.lcount <- l.darktime end
      | Glow ->
          if l.gdir < 0 then begin
            s.light <- s.light - 8;
            if s.light <= l.minlight then begin s.light <- s.light + 8; l.gdir <- 1 end
          end
          else begin
            s.light <- s.light + 8;
            if s.light >= l.maxlight then begin s.light <- s.light - 8; l.gdir <- -1 end
          end
      | Flicker ->
          l.lcount <- l.lcount - 1;
          if l.lcount <= 0 then begin
            let amount = (random () land 3) * 16 in
            s.light <- (if s.light - amount < l.minlight then l.minlight else l.maxlight - amount);
            l.lcount <- 4
          end)
  | Button b ->
      b.btimer <- b.btimer - 1;
      if b.btimer <= 0 then begin
        (match b.where with 0 -> b.bside.top <- b.texture | 1 -> b.bside.middle <- b.texture | _ -> b.bside.bottom <- b.texture);
        th.alive <- false
      end

(* P_SpawnSpecials: the sectors' lights *)
let spawn_lights (t : t) : unit =
  Array.iter
    (fun (s : Level.sector) ->
      let light (kind : light_kind) (minl : int) (maxl : int) (dark : int) (bright : int) (count : int) : unit =
        add t (Light { lsector = s; lkind = kind; minlight = minl; maxlight = maxl; darktime = dark; brighttime = bright; lcount = count; gdir = -1 }) in
      let lowest = min_light t s s.light in
      (* (P_SpawnStrobeFlash: no darker neighbour, then black) *)
      let strobe (dark : int) (sync : bool) : unit =
        light Strobe (if lowest = s.light then 0 else lowest) s.light dark 5 (if sync then 1 else (random () land 7) + 1) in
      match s.special with
      | 1 -> light Flash lowest s.light 7 64 ((random () land 64) + 1)
      | 2 | 4 -> strobe 15 false
      | 3 -> strobe 35 false
      | 8 -> light Glow lowest s.light 0 0 0
      | 12 -> strobe 35 true
      | 13 -> strobe 15 true
      | 17 -> light Flicker (lowest + 16) s.light 0 0 4
      | _ -> ())
    t.level.sectors
