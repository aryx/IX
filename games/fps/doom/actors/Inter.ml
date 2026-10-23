(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Inter.mli *)

open World

let where (t : t) (who : Things.target) : float * float * float * float =
  match who with
  | Things.Thing m -> (m.mx, m.my, m.mz, Things.height m)
  | _ -> (t.player.x, t.player.y, t.player.z, height)

(*****************************************************************************)
(* Damage *)
(*****************************************************************************)

(* P_KillMobj: no more shootable, a corpse; gibbed if far below 0 *)
let kill (t : t) (m : Things.mobj) : unit =
  m.flags <-
    m.flags
    land lnot (Info.shootable lor Info.nogravity)
    lor Info.corpse lor Info.dropoff;
  if m.flags land Info.countkill <> 0 then t.kills <- t.kills + 1;
  match m.actor with
  | None -> ()
  | Some i -> (
      let st =
        if m.health < -i.spawnhealth && i.xdeathstate <> "" then i.xdeathstate
        else i.deathstate
      in
      if Mobj.set_state t m st then
        m.stics <- max 1 (m.stics - (Info.p_random () land 3));
      (* (what it held: a zombieman's clip, a shotgun guy's shotgun) *)
      match i.doomednum with
      | 3004 -> Mobj.spawn_item t 2007 m.mx m.my
      | 9 -> Mobj.spawn_item t 2001 m.mx m.my
      | _ -> ())

