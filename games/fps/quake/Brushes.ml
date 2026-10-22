(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Brushes.mli *)

open Model

type body = {
  mutable origin : vec;
  mutable velocity : vec;
  mutable yaw : float;
  mutable onground : bool;
  mutable ground : int;
}

(* STATE_TOP, STATE_BOTTOM, STATE_UP, STATE_DOWN *)
type state = Top | Bottom | Up | Down

(* what a mover does when it arrives, or when its time comes *)
type action =
  | Door_hit_top
  | Door_hit_bottom
  | Door_go_down
  | Button_wait
  | Button_return
  | Button_done
  | Plat_hit_top
  | Plat_hit_bottom
  | Plat_go_down
  (* fd_secret_move1 to 6 *)
  | Secret of int
  | Remove

type kind =
  | Door of {
      pos1 : vec;
      pos2 : vec;
      mutable dstate : state;
      mutable linked : int list;
      key : int;
      toggle : bool;
    }
  | Button of {
      bpos1 : vec;
      bpos2 : vec;
      mutable bstate : state;
      shootable : bool;
    }
  | Plat of {
      ppos1 : vec;
      ppos2 : vec;
      mutable pstate : state;
      mutable usable : bool;
    }
  | Secret_door of {
      start : vec;
      mutable dest1 : vec;
      mutable dest2 : vec;
      forward : vec;
      right : vec;
      up : vec;
      length : float;
      width : float;
      flags : int;
    }
  (* a door's field, a plat's: touched, it uses its owner *)
  | Field of { owner : int; fmins : vec; fmaxs : vec }
  | Trigger of { once : bool; secret : bool }
  | Teleport of { mutable enabled_until : float }
  | Changelevel
  | Wall
  | Light of { style : int; mutable on : bool }
  | Other

type ent = {
  num : int;
  classname : string;
  keys : (string * string) list;
  (* its brush model, -1 none *)
  bmodel : int;
  mutable eorigin : vec;
  mutable alive : bool;
  kind : kind;
  mutable frame : int;
  speed : float;
  wait : float;
  (* moving: towards dest, then the action *)
  mutable dest : vec;
  mutable moving : bool;
  mutable on_arrive : action;
  (* thinking: the action at that time *)
  mutable think : (float * action) option;
  (* (a touch's or a field's next possible time: attack_finished) *)
  mutable ready : float;
  mutable message : string;
}

type t = {
  level : Model.t;
  ents : ent array;
  styles : string array;
  mutable msg : (string * float) option;
  mutable exited : bool;
  mutable found : int;
  total : int;
  mutable keys_held : int;
  mutable now : float;
}

let key (e : ent) (k : string) : string option = List.assoc_opt k e.keys

let fkey (e : ent) (k : string) (default : float) : float =
  match
    Option.bind (key e k) (fun (s : string) ->
        float_of_string_opt (String.trim s))
  with
  | Some f -> f
  | None -> default

let ikey (e : ent) (k : string) : int = int_of_float (fkey e k 0.)

let size (m : Model.t) (e : ent) : vec =
  if e.bmodel < 0 then zero
  else
    let sm = m.submodels.(e.bmodel) in
    sub sm.maxs sm.mins

let absmins (m : Model.t) (e : ent) : vec =
  if e.bmodel < 0 then e.eorigin else add e.eorigin m.submodels.(e.bmodel).mins

let absmaxs (m : Model.t) (e : ent) : vec =
  if e.bmodel < 0 then e.eorigin else add e.eorigin m.submodels.(e.bmodel).maxs

