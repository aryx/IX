(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Weapons.mli *)

open World

(* p_pspr.h's: where a weapon is held (its top), where it goes down to,
 * how fast *)
let weapontop = 32.
let weaponbottom = 128.
let lowerspeed = 6.
let raisespeed = 6.
let meleerange = 64.

(* the attack key this tic (the command's) *)
let attacking = ref false

let ammo_of (p : player) (w : Info.weapon) : int =
  match (Info.weaponinfo w).ammo with
  | None -> 1
  | Some Info.Clip -> p.clips
  | Some Info.Shell -> p.shells

(* P_CheckAmmo: enough to fire, else the best weapon left asked for
 * (the shotgun, the pistol, the chainsaw, the fist) *)
let check_ammo (p : player) : bool =
  if ammo_of p p.readyweapon > 0 then true
  else begin
    let has (w : Info.weapon) : bool =
      List.mem w p.weapons && ammo_of p w > 0
    in
    let best =
      if has Info.Shotgun then Info.Shotgun
      else if has Info.Pistol then Info.Pistol
      else if has Info.Chainsaw then Info.Chainsaw
      else Info.Fist
    in
    p.pendingweapon <- Some best;
    false
  end

let use_ammo (p : player) : unit =
  match (Info.weaponinfo p.readyweapon).ammo with
  | Some Info.Clip -> p.clips <- p.clips - 1
  | Some Info.Shell -> p.shells <- p.shells - 1
  | None -> ()

(* P_SetPsprite: a state of the hand, its action, on through those of
 * no tics *)
let rec set_psprite (t : t) (sp : psprite) (name : string) : unit =
  match Info.state name with
  | None -> sp.pstate <- None
  | Some st -> (
      sp.pstate <- Some st;
      sp.ptics <- st.tics;
      act t sp st.action;
      match sp.pstate with
      | Some cur when cur == st && sp.ptics = 0 -> set_psprite t sp st.next
      | _ -> ())

(* P_BringUpWeapon: the pending weapon, from below *)
and bring_up (t : t) : unit =
  let p = t.player in
  let w = match p.pendingweapon with Some w -> w | None -> p.readyweapon in
  if w = Info.Chainsaw then start_sound t None "sawup";
  p.readyweapon <- w;
  p.pendingweapon <- None;
  p.weapon_sp.sy <- weaponbottom;
  set_psprite t p.weapon_sp (Info.weaponinfo w).upstate

(* P_FireWeapon *)
and fire (t : t) : unit =
  let p = t.player in
  if check_ammo p then begin
    set_psprite t p.weapon_sp (Info.weaponinfo p.readyweapon).atkstate;
    Enemy.noise_alert t
  end

(* the player's shots: from 36 up (its middle and 8), as Inter's *)
and shootz (p : player) : float = p.z +. (height /. 2.) +. 8.

(* P_BulletSlope: the aim, or a 32nd of a turn to the left, the right *)
and bullet_slope (t : t) : float =
  let p = t.player in
  let aim (a : float) : float * Things.target =
    Inter.aim t Things.The_player p.x p.y (shootz p) a (16. *. 64.)
  in
  let slope, target = aim p.angle in
  if target <> Things.Nobody then slope
  else
    let slope, target = aim (p.angle +. (pi /. 32.)) in
    if target <> Things.Nobody then slope
    else fst (aim (p.angle -. (pi /. 32.)))

(* P_GunShot: 5, 10 or 15; spread unless the first of a series *)
and gun_shot (t : t) (slope : float) (accurate : bool) : unit =
  let p = t.player in
  let damage = 5 * ((Info.p_random () mod 3) + 1) in
  let a =
    if accurate then p.angle
    else p.angle +. (float (Info.p_random2 ()) *. 2. *. pi /. 16384.)
  in
  Inter.line_attack t Things.The_player p.x p.y (shootz p) a (32. *. 64.) slope
    damage

(* the fist and the chainsaw: a line of 64, turning to what they hit *)
and melee (t : t) (damage : int) (range : float) : Things.target =
  let p = t.player in
  let a = p.angle +. (float (Info.p_random2 ()) *. 2. *. pi /. 16384.) in
  let slope, target =
    Inter.aim t Things.The_player p.x p.y (shootz p) a range
  in
  Inter.line_attack t Things.The_player p.x p.y (shootz p) a range slope damage;
  (match target with
  | Things.Thing m -> p.angle <- Float.atan2 (m.my -. p.y) (m.mx -. p.x)
  | _ -> ());
  target

and act (t : t) (sp : psprite) (a : Info.action) : unit =
  let p = t.player in
  let wi = Info.weaponinfo p.readyweapon in
  match a with
  | Info.Weapon_ready ->
      (match sp.pstate with
      | Some st when st.sname = "SAW" -> start_sound t None "sawidl"
      | _ -> ());
      if p.pendingweapon <> None || p.health <= 0 then
        set_psprite t sp wi.downstate
      else if !attacking then begin
        p.attackdown <- true;
        fire t
      end
      else begin
        p.attackdown <- false;
        (* (the weapon bobbing as the player walks) *)
        let angle = 2. *. pi *. float (128 * t.tic) /. 8192. in
        sp.sx <- 1. +. (p.bob *. Float.cos angle);
        sp.sy <- weapontop +. (p.bob *. Float.abs (Float.sin angle))
      end
  | Info.Lower ->
      sp.sy <- sp.sy +. lowerspeed;
      if sp.sy >= weaponbottom then
        if p.health <= 0 then begin
          sp.sy <- weaponbottom;
          sp.pstate <- None
        end
        else bring_up t
  | Info.Raise ->
      sp.sy <- sp.sy -. raisespeed;
      if sp.sy <= weapontop then begin
        sp.sy <- weapontop;
        set_psprite t sp wi.readystate
      end
  | Info.Refire ->
      if !attacking && p.pendingweapon = None && p.health > 0 then begin
        p.refire <- p.refire + 1;
        fire t
      end
      else begin
        p.refire <- 0;
        ignore (check_ammo p)
      end
  | Info.Punch ->
      let damage = ((Info.p_random () mod 10) + 1) lsl 1 in
      if melee t damage meleerange <> Things.Nobody then
        start_sound t None "punch"
  | Info.Saw ->
      let damage = 2 * ((Info.p_random () mod 10) + 1) in
      if melee t damage (meleerange +. 1.) <> Things.Nobody then
        start_sound t None "sawhit"
      else start_sound t None "sawful"
  | Info.Fire_pistol ->
      start_sound t None "pistol";
      use_ammo p;
      set_psprite t p.flash_sp wi.flashstate;
      gun_shot t (bullet_slope t) (p.refire = 0)
  | Info.Fire_shotgun ->
      start_sound t None "shotgn";
      use_ammo p;
      set_psprite t p.flash_sp wi.flashstate;
      let slope = bullet_slope t in
      for _i = 1 to 7 do
        gun_shot t slope false
      done
  | Info.Light0 -> p.extralight <- 0
  | Info.Light1 -> p.extralight <- 1
  | Info.Light2 -> p.extralight <- 2
  | _ -> ()

let setup (t : t) : unit =
  let p = t.player in
  p.weapon_sp.pstate <- None;
  p.flash_sp.pstate <- None;
  p.pendingweapon <- Some p.readyweapon;
  bring_up t

(* P_MovePsprites: each psprite's tics, the flash where the weapon is *)
let tic (t : t) (attack : bool) (change : Info.weapon option) : unit =
  let p = t.player in
  attacking := attack;
  (match change with
  | Some w when List.mem w p.weapons && w <> p.readyweapon && p.health > 0 ->
      p.pendingweapon <- Some w
  | _ -> ());
  List.iter
    (fun (sp : psprite) ->
      match sp.pstate with
      | Some st when sp.ptics <> -1 ->
          sp.ptics <- sp.ptics - 1;
          if sp.ptics <= 0 then set_psprite t sp st.next
      | _ -> ())
    [ p.weapon_sp; p.flash_sp ];
  p.flash_sp.sx <- p.weapon_sp.sx;
  p.flash_sp.sy <- p.weapon_sp.sy
