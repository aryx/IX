(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Monster_ai.mli *)

open Model
open Edict

type range = Melee_range | Near | Mid | Far

let mclass (e : t) : mclass =
  match e.mclass with
  | Some c -> c
  | None -> failwith "Monster_ai: not a monster"

let range (w : world) (e : t) (who : who) : range =
  let r = length (sub (eye w (Ent e)) (eye w who)) in
  if r < 120. then Melee_range
  else if r < 500. then Near
  else if r < 1000. then Mid
  else Far

let visible (w : world) (e : t) (who : who) : bool =
  let t = Physics.traceline w (eye w (Ent e)) (eye w who) false (Ent e) in
  t.fraction = 1.

let infront (w : world) (e : t) (who : who) : bool =
  let o, _, _ = where w who in
  let a = e.yaw *. Float.pi /. 180. in
  let forward = { x = Float.cos a; y = Float.sin a; z = 0. } in
  dot (normalize (sub o e.origin)) forward > 0.3

let seq (e : t) : seq = List.assoc e.seq (mclass e).seqs

(* a monster's frame: shown, the next one's think set, then what it
 * does (which may start another sequence) *)
let rec think (w : world) (e : t) : unit =
  let s = seq e in
  let i = e.step in
  e.frame <- s.frames.(i);
  e.nextthink <- time w +. 0.1;
  if i + 1 < Array.length s.acts then e.step <- i + 1
  else if s.next = "" then e.nextthink <- 0. (* the last frame, kept *)
  else begin
    e.seq <- s.next;
    e.step <- 0
  end;
  List.iter (act w e) s.acts.(i)

and start (w : world) (e : t) (name : string) : unit =
  e.seq <- name;
  e.step <- 0;
  think w e

(* (the sequence after this frame: QuakeC's self.think = th_run) *)
and next (e : t) (name : string) : unit =
  e.seq <- name;
  e.step <- 0

and face (w : world) (e : t) : unit =
  let o, _, _ = where w e.enemy in
  e.ideal_yaw <- vectoyaw (sub o e.origin);
  Physics.change_yaw e

and hunt_target (w : world) (e : t) : unit =
  let o, _, _ = where w e.enemy in
  e.ideal_yaw <- vectoyaw (sub o e.origin);
  next e (mclass e).run;
  e.nextthink <- time w +. 0.1;
  e.attack_finished <- time w +. 1.

and found_target (w : world) (e : t) : unit =
  if same e.enemy The_player then begin
    w.sight_entity <- Some e;
    w.sight_time <- time w
  end;
  let sights = (mclass e).sight in
  if sights <> [] then begin
    let k = int_of_float (random w *. float (List.length sights)) in
    sound w (Some e.origin)
      (List.nth sights (min k (List.length sights - 1)))
      1.
  end;
  hunt_target w e

(* FindTarget: the player, or the monster that saw it a tenth of a
 * second ago, checked as the player would be; the enemy then the
 * player. A monster that saw the player has show_hostile: those near
 * it wake even behind it, as near the player that shot *)
and find_target (w : world) (e : t) : bool =
  let c = w.client in
  let client, hostile =
    match w.sight_entity with
    | Some s when w.sight_time >= time w -. 0.1 && s != e && not s.removed ->
        (* (its show_hostile is FoundTarget's second ahead, as its
         * attack_finished: that one kept, not another field) *)
        (Ent s, s.attack_finished >= time w)
    | _ -> (The_player, c.show_hostile >= time w)
  in
  if c.phealth <= 0. || same e.enemy The_player then false
  else begin
    let r = range w e client in
    let ok =
      r <> Far && visible w e client
      &&
      match r with
      | Near -> hostile || infront w e client
      | Mid -> infront w e client
      | _ -> true
    in
    if ok then begin
      e.enemy <- The_player;
      found_target w e
    end;
    ok
  end

(* ai_run *)
and run (w : world) (e : t) (dist : float) : unit =
  let c = mclass e in
  if not (alive w e.enemy) then begin
    e.enemy <- Nobody;
    next e c.stand
  end
  else begin
    let seen = visible w e e.enemy in
    if seen then begin
      e.search_time <- time w +. 5.;
      e.seen_for <- e.seen_for + 1
    end
    else e.seen_for <- 0;
    if not (seen && c.check_attack w e) then
      (* (ai=ways, the player unseen: the playground's way to it) *)
      match
        if w.ways && (not seen) && same e.enemy The_player then
          Ways.direction w e
        else None
      with
      | Some yaw ->
          if not (Physics.step_direction w e yaw dist) then
            Physics.move_to_goal w e dist
      | None -> Physics.move_to_goal w e dist
  end

and act (w : world) (e : t) (a : act) : unit =
  let c = mclass e in
  match a with
  | Nothing | Refire _ -> ()
  | Stand | Walk _ -> ignore (find_target w e)
  | Run d -> run w e d
  | Face -> face w e
  | Charge d ->
      face w e;
      ignore (Physics.walk_move w e e.yaw d)
  | Back d | Pain_back d -> ignore (Physics.walk_move w e (e.yaw +. 180.) d)
  | Pain_forward d -> ignore (Physics.walk_move w e e.yaw d)
  | Fire | Leap -> c.fire w e
  | Melee -> c.bite w e
  | Drop ->
      e.solid <- false;
      Items.drop_backpack w e
  | Landed name -> if e.onground then next e name
  | Noise (sfx, chance) ->
      if random w < chance then sound w (Some e.origin) sfx 2.
