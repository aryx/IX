(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Monsters.mli *)

open Model
open Edict

(* a model's frames as its QuakeC declares them: each run's name and
 * length, in order *)
let first_of (layout : (string * int) list) (name : string) : int =
  let rec go (l : (string * int) list) (k : int) : int =
    match l with
    | (n, len) :: rest -> if n = name then k else go rest (k + len)
    | [] -> failwith ("Monsters: no frames " ^ name)
  in
  go layout 0

(* [seq layout run acts next]: a sequence over the run's frames *)
let seq (layout : (string * int) list) (run : string) (acts : act list list)
    (next : string) : seq =
  let f = first_of layout run in
  {
    frames =
      Array.of_list (List.mapi (fun (i : int) (_ : act list) -> f + i) acts);
    acts = Array.of_list acts;
    next;
  }

let nothing (n : int) : act list list = List.init n (fun (_ : int) -> [])

(* the aim turned by the playground's error, with ai=ways (Ways) *)
let aimed (w : world) (e : t) (dir : vec) : vec =
  if not w.ways then dir
  else
    let a = Ways.aim_error e *. Float.pi /. 180. in
    let c = Float.cos a and s = Float.sin a in
    {
      dir with
      x = (c *. dir.x) -. (s *. dir.y);
      y = (s *. dir.x) +. (c *. dir.y);
    }

let range_and_shot (w : world) (e : t) : Monster_ai.range option =
  let t = Physics.traceline w (eye w (Ent e)) (eye w e.enemy) true (Ent e) in
  if same t.what e.enemy || t.fraction = 1. then
    Some (Monster_ai.range w e e.enemy)
  else None

(* the pain sequences, by the random number, and the sound *)
let pains (w : world) (e : t) (choices : (float * float * string * string) list)
    : unit =
  if e.pain_finished <= time w then begin
    let r = random w in
    match
      List.find_opt
        (fun ((p, _, _, _) : float * float * string * string) -> r < p)
        choices
    with
    | Some (_, pause, s, sfx) ->
        e.pain_finished <- time w +. pause;
        sound w (Some e.origin) sfx 1.;
        Monster_ai.start w e s
    | None -> ()
  end

(*****************************************************************************)
(* The soldier (grunt.qc) *)
(*****************************************************************************)

let soldier_layout =
  [
    ("stand", 8);
    ("death", 10);
    ("deathc", 11);
    ("load", 11);
    ("pain", 6);
    ("painb", 14);
    ("painc", 13);
    ("run", 8);
    ("shoot", 9);
    ("prowl", 24);
  ]

(* army_fire: behind where the player goes, 4 pellets *)
let army_fire (w : world) (e : t) : unit =
  Monster_ai.face w e;
  sound w (Some e.origin) "soldier/sattck1" 1.;
  let o, _, _ = where w e.enemy in
  let v =
    match e.enemy with
    | The_player -> w.play.body.velocity
    | Ent x -> x.velocity
    | Nobody -> zero
  in
  let dir = aimed w e (normalize (sub (sub o (scale 0.2 v)) e.origin)) in
  Combat.fire_bullets w (Ent e) (eye w (Ent e)) dir 4 (0.1, 0.1)

(* SoldierCheckAttack *)
let soldier_check (w : world) (e : t) : bool =
  match range_and_shot w e with
  | Some r when time w >= e.attack_finished ->
      let chance =
        match r with
        | Monster_ai.Melee_range -> 0.9
        | Monster_ai.Near -> 0.4
        | Monster_ai.Mid -> 0.05
        | Monster_ai.Far -> 0.
      in
      if random w < chance then begin
        Monster_ai.start w e "atk";
        e.attack_finished <- time w +. 1. +. random w;
        true
      end
      else false
  | _ -> false

let soldier : mclass =
  let s = seq soldier_layout in
  {
    mname = "monster_army";
    mmodel = "progs/soldier.mdl";
    head = "progs/h_guard.mdl";
    mhealth = 30.;
    mmins = { x = -16.; y = -16.; z = -24. };
    mmaxs = { x = 16.; y = 16.; z = 40. };
    gib_health = -35.;
    seqs =
      [
        ("stand", s "stand" (List.init 8 (fun (_ : int) -> [ Stand ])) "stand");
        ( "run",
          s "run"
            [
              [ Noise ("soldier/idle", 0.2); Run 11. ];
              [ Run 15. ];
              [ Run 10. ];
              [ Run 10. ];
              [ Run 8. ];
              [ Run 15. ];
              [ Run 10. ];
              [ Run 8. ];
            ]
            "run" );
        ( "atk",
          s "shoot"
            [
              [ Face ];
              [ Face ];
              [ Face ];
              [ Face ];
              [ Face; Fire ];
              [ Face ];
              [ Face ];
              [ Face ];
              [ Face ];
            ]
            "run" );
        ("pain", s "pain" (nothing 5 @ [ [ Pain_back 1. ] ]) "run");
        ( "painb",
          s "painb"
            ([ []; [ Pain_forward 13. ]; [ Pain_forward 9. ] ]
            @ nothing 8
            @ [ [ Pain_back 2. ]; []; [] ])
            "run" );
        ( "painc",
          s "painc"
            [
              [];
              [ Pain_back 1. ];
              [];
              [];
              [ Pain_forward 1. ];
              [ Pain_forward 1. ];
              [];
              [ Pain_back 1. ];
              [ Pain_forward 4. ];
              [ Pain_forward 3. ];
              [ Pain_forward 6. ];
              [ Pain_forward 8. ];
              [];
            ]
            "run" );
        ( "die",
          s "death"
            ([ [ Noise ("soldier/death1", 1.) ]; []; [ Drop ] ] @ nothing 7)
            "" );
        ( "cdie",
          s "deathc"
            ([
               [ Noise ("soldier/death1", 1.) ];
               [ Back 5. ];
               [ Drop; Back 4. ];
               [ Back 13. ];
               [ Back 3. ];
               [ Back 4. ];
             ]
            @ nothing 5)
            "" );
      ];
    stand = "stand";
    walk = "stand";
    run = "run";
    missile = "atk";
    melee = "";
    deaths = [ "die"; "cdie" ];
    sight = [ "soldier/sight1" ];
    pain =
      (fun (w : world) (e : t) (_ : float) ->
        pains w e
          [
            (0.2, 0.6, "pain", "soldier/pain1");
            (0.6, 1.1, "painb", "soldier/pain2");
            (1.1, 1.1, "painc", "soldier/pain2");
          ]);
    fire = army_fire;
    bite = (fun (_ : world) (_ : t) -> ());
    check_attack = soldier_check;
  }

(*****************************************************************************)
(* The dog (rottweiler.qc) *)
(*****************************************************************************)

let dog_layout =
  [
    ("attack", 8);
    ("death", 9);
    ("deathb", 9);
    ("pain", 6);
    ("painb", 16);
    ("run", 12);
    ("leap", 9);
    ("stand", 9);
    ("walk", 8);
  ]

(* dog_bite: within 100, (3 randoms) x 8 *)
let dog_bite (w : world) (e : t) : unit =
  sound w (Some e.origin) "dog/dattack1" 1.;
  let o, _, _ = where w e.enemy in
  Monster_ai.face w e;
  if length (sub o e.origin) <= 100. then
    Combat.damage w e.enemy e.origin (Ent e)
      ((random w +. random w +. random w) *. 8.)

(* Dog_JumpTouch: 10 to 20 to what it lands on, if fast *)
let dog_jump_touch (w : world) (e : t) (other : who) : unit =
  if e.health > 0. && alive w other && length e.velocity > 300. then
    Combat.damage w other e.origin (Ent e) (10. +. (10. *. random w))

(* dog_leap2: 300 forward, 200 up *)
let dog_leap (w : world) (e : t) : unit =
  Monster_ai.face w e;
  e.touch <- dog_jump_touch;
  let a = e.yaw *. Float.pi /. 180. in
  e.origin <- { e.origin with z = e.origin.z +. 1. };
  e.velocity <- { x = 300. *. Float.cos a; y = 300. *. Float.sin a; z = 200. };
  e.onground <- false

(* DogCheckAttack: CheckDogMelee, CheckDogJump *)
let dog_check (w : world) (e : t) : bool =
  let o, mins, maxs = where w e.enemy in
  match Monster_ai.range w e e.enemy with
  | Monster_ai.Melee_range ->
      Monster_ai.start w e "atta";
      true
  | _ ->
      let bottom = o.z +. mins.z and size = maxs.z -. mins.z in
      let d = length { (sub o e.origin) with z = 0. } in
      if e.origin.z +. e.mins.z > bottom +. (0.75 *. size) then false
      else if e.origin.z +. e.maxs.z < bottom +. (0.25 *. size) then false
      else if d < 80. || d > 150. then false
      else begin
        Monster_ai.start w e "leap";
        true
      end

let dog : mclass =
  let s = seq dog_layout in
  {
    mname = "monster_dog";
    mmodel = "progs/dog.mdl";
    head = "progs/h_dog.mdl";
    mhealth = 25.;
    mmins = { x = -32.; y = -32.; z = -24. };
    mmaxs = { x = 32.; y = 32.; z = 40. };
    gib_health = -35.;
    seqs =
      [
        ("stand", s "stand" (List.init 9 (fun (_ : int) -> [ Stand ])) "stand");
        ( "run",
          s "run"
            [
              [ Noise ("dog/idle", 0.2); Run 16. ];
              [ Run 32. ];
              [ Run 32. ];
              [ Run 20. ];
              [ Run 64. ];
              [ Run 32. ];
              [ Run 16. ];
              [ Run 32. ];
              [ Run 32. ];
              [ Run 20. ];
              [ Run 64. ];
              [ Run 32. ];
            ]
            "run" );
        ( "atta",
          s "attack"
            [
              [ Charge 10. ];
              [ Charge 10. ];
              [ Charge 10. ];
              [ Melee ];
              [ Charge 10. ];
              [ Charge 10. ];
              [ Charge 10. ];
              [ Charge 10. ];
            ]
            "run" );
        (* (the leap's last frame kept until it lands) *)
        ( "leap",
          s "leap"
            ([ [ Face ]; [ Leap ] ]
            @ List.init 7 (fun (_ : int) -> [ Landed "run" ]))
            "landing" );
        ( "landing",
          {
            frames = [| first_of dog_layout "leap" + 8 |];
            acts = [| [ Landed "run" ] |];
            next = "landing";
          } );
        ("pain", s "pain" (nothing 6) "run");
        ( "painb",
          s "painb"
            ([
               [];
               [];
               [ Pain_back 4. ];
               [ Pain_back 12. ];
               [ Pain_back 12. ];
               [ Pain_back 2. ];
               [];
               [ Pain_back 4. ];
               [];
               [ Pain_back 10. ];
             ]
            @ nothing 6)
            "run" );
        ("die", s "death" ([ Noise ("dog/ddeath", 1.) ] :: nothing 8) "");
        ("dieb", s "deathb" ([ Noise ("dog/ddeath", 1.) ] :: nothing 8) "");
      ];
    stand = "stand";
    walk = "stand";
    run = "run";
    missile = "leap";
    melee = "atta";
    deaths = [ "die"; "dieb" ];
    sight = [ "dog/dsight" ];
    pain =
      (fun (w : world) (e : t) (_ : float) ->
        sound w (Some e.origin) "dog/dpain1" 1.;
        Monster_ai.start w e (if random w > 0.5 then "pain" else "painb"));
    fire = dog_leap;
    bite = dog_bite;
    check_attack = dog_check;
  }

(*****************************************************************************)
(* The enforcer (enforcer.qc) *)
(*****************************************************************************)

let enforcer_layout =
  [
    ("stand", 7);
    ("walk", 16);
    ("run", 8);
    ("attack", 10);
    ("death", 14);
    ("fdeath", 11);
    ("paina", 4);
    ("painb", 5);
    ("painc", 8);
    ("paind", 19);
  ]

(* Laser_Touch: 15, and the laser's stop *)
let laser_touch (w : world) (e : t) (other : who) : unit =
  sound w (Some e.origin) "enforcer/enfstop" 1.;
  (match other with
  | Nobody -> effect w (Gunshot e.origin)
  | _ ->
      effect w (Blood (e.origin, 15));
      Combat.damage w other e.origin e.owner 15.);
  remove w e

(* enforcer_fire: LaunchLaser at the enemy, from in front of its gun *)
let enforcer_fire (w : world) (e : t) : unit =
  Monster_ai.face w e;
  sound w (Some e.origin) "enforcer/enfire" 1.;
  let a = e.yaw *. Float.pi /. 180. in
  let src =
    {
      x = e.origin.x +. (30. *. Float.cos a);
      y = e.origin.y +. (30. *. Float.sin a);
      z = e.origin.z +. 16.;
    }
  in
  let o, _, _ = where w e.enemy in
  let dir = aimed w e (normalize (sub o src)) in
  ignore
    (Combat.launch w (Ent e) "laser" "progs/laser.mdl" src dir 600. laser_touch)

(* CheckAttack, fight.qc's for the monsters with no check of their own *)
let check_attack (w : world) (e : t) : bool =
  match range_and_shot w e with
  | Some r when time w >= e.attack_finished ->
      let chance =
        match r with
        | Monster_ai.Melee_range -> 0.9
        | Monster_ai.Near -> 0.4
        | Monster_ai.Mid -> 0.1
        | Monster_ai.Far -> 0.
      in
      if random w < chance then begin
        Monster_ai.start w e "atk";
        e.attack_finished <- time w +. (2. *. random w);
        true
      end
      else false
  | _ -> false

let enforcer : mclass =
  let s = seq enforcer_layout in
  let a = first_of enforcer_layout "attack" in
  {
    mname = "monster_enforcer";
    mmodel = "progs/enforcer.mdl";
    head = "progs/h_mega.mdl";
    mhealth = 80.;
    mmins = { x = -16.; y = -16.; z = -24. };
    mmaxs = { x = 16.; y = 16.; z = 40. };
    gib_health = -35.;
    seqs =
      [
        ("stand", s "stand" (List.init 7 (fun (_ : int) -> [ Stand ])) "stand");
        ( "run",
          s "run"
            [
              [ Noise ("enforcer/idle1", 0.2); Run 18. ];
              [ Run 14. ];
              [ Run 7. ];
              [ Run 12. ];
              [ Run 14. ];
              [ Run 14. ];
              [ Run 7. ];
              [ Run 11. ];
            ]
            "run" );
        (* (atk9 to atk12 show attack5 to attack8 again: a second shot) *)
        ( "atk",
          {
            frames =
              Array.map
                (fun (k : int) -> a + k)
                [| 0; 1; 2; 3; 4; 5; 6; 7; 4; 5; 6; 7; 8; 9 |];
            acts =
              [|
                [ Face ];
                [ Face ];
                [ Face ];
                [ Face ];
                [ Face ];
                [ Fire ];
                [ Face ];
                [ Face ];
                [ Face ];
                [ Fire ];
                [ Face ];
                [ Face ];
                [ Face ];
                [ Face ];
              |];
            next = "run";
          } );
        ("paina", s "paina" (nothing 4) "run");
        ("painb", s "painb" (nothing 5) "run");
        ("painc", s "painc" (nothing 8) "run");
        ("paind", s "paind" (nothing 19) "run");
        ( "die",
          s "death"
            ([ [ Noise ("enforcer/death1", 1.) ]; []; [ Drop ] ] @ nothing 11)
            "" );
        ( "fdie",
          s "fdeath"
            ([ [ Noise ("enforcer/death1", 1.) ]; []; [ Drop ] ] @ nothing 8)
            "" );
      ];
    stand = "stand";
    walk = "stand";
    run = "run";
    missile = "atk";
    melee = "";
    deaths = [ "die"; "fdie" ];
    sight =
      [
        "enforcer/sight1";
        "enforcer/sight2";
        "enforcer/sight3";
        "enforcer/sight4";
      ];
    pain =
      (fun (w : world) (e : t) (_ : float) ->
        let r = random w in
        if e.pain_finished <= time w then begin
          sound w (Some e.origin)
            (if r < 0.5 then "enforcer/pain1" else "enforcer/pain2")
            1.;
          let s, pause =
            if r < 0.2 then ("paina", 1.)
            else if r < 0.4 then ("painb", 1.)
            else if r < 0.7 then ("painc", 1.)
            else ("paind", 2.)
          in
          e.pain_finished <- time w +. pause;
          Monster_ai.start w e s
        end);
    fire = enforcer_fire;
    bite = (fun (_ : world) (_ : t) -> ());
    check_attack;
  }

(*****************************************************************************)
(* Spawning *)
(*****************************************************************************)

let classes = [ soldier; dog; enforcer ]

(* walkmonster_start: on the floor, thinking its first stand frame a
 * little later (spread over the first frames, as id's 0.1 to 0.2) *)
let spawn (w : world) (classname : string) (origin : vec) (yaw : float) :
    t option =
  match List.find_opt (fun (c : mclass) -> c.mname = classname) classes with
  | None -> None
  | Some c ->
      let e = spawn w classname origin c.mmins c.mmaxs in
      e.mclass <- Some c;
      e.model <- w.models c.mmodel;
      e.yaw <- yaw;
      e.ideal_yaw <- yaw;
      e.solid <- true;
      e.takedamage <- true;
      e.health <- c.mhealth;
      e.movetype <- Step;
      e.ammo_shells <- (if c == soldier then 5 else 0);
      (* droptofloor *)
      let t =
        Physics.trace w e.origin e.mins e.maxs
          { e.origin with z = e.origin.z -. 256. }
          (Ent e)
      in
      if t.fraction < 1. && not t.allsolid then e.origin <- t.endpos;
      e.onground <- true;
      e.seq <- c.stand;
      e.think <- Monster_ai.think;
      e.nextthink <- time w +. 0.1 +. (random w *. 0.1);
      Some e

let models =
  [
    "progs/soldier.mdl";
    "progs/dog.mdl";
    "progs/enforcer.mdl";
    "progs/h_guard.mdl";
    "progs/h_dog.mdl";
    "progs/h_mega.mdl";
    "progs/laser.mdl";
    "progs/gib1.mdl";
    "progs/gib2.mdl";
    "progs/gib3.mdl";
    "progs/backpack.mdl";
  ]

let sounds =
  [
    "soldier/death1";
    "soldier/idle";
    "soldier/pain1";
    "soldier/pain2";
    "soldier/sattck1";
    "soldier/sight1";
    "dog/dattack1";
    "dog/ddeath";
    "dog/dpain1";
    "dog/dsight";
    "dog/idle";
    "enforcer/death1";
    "enforcer/enfire";
    "enforcer/enfstop";
    "enforcer/idle1";
    "enforcer/pain1";
    "enforcer/pain2";
    "enforcer/sight1";
    "enforcer/sight2";
    "enforcer/sight3";
    "enforcer/sight4";
    "player/udeath";
  ]