(* the player hurt: the armor's share, the red, the pain *)
let damage_player (t : t) (source : Things.target) (amount : int) : unit =
  let p = t.player in
  let saved = if p.armor > 100 then amount / 2 else amount / 3 in
  let saved = min saved p.armor in
  p.armor <- p.armor - saved;
  let amount = amount - saved in
  p.health <- max 0 (p.health - amount);
  (match source with Things.Thing m -> p.attacker <- Some m | _ -> ());
  p.damagecount <- min 100 (p.damagecount + amount);
  if p.health = 0 then begin
    (* (P_KillMobj's for a player: the dead player's view, Play's) *)
    start_sound t None (if amount > 50 then "pdiehi" else "pldeth")
  end
    (* (its pain sound and picture, A_Pain of S_PLAY_PAIN: the face's
     * only, here the sound) *)
  else if Info.p_random () < 255 then start_sound t None "plpain"

let damage (t : t) (target : Things.target) ((ix, iy) : float * float)
    (source : Things.target) (amount : int) : unit =
  match target with
  | Things.Nobody -> ()
  | Things.The_player ->
      if t.player.health > 0 then damage_player t source amount
  | Things.Thing m -> (
      match m.actor with
      | Some i when m.flags land Info.shootable <> 0 && m.health > 0 ->
          (* (pushed away from the blow, the lighter the further; not by
           * the chainsaw's, which holds the victim) *)
          let saw =
            source = Things.The_player && t.player.readyweapon = Info.Chainsaw
          in
          if not saw then begin
            let a = Float.atan2 (m.my -. iy) (m.mx -. ix) in
            let thrust = float amount *. 100. /. 8. /. float i.mass in
            m.momx <- m.momx +. (thrust *. Float.cos a);
            m.momy <- m.momy +. (thrust *. Float.sin a)
          end;
          m.health <- m.health - amount;
          if m.health <= 0 then kill t m
          else begin
            if Info.p_random () < i.painchance then begin
              m.flags <- m.flags lor Info.justhit;
              ignore (Mobj.set_state t m i.painstate)
            end;
            m.reactiontime <- 0;
            (* (it turns on who hurt it, for a while: BASETHRESHOLD) *)
            let self =
              match source with Things.Thing s -> s == m | _ -> false
            in
            if m.threshold = 0 && source <> Things.Nobody && not self then begin
              m.target <- source;
              m.threshold <- 100;
              let standing =
                match m.state with
                | Some st -> st.sname = i.spawnstate
                | None -> false
              in
              if standing && i.seestate <> "" then
                ignore (Mobj.set_state t m i.seestate)
            end
          end
      | _ -> ())

(*****************************************************************************)
(* Shots *)
(*****************************************************************************)

(* the slopes of the view: 100 rows up and down of a focal length of
 * 160 (id's topslope, bottomslope) *)
let view_slope = 100. /. 160.

(* the target an intercept is, if a shot can hit it *)
let target_of (i : Collision.intercept) : Things.target =
  match i with
  | Collision.Thing_hit (_, m) -> Things.Thing m
  | Collision.Player_hit _ -> Things.The_player
  | Collision.Line _ -> Things.Nobody

let aim (t : t) (shooter : Things.target) (x : float) (y : float) (z : float)
    (angle : float) (range : float) : float * Things.target =
  let x2 = x +. (range *. View.fcos angle)
  and y2 = y +. (range *. View.fsin angle) in
  let top = ref view_slope and bottom = ref (-.view_slope) in
  let rec go (l : Collision.intercept list) : float * Things.target =
    match l with
    | [] -> (0., Things.Nobody)
    | Collision.Line (f, line) :: rest -> (
        let d = f *. range in
        match Collision.opening t line with
        | Some (ob, ot) when ob < ot && d > 0. ->
            top := Float.min !top ((ot -. z) /. d);
            bottom := Float.max !bottom ((ob -. z) /. d);
            if !top <= !bottom then (0., Things.Nobody) else go rest
        | Some _ when d <= 0. -> go rest
        | _ -> (0., Things.Nobody))
    | i :: rest ->
        let d = Float.max 1. (Collision.fraction i *. range) in
        let _, _, tz, th = where t (target_of i) in
        let ttop = (tz +. th -. z) /. d and tbottom = (tz -. z) /. d in
        if ttop < !bottom || tbottom > !top then go rest
        else
          let ttop = Float.min ttop !top
          and tbottom = Float.max tbottom !bottom in
          ((ttop +. tbottom) /. 2., target_of i)
  in
  go (Collision.intercepts t shooter x y x2 y2)

let line_attack (t : t) (shooter : Things.target) (x : float) (y : float)
    (z : float) (angle : float) (range : float) (slope : float) (amount : int) :
    unit =
  let x2 = x +. (range *. View.fcos angle)
  and y2 = y +. (range *. View.fsin angle) in
  let at (f : float) (back : float) : float * float * float =
    let f = f -. (back /. range) in
    (x +. (f *. (x2 -. x)), y +. (f *. (y2 -. y)), z +. (slope *. f *. range))
  in
  let rec go (l : Collision.intercept list) : unit =
    match l with
    | [] -> ()
    | Collision.Line (f, line) :: rest -> (
        let d = f *. range in
        let hz = z +. (slope *. d) in
        match Collision.opening t line with
        | Some (ob, ot) when hz > ob && hz < ot -> go rest
        | _ ->
            let px, py, pz = at f 4. in
            (* (into the sky: no puff) *)
            let side = Level.point_on_line_side x y line in
            let sky =
              match Level.line_sector t.level line side with
              | Some s -> s.ceilingpic = t.textures.sky_flat && pz > s.ceiling
              | None -> false
            in
            if not sky then Mobj.spawn_puff t px py pz)
    | i :: rest ->
        let d = Float.max 1. (Collision.fraction i *. range) in
        let target = target_of i in
        let _, _, tz, th = where t target in
        if (tz +. th -. z) /. d < slope || (tz -. z) /. d > slope then go rest
        else begin
          let px, py, pz = at (Collision.fraction i) 10. in
          let noblood =
            match target with
            | Things.Thing m -> m.flags land Info.noblood <> 0
            | _ -> false
          in
          if noblood then Mobj.spawn_puff t px py pz
          else Mobj.spawn_blood t px py pz amount;
          damage t target (x, y) shooter amount
        end
  in
  go (Collision.intercepts t shooter x y x2 y2)

(* PIT_RadiusAttack: the distance the box's, not the centre's *)
let radius_attack (t : t) (spot : Things.mobj) (source : Things.target)
    (amount : int) : unit =
  let hurt (who : Things.target) (r : float) : unit =
    let x, y, z, h = where t who in
    let d =
      Float.max (Float.abs (x -. spot.mx)) (Float.abs (y -. spot.my)) -. r
    in
    let d = Float.max 0. d in
    if
      d < float amount
      && Collision.check_sight t spot.mx spot.my (spot.mz +. 8.) x y z h
    then damage t who (spot.mx, spot.my) source (amount - int_of_float d)
  in
  List.iter
    (fun (m : Things.mobj) ->
      if m.alive && m != spot && m.flags land Info.shootable <> 0 then
        hurt (Things.Thing m) (Things.radius m))
    t.things;
  hurt Things.The_player radius

let missile_hit (t : t) (m : Things.mobj) (target : Things.target) : unit =
  match m.actor with
  | Some i ->
      damage t target (m.mx, m.my) m.target
        (((Info.p_random () mod 8) + 1) * i.damage)
  | None -> ()

(*****************************************************************************)
(* Items *)
(*****************************************************************************)

(* P_TouchSpecialThing, P_GiveAmmo, P_GiveBody, P_GiveArmor,
 * P_GiveWeapon: what an item gives, its message and sound, if it can be
 * taken (a medikit not at full health) *)
let give (t : t) (n : int) : (string * string) option =
  let p = t.player in
  let body (k : int) (most : int) (msg : string) : (string * string) option =
    if p.health >= most then None
    else begin
      p.health <- min most (p.health + k);
      Some (msg, "itemup")
    end
  in
  let clips (k : int) (msg : string) : (string * string) option =
    if p.clips >= 200 then None
    else begin
      p.clips <- min 200 (p.clips + k);
      Some (msg, "itemup")
    end
  in
  let shells (k : int) (msg : string) : (string * string) option =
    if p.shells >= 50 then None
    else begin
      p.shells <- min 50 (p.shells + k);
      Some (msg, "itemup")
    end
  in
  let weapon (w : Info.weapon) (msg : string) : (string * string) option =
    if not (List.mem w p.weapons) then begin
      p.weapons <- w :: p.weapons;
      p.pendingweapon <- Some w
    end;
    if w = Info.Shotgun then p.shells <- min 50 (p.shells + 8);
    Some (msg, "wpnup")
  in
  match n with
  | 2007 -> clips 10 "Picked up a clip."
  | 2048 -> clips 50 "Picked up a box of bullets."
  | 2008 -> shells 4 "Picked up 4 shotgun shells."
  | 2049 -> shells 20 "Picked up a box of shotgun shells."
  | 2011 -> body 10 100 "Picked up a stimpack."
  | 2012 -> body 25 100 "Picked up a medikit."
  | 2014 ->
      p.health <- min 200 (p.health + 1);
      Some ("Picked up a health bonus.", "itemup")
  | 2013 ->
      p.health <- min 200 (p.health + 100);
      Some ("Supercharge!", "getpow")
  | 2015 ->
      p.armor <- min 200 (p.armor + 1);
      Some ("Picked up an armor bonus.", "itemup")
  | 2018 ->
      if p.armor >= 100 then None
      else begin
        p.armor <- 100;
        Some ("Picked up the armor.", "itemup")
      end
  | 2019 ->
      if p.armor >= 200 then None
      else begin
        p.armor <- 200;
        Some ("Picked up the MegaArmor!", "itemup")
      end
  | 2001 -> weapon Info.Shotgun "You got the shotgun!"
  | 2005 -> weapon Info.Chainsaw "A chainsaw!  Find some meat!"
  | 5 | 6 | 13 | 38 | 39 | 40 ->
      p.keys <- n :: p.keys;
      let colour =
        match n with 5 | 40 -> "blue" | 6 | 39 -> "yellow" | _ -> "red"
      in
      Some
        ( Printf.sprintf "Picked up a %s %s." colour
            (if n >= 38 then "skull key" else "keycard"),
          "itemup" )
  | _ -> None

let touch_specials (t : t) : unit =
  let p = t.player in
  if p.health > 0 then
    List.iter
      (fun (m : Things.mobj) ->
        let r = radius +. m.kind.radius in
        if
          m.alive && m.actor = None
          && Float.abs (m.mx -. p.x) < r
          && Float.abs (m.my -. p.y) < r
          && m.mz <= p.z +. height
          && p.z <= m.mz +. 8. +. m.kind.height
        then
          match give t m.kind.doomednum with
          | Some (msg, sfx) ->
              Mobj.remove t m;
              say t msg;
              p.bonuscount <- p.bonuscount + 6;
              start_sound t None sfx
          | None -> ())
      t.things
