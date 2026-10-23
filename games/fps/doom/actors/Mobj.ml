(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Mobj.mli *)

let act : (World.t -> Things.mobj -> Info.action -> unit) ref =
  ref (fun (_ : World.t) (_ : Things.mobj) (_ : Info.action) -> ())

let remove (t : World.t) (m : Things.mobj) : unit =
  m.alive <- false;
  let k = m.sector.index in
  t.by_sector.(k) <-
    List.filter (fun (o : Things.mobj) -> o != m) t.by_sector.(k)

(* P_SetMobjState: a state, its action, and on through the states of
 * no tics *)
let rec set_state (t : World.t) (m : Things.mobj) (name : string) : bool =
  match Info.state name with
  | None ->
      m.state <- None;
      remove t m;
      false
  | Some st ->
      m.state <- Some st;
      m.stics <- st.tics;
      !act t m st.action;
      if m.alive && m.stics = 0 then set_state t m st.next else m.alive

(* (a thing of no map: its kind, for drawing, made from its info) *)
let kind_of (i : Info.mobjinfo) : Things.info =
  {
    doomednum = i.doomednum;
    sprite = "";
    frames = [||];
    tics = 1;
    radius = i.radius;
    height = i.height;
    solid = false;
    hanging = false;
    monster = false;
  }

let add (t : World.t) (m : Things.mobj) : unit =
  t.things <- m :: t.things;
  t.by_sector.(m.sector.index) <- m :: t.by_sector.(m.sector.index)

let spawn (t : World.t) (i : Info.mobjinfo) (x : float) (y : float) (z : float)
    : Things.mobj =
  let s = Level.sector_at t.level x y in
  let m = Things.make (kind_of i) (Some i) x y z s in
  add t m;
  (* (the first state's action, as P_SpawnMobj does not: none has one) *)
  m

let spawn_item (t : World.t) (n : int) (x : float) (y : float) : unit =
  match Things.info n with
  | Some i ->
      let s = Level.sector_at t.level x y in
      add t (Things.make i None x y s.floor s)
  | None -> ()

(* P_SpawnPuff: up a little, its first tics random *)
let spawn_puff (t : World.t) (x : float) (y : float) (z : float) : unit =
  let z = z +. (float (Info.p_random2 ()) /. 64.) in
  let m = spawn t Info.puff x y z in
  m.momz <- 1.;
  m.stics <- max 1 (m.stics - (Info.p_random () land 3))

(* P_SpawnBlood: redder the more it hurt *)
let spawn_blood (t : World.t) (x : float) (y : float) (z : float) (damage : int)
    : unit =
  let z = z +. (float (Info.p_random2 ()) /. 64.) in
  let m = spawn t Info.blood x y z in
  m.momz <- 2.;
  m.stics <- max 1 (m.stics - (Info.p_random () land 3));
  if damage <= 12 && damage >= 9 then ignore (set_state t m "BLOOD2")
  else if damage < 9 then ignore (set_state t m "BLOOD3")

let explode_missile (t : World.t) (m : Things.mobj) : unit =
  m.momx <- 0.;
  m.momy <- 0.;
  m.momz <- 0.;
  match m.actor with
  | Some i ->
      if set_state t m i.deathstate then begin
        m.stics <- max 1 (m.stics - (Info.p_random () land 3));
        m.flags <- m.flags land lnot Info.missile;
        World.start_sound t (Some (m.mx, m.my)) i.deathsound
      end
  | None -> ()

(* P_XYMovement: by the momentum, in steps of half the most a step can
 * be when it is large; a missile stopped explodes (or hits); friction
 * for the others on the ground, a corpse sliding to a stop *)
let xy_movement (t : World.t) (hit : Things.mobj -> Things.target -> unit)
    (m : Things.mobj) : unit =
  let clamp (v : float) : float =
    Float.max (-.World.maxmove) (Float.min World.maxmove v)
  in
  m.momx <- clamp m.momx;
  m.momy <- clamp m.momy;
  let big =
    Float.abs m.momx > World.maxmove /. 2.
    || Float.abs m.momy > World.maxmove /. 2.
  in
  let steps = if big then 2 else 1 in
  let n = float steps in
  let stopped = ref false in
  for _i = 1 to steps do
    if not !stopped then begin
      let ok, pos =
        Collision.try_move_thing t m
          (m.mx +. (m.momx /. n))
          (m.my +. (m.momy /. n))
      in
      if not ok then begin
        stopped := true;
        if m.flags land Info.missile <> 0 then begin
          if pos.hit <> Things.Nobody then hit m pos.hit;
          explode_missile t m
        end
        else begin
          m.momx <- 0.;
          m.momy <- 0.
        end
      end
    end
  done;
  if m.flags land Info.missile = 0 && m.mz <= m.floorz then begin
    if Float.abs m.momx < World.stopspeed && Float.abs m.momy < World.stopspeed
    then begin
      m.momx <- 0.;
      m.momy <- 0.
    end
    else begin
      m.momx <- m.momx *. World.friction;
      m.momy <- m.momy *. World.friction
    end
  end

(* P_ZMovement: up or down by the momentum, gravity off the floor; a
 * missile that meets the floor or the ceiling explodes *)
let z_movement (t : World.t) (m : Things.mobj) : unit =
  m.mz <- m.mz +. m.momz;
  let missile = m.flags land Info.missile <> 0 in
  if m.mz <= m.floorz then begin
    m.mz <- m.floorz;
    if m.momz < 0. then m.momz <- 0.;
    if missile then explode_missile t m
  end
  else if m.flags land Info.nogravity = 0 then
    m.momz <- (if m.momz = 0. then -2. else m.momz -. 1.);
  if m.alive && m.mz +. Things.height m > m.ceilingz then begin
    if m.momz > 0. then m.momz <- 0.;
    m.mz <- m.ceilingz -. Things.height m;
    if missile then explode_missile t m
  end

let think (t : World.t) (hit : Things.mobj -> Things.target -> unit)
    (m : Things.mobj) : unit =
  if m.momx <> 0. || m.momy <> 0. then xy_movement t hit m;
  if m.alive && (m.mz <> m.floorz || m.momz <> 0.) then z_movement t m;
  if m.alive && m.stics <> -1 then begin
    m.stics <- m.stics - 1;
    if m.stics <= 0 then
      match m.state with
      | Some st -> ignore (set_state t m st.next)
      | None -> ()
  end