(* (QuakeC's "if (!self.wait) self.wait = 5": 0 is unset) *)
let nonzero (v : float) (default : float) : float =
  if v = 0. then default else v

let fabs_dot (a : vec) (b : vec) : float = Float.abs (dot a b)

(* "angle": -1 up, -2 down, else a yaw (SetMovedir) *)
let movedir (e : ent) : vec =
  let a = fkey e "angle" 0. in
  if a = -1. then { x = 0.; y = 0.; z = 1. }
  else if a = -2. then { x = 0.; y = 0.; z = -1. }
  else
    let f, _, _ = View.angle_vectors 0. a in
    f

let player_mins = { x = -16.; y = -16.; z = -24. }
let player_maxs = { x = 16.; y = 16.; z = 32. }

let boxes_touch (amin : vec) (amax : vec) (bmin : vec) (bmax : vec) : bool =
  amin.x <= bmax.x && amax.x >= bmin.x && amin.y <= bmax.y && amax.y >= bmin.y
  && amin.z <= bmax.z && amax.z >= bmin.z

(*****************************************************************************)
(* Spawning *)
(*****************************************************************************)

let create (m : Model.t) (styles : string array) : t =
  Array.fill styles 0 (Array.length styles) "";
  List.iter (fun ((k, s) : int * string) -> styles.(k) <- s) View.styles;
  let ents =
    List.mapi
      (fun (num : int) (keys : (string * string) list) ->
        let classname =
          match List.assoc_opt "classname" keys with Some v -> v | None -> ""
        in
        let bmodel =
          match List.assoc_opt "model" keys with
          | Some s when String.length s > 1 && s.[0] = '*' ->
              int_of_string (String.sub s 1 (String.length s - 1))
          | _ -> -1
        in
        let flags =
          match
            Option.bind (List.assoc_opt "spawnflags" keys) int_of_string_opt
          with
          | Some f -> f
          | None -> 0
        in
        let origin =
          match List.assoc_opt "origin" keys with
          | Some o -> vec_of_string o
          | None -> zero
        in
        {
          num;
          classname;
          keys;
          bmodel;
          eorigin = origin;
          (* (not in medium skill: SPAWNFLAG_NOT_MEDIUM) *)
          alive = num = 0 || flags land 512 = 0;
          kind = Other;
          frame = 0;
          speed = 0.;
          wait = 0.;
          dest = origin;
          moving = false;
          on_arrive = Remove;
          think = None;
          ready = 0.;
          message =
            (match List.assoc_opt "message" keys with
            | Some v -> v
            | None -> "");
        })
      m.entities
    |> Array.of_list
  in
  let b =
    {
      level = m;
      ents;
      styles;
      msg = None;
      exited = false;
      found = 0;
      total = 0;
      keys_held = 0;
      now = 0.;
    }
  in
  let set (e : ent) (speed : float) (wait : float) (kind : kind) : unit =
    ents.(e.num) <- { e with speed; wait; kind }
  in
  let total = ref 0 in
  Array.iter
    (fun (e : ent) ->
      if e.alive then
        match e.classname with
        | "func_door" ->
            let dir = movedir e in
            let lip = fkey e "lip" 8. in
            let pos1 = e.eorigin in
            let pos2 = add pos1 (scale (fabs_dot dir (size m e) -. lip) dir) in
            let flags = ikey e "spawnflags" in
            (* (START_OPEN: the positions swapped) *)
            let pos1, pos2 =
              if flags land 1 <> 0 then (pos2, pos1) else (pos1, pos2)
            in
            set e (fkey e "speed" 100.) (fkey e "wait" 3.)
              (Door
                 {
                   pos1;
                   pos2;
                   dstate = Bottom;
                   linked = [ e.num ];
                   key = flags land (8 lor 16);
                   toggle = flags land 32 <> 0;
                 });
            ents.(e.num).eorigin <- pos1
        | "func_door_secret" ->
            let f, r, u = View.angle_vectors 0. (fkey e "angle" 0.) in
            set e (fkey e "speed" 50.)
              (nonzero (fkey e "wait" 0.) 5.)
              (Secret_door
                 {
                   start = e.eorigin;
                   dest1 = e.eorigin;
                   dest2 = e.eorigin;
                   forward = f;
                   right = r;
                   up = u;
                   length = fkey e "t_length" 0.;
                   width = fkey e "t_width" 0.;
                   flags = ikey e "spawnflags";
                 })
        | "func_button" ->
            let dir = movedir e in
            let pos2 =
              add e.eorigin
                (scale (fabs_dot dir (size m e) -. fkey e "lip" 4.) dir)
            in
            set e (fkey e "speed" 40.)
              (nonzero (fkey e "wait" 0.) 1.)
              (Button
                 {
                   bpos1 = e.eorigin;
                   bpos2 = pos2;
                   bstate = Bottom;
                   shootable = fkey e "health" 0. > 0.;
                 })
        | "func_plat" ->
            let sz = size m e in
            let pos1 = e.eorigin in
            let h = fkey e "height" 0. in
            let pos2 =
              {
                pos1 with
                z = (if h <> 0. then pos1.z -. h else pos1.z -. sz.z +. 8.);
              }
            in
            let targeted = key e "targetname" <> None in
            set e (fkey e "speed" 150.) 0.
              (Plat
                 {
                   ppos1 = pos1;
                   ppos2 = pos2;
                   pstate = (if targeted then Up else Bottom);
                   usable = targeted;
                 });
            if not targeted then ents.(e.num).eorigin <- pos2
        | "func_wall" -> set e 0. 0. Wall
        | "trigger_once" ->
            set e 0. (-1.) (Trigger { once = true; secret = false })
        | "trigger_multiple" ->
            set e 0.
              (nonzero (fkey e "wait" 0.) 0.2)
              (Trigger { once = false; secret = false })
        | "trigger_secret" ->
            incr total;
            set e 0. (-1.) (Trigger { once = true; secret = true });
            if e.message = "" then
              ents.(e.num).message <- "You found a secret area!"
        | "trigger_teleport" ->
            set e 0. 0.
              (Teleport
                 {
                   enabled_until =
                     (if key e "targetname" = None then infinity else 0.);
                 })
        | "trigger_changelevel" -> set e 0. 0. Changelevel
        | "light" | "light_fluoro" | "light_fluorospark" -> (
            match
              (key e "targetname", Option.bind (key e "style") int_of_string_opt)
            with
            | Some _, Some s when s >= 32 ->
                let on = ikey e "spawnflags" land 1 = 0 in
                styles.(s) <- (if on then "m" else "a");
                set e 0. 0. (Light { style = s; on })
            | _ -> ())
        | _ -> ())
    ents;
  (* the doors that touch, linked (LinkDoors); a field around each
   * group with nothing else to open it: no name, no key, not shot *)
  let doors =
    List.filter
      (fun (e : ent) ->
        e.alive && match e.kind with Door _ -> true | _ -> false)
      (Array.to_list ents)
  in
  let fields = ref [] in
  List.iter
    (fun (e : ent) ->
      match e.kind with
      | Door d when ikey e "spawnflags" land 4 = 0 && List.length d.linked = 1
        ->
          let group = ref [ e ] and changed = ref true in
          while !changed do
            changed := false;
            List.iter
              (fun (o : ent) ->
                if
                  (not (List.memq o !group))
                  && ikey o "spawnflags" land 4 = 0
                  && List.exists
                       (fun (g : ent) ->
                         boxes_touch (absmins m g) (absmaxs m g) (absmins m o)
                           (absmaxs m o))
                       !group
                then begin
                  group := o :: !group;
                  changed := true
                end)
              doors
          done;
          let nums = List.map (fun (g : ent) -> g.num) !group in
          List.iter
            (fun (g : ent) ->
              match g.kind with Door gd -> gd.linked <- nums | _ -> ())
            !group;
          if
            List.for_all
              (fun (g : ent) ->
                key g "targetname" = None
                && fkey g "health" 0. = 0.
                && match g.kind with Door gd -> gd.key = 0 | _ -> true)
              !group
          then begin
            let mins =
              List.fold_left
                (fun (a : vec) (g : ent) ->
                  let v = absmins m g in
                  {
                    x = Float.min a.x v.x;
                    y = Float.min a.y v.y;
                    z = Float.min a.z v.z;
                  })
                (absmins m e) !group
            in
            let maxs =
              List.fold_left
                (fun (a : vec) (g : ent) ->
                  let v = absmaxs m g in
                  {
                    x = Float.max a.x v.x;
                    y = Float.max a.y v.y;
                    z = Float.max a.z v.z;
                  })
                (absmaxs m e) !group
            in
            fields :=
              Field
                {
                  owner = e.num;
                  fmins =
                    { x = mins.x -. 60.; y = mins.y -. 60.; z = mins.z -. 8. };
                  fmaxs =
                    { x = maxs.x +. 60.; y = maxs.y +. 60.; z = maxs.z +. 8. };
                }
              :: !fields
          end
      | _ -> ())
    doors;
  (* a plat's field: over it, the height it travels (plat_spawn_inside_trigger) *)
  Array.iter
    (fun (e : ent) ->
      match e.kind with
      | Plat p ->
          let sm = m.submodels.(e.bmodel) in
          let mins = add sm.mins { x = 25.; y = 25.; z = 0. }
          and maxs = sub sm.maxs { x = 25.; y = 25.; z = -8. } in
          let mins =
            { mins with z = maxs.z -. (p.ppos1.z -. p.ppos2.z +. 8.) }
          in
          fields :=
            Field { owner = e.num; fmins = mins; fmaxs = maxs } :: !fields
      | _ -> ())
    ents;
  let extra =
    List.mapi
      (fun (i : int) (k : kind) ->
        {
          num = Array.length ents + i;
          classname = "field";
          keys = [];
          bmodel = -1;
          eorigin = zero;
          alive = true;
          kind = k;
          frame = 0;
          speed = 0.;
          wait = 0.;
          dest = zero;
          moving = false;
          on_arrive = Remove;
          think = None;
          ready = 0.;
          message = "";
        })
      (List.rev !fields)
  in
  { b with ents = Array.append ents (Array.of_list extra); total = !total }

(*****************************************************************************)
(* Moving (SUB_CalcMove, SV_PushMove) *)
(*****************************************************************************)

let calc_move (e : ent) (dest : vec) (arrive : action) : unit =
  e.dest <- dest;
  e.moving <- true;
  e.on_arrive <- arrive

let say (b : t) (s : string) : unit = if s <> "" then b.msg <- Some (s, b.now)

let rec use_targets (b : t) (body : body) (e : ent) : unit =
  say b e.message;
  (match key e "killtarget" with
  | Some k ->
      Array.iter
        (fun (o : ent) -> if key o "targetname" = Some k then o.alive <- false)
        b.ents
  | None -> ());
  match key e "target" with
  | Some t ->
      Array.iter
        (fun (o : ent) ->
          if o.alive && key o "targetname" = Some t then use_ent b body o)
        b.ents
  | None -> ()

and door_go_up (b : t) (body : body) (e : ent) : unit =
  match e.kind with
  | Door d -> (
      match d.dstate with
      | Up -> ()
      | Top ->
          if e.wait >= 0. then e.think <- Some (b.now +. e.wait, Door_go_down)
      | _ ->
          d.dstate <- Up;
          calc_move e d.pos2 Door_hit_top;
          use_targets b body e)
  | _ -> ()

and door_go_down (e : ent) : unit =
  match e.kind with
  | Door d ->
      d.dstate <- Down;
      calc_move e d.pos1 Door_hit_bottom
  | _ -> ()

and door_fire (b : t) (body : body) (e : ent) : unit =
  match e.kind with
  | Door d ->
      let group = List.map (fun (k : int) -> b.ents.(k)) d.linked in
      if d.toggle && (d.dstate = Up || d.dstate = Top) then
        List.iter door_go_down group
      else List.iter (door_go_up b body) group
  | _ -> ()

and use_ent (b : t) (body : body) (e : ent) : unit =
  match e.kind with
  | Door _ -> door_fire b body e
  | Button bt ->
      if bt.bstate <> Up && bt.bstate <> Top then begin
        bt.bstate <- Up;
        calc_move e bt.bpos2 Button_wait
      end
  | Plat p ->
      if p.usable then begin
        p.usable <- false;
        p.pstate <- Down;
        calc_move e p.ppos2 Plat_hit_bottom
      end
      else if e.think = None && p.pstate = Top then begin
        p.pstate <- Down;
        calc_move e p.ppos2 Plat_hit_bottom
      end
  | Secret_door s ->
      if (not e.moving) && e.eorigin = s.start then begin
        e.message <- "";
        use_targets b body e;
        (* back (or down), then aside along its angle *)
        let sz = size b.level e in
        let width =
          if s.width <> 0. then s.width
          else if s.flags land 4 <> 0 then fabs_dot s.up sz
          else fabs_dot s.right sz
        in
        let length =
          if s.length <> 0. then s.length else fabs_dot s.forward sz
        in
        let side = if s.flags land 2 <> 0 then -1. else 1. in
        s.dest1 <-
          (if s.flags land 4 <> 0 then sub s.start (scale width s.up)
           else add s.start (scale (width *. side) s.right));
        s.dest2 <- add s.dest1 (scale length s.forward);
        calc_move e s.dest1 (Secret 1)
      end
  | Trigger tr -> trigger b body e tr.once tr.secret
  | Teleport tp -> tp.enabled_until <- b.now +. 0.2
  | Light l ->
      l.on <- not l.on;
      b.styles.(l.style) <- (if l.on then "m" else "a")
  | Field _ | Changelevel | Wall | Other -> use_targets b body e

(* multi_trigger *)
and trigger (b : t) (body : body) (e : ent) (once : bool) (secret : bool) : unit
    =
  if b.now >= e.ready then begin
    if secret then b.found <- b.found + 1;
    use_targets b body e;
    if once then e.alive <- false else e.ready <- b.now +. e.wait
  end

let arrive (b : t) (body : body) (e : ent) (a : action) : unit =
  match (a, e.kind) with
  | Door_hit_top, Door d ->
      d.dstate <- Top;
      (* (wait -1: never back, its think in the past never runs) *)
      if (not d.toggle) && e.wait >= 0. then
        e.think <- Some (b.now +. e.wait, Door_go_down)
  | Door_hit_bottom, Door d -> d.dstate <- Bottom
  | Door_go_down, Door _ -> door_go_down e
  | Button_wait, Button bt ->
      bt.bstate <- Top;
      e.frame <- 1;
      if e.wait >= 0. then e.think <- Some (b.now +. e.wait, Button_return);
      use_targets b body e
  | Button_return, Button bt ->
      bt.bstate <- Down;
      e.frame <- 0;
      calc_move e bt.bpos1 Button_done
  | Button_done, Button bt -> bt.bstate <- Bottom
  | Plat_hit_top, Plat p ->
      p.pstate <- Top;
      e.think <- Some (b.now +. 3., Plat_go_down)
  | Plat_hit_bottom, Plat p -> p.pstate <- Bottom
  | Plat_go_down, Plat p ->
      p.pstate <- Down;
      calc_move e p.ppos2 Plat_hit_bottom
  | Secret k, Secret_door s -> (
      match k with
      | 1 -> e.think <- Some (b.now +. 1., Secret 2)
      | 2 -> calc_move e s.dest2 (Secret 3)
      | 3 ->
          if s.flags land 1 = 0 && e.wait >= 0. then
            e.think <- Some (b.now +. e.wait, Secret 4)
      | 4 -> calc_move e s.dest1 (Secret 5)
      | 5 -> e.think <- Some (b.now +. 1., Secret 6)
      | _ -> calc_move e s.start Remove)
  | _ -> ()

(* the player in the brush's model at its origin *)
let inside (b : t) (e : ent) (body : body) : bool =
  let h = b.level.hulls.(1)
  and root = b.level.submodels.(e.bmodel).headnode.(1) in
  let rec contents (num : int) (p : vec) : int =
    if num < 0 then num
    else
      contents
        (if dot h.cplanes.(num).normal p -. h.cplanes.(num).dist >= 0. then
           h.front.(num)
         else h.back.(num))
        p
  in
  contents root (sub body.origin e.eorigin) = -2

let solids_but (b : t) (k : int) : (int * int * vec) list =
  Array.fold_left
    (fun (acc : (int * int * vec) list) (e : ent) ->
      match e.kind with
      | (Door _ | Button _ | Plat _ | Secret_door _ | Wall)
        when e.alive && e.num <> k && e.bmodel >= 0 ->
          (e.num, e.bmodel, e.eorigin) :: acc
      | _ -> acc)
    [] b.ents

let solids (b : t) : (int * int * vec) list = solids_but b (-1)

(* the mover moved by delta, the player with it; false if blocked *)
let push (b : t) (e : ent) (delta : vec) (body : body) : bool =
  let old = e.eorigin in
  e.eorigin <- add old delta;
  let riding = body.onground && body.ground = e.num in
  if riding || inside b e body then begin
    let t =
      Trace.move b.level 1 body.origin (add body.origin delta)
        (solids_but b e.num)
    in
    body.origin <- t.endpos;
    if inside b e body then begin
      e.eorigin <- old;
      false
    end
    else true
  end
  else true

let blocked (e : ent) : unit =
  match e.kind with
  | Door d when e.wait >= 0. -> (
      match d.dstate with
      | Down ->
          d.dstate <- Up;
          calc_move e d.pos2 Door_hit_top
      | _ -> door_go_down e)
  | Plat p -> (
      match p.pstate with
      | Up ->
          p.pstate <- Down;
          calc_move e p.ppos2 Plat_hit_bottom
      | Down ->
          p.pstate <- Up;
          calc_move e p.ppos1 Plat_hit_top
      | _ -> ())
  | _ -> ()

let run (b : t) (body : body) (time : float) (dt : float) : unit =
  b.now <- time;
  Array.iter
    (fun (e : ent) ->
      if e.alive then begin
        if e.moving then begin
          let d = sub e.dest e.eorigin in
          let len = length d and step = e.speed *. dt in
          let delta = if len <= step then d else scale (step /. len) d in
          if push b e delta body then begin
            if len <= step then begin
              e.moving <- false;
              arrive b body e e.on_arrive
            end
          end
          else blocked e
        end;
        match e.think with
        | Some (at, a) when at <= time ->
            e.think <- None;
            arrive b body e a
        | _ -> ()
      end)
    b.ents

(*****************************************************************************)
(* Touching *)
(*****************************************************************************)

let touch (b : t) (body : body) (time : float) : unit =
  b.now <- time;
  let pmin = add body.origin player_mins
  and pmax = add body.origin player_maxs in
  (* (a touch: the boxes overlap; a brush's walls, a unit around) *)
  let near (mins : vec) (maxs : vec) : bool =
    boxes_touch pmin pmax
      (sub mins { x = 1.; y = 1.; z = 1. })
      (add maxs { x = 1.; y = 1.; z = 1. })
  in
  let m = b.level in
  Array.iter
    (fun (e : ent) ->
      if e.alive then
        match e.kind with
        | Field f ->
            if boxes_touch pmin pmax f.fmins f.fmaxs && time >= e.ready then begin
              e.ready <- time +. 1.;
              let o = b.ents.(f.owner) in
              match o.kind with
              | Plat p -> (
                  match p.pstate with
                  | Bottom ->
                      p.pstate <- Up;
                      calc_move o p.ppos1 Plat_hit_top;
                      e.ready <- time
                  | Top ->
                      o.think <- Some (time +. 1., Plat_go_down);
                      e.ready <- time
                  | _ -> e.ready <- time)
              | _ ->
                  say b o.message;
                  o.message <- "";
                  door_fire b body o
            end
        | Door d when near (absmins m e) (absmaxs m e) ->
            if d.key <> 0 && time >= e.ready then begin
              e.ready <- time +. 2.;
              if b.keys_held land d.key = d.key then begin
                b.keys_held <- b.keys_held land lnot d.key;
                door_fire b body e
              end
              else
                say b
                  (if d.key = 8 then "You need the gold key"
                   else "You need the silver key")
            end
        | Button bt when (not bt.shootable) && near (absmins m e) (absmaxs m e)
          ->
            use_ent b body e
        | Trigger tr
          when key e "targetname" = None
               && boxes_touch pmin pmax (absmins m e) (absmaxs m e) ->
            trigger b body e tr.once tr.secret
        | Teleport tp
          when tp.enabled_until >= time
               && boxes_touch pmin pmax (absmins m e) (absmaxs m e) -> (
            match
              Array.to_list b.ents
              |> List.find_opt (fun (o : ent) ->
                  key o "targetname" = key e "target"
                  && o.classname = "info_teleport_destination")
            with
            | Some d ->
                let yaw = fkey d "angle" 0. in
                let f, _, _ = View.angle_vectors 0. yaw in
                body.origin <- add d.eorigin { x = 0.; y = 0.; z = 27. };
                body.yaw <- yaw;
                body.velocity <- scale 300. f
            | None -> ())
        | Changelevel when boxes_touch pmin pmax (absmins m e) (absmaxs m e) ->
            b.exited <- true
        | _ -> ())
    b.ents;
  (* the keys, picked up within their box (item_key1: silver, 2: gold) *)
  Array.iter
    (fun (e : ent) ->
      if e.alive && (e.classname = "item_key1" || e.classname = "item_key2")
      then
        if
          boxes_touch pmin pmax
            (sub e.eorigin { x = 16.; y = 16.; z = 0. })
            (add e.eorigin { x = 16.; y = 16.; z = 56. })
        then begin
          e.alive <- false;
          b.keys_held <-
            (b.keys_held lor if e.classname = "item_key2" then 8 else 16);
          say b
            (if e.classname = "item_key2" then "You got the gold key"
             else "You got the silver key")
        end)
    b.ents

let use (b : t) (body : body) (eye : vec) (forward : vec) (time : float) : unit
    =
  b.now <- time;
  let t = Trace.move b.level 0 eye (add eye (scale 96. forward)) (solids b) in
  if t.hit >= 0 && t.fraction < 1. then begin
    let e = b.ents.(t.hit) in
    match e.kind with Secret_door _ | Button _ -> use_ent b body e | _ -> ()
  end

let drawn (b : t) : (int * int * vec * int) list =
  Array.fold_left
    (fun (acc : (int * int * vec * int) list) (e : ent) ->
      match e.kind with
      | (Door _ | Button _ | Plat _ | Secret_door _ | Wall)
        when e.alive && e.bmodel > 0 ->
          (e.num, e.bmodel, e.eorigin, e.frame) :: acc
      | _ -> acc)
    [] b.ents

let message (b : t) : (string * float) option = b.msg
let exited (b : t) : bool = b.exited
let secrets (b : t) : int * int = (b.found, b.total)

let taken (b : t) (classname : string) (origin : vec) : bool =
  Array.exists
    (fun (e : ent) ->
      e.classname = classname && e.eorigin = origin && not e.alive)
    b.ents
