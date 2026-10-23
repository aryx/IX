(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Trace.mli *)

open Model

type trace = {
  fraction : float;
  endpos : vec;
  normal : vec;
  startsolid : bool;
  allsolid : bool;
  hit : int;
}

(* what a trace learns on its way (trace_t, filled by the walk) *)
type state = {
  mutable sfraction : float;
  mutable send : vec;
  mutable snormal : vec;
  mutable sstartsolid : bool;
  mutable sallsolid : bool;
}

let dist_epsilon = 0.03125

let plane_dist (p : plane) (q : vec) : float =
  match p.kind with
  | 0 -> q.x -. p.dist
  | 1 -> q.y -. p.dist
  | 2 -> q.z -. p.dist
  | _ -> dot p.normal q -. p.dist

let rec hull_point_contents (h : hull) (num : int) (p : vec) : int =
  if num < 0 then num
  else
    hull_point_contents h
      (if plane_dist h.cplanes.(num) p >= 0. then h.front.(num)
       else h.back.(num))
      p

let point_contents (m : Model.t) (p : vec) : contents =
  Model.contents_of
    (hull_point_contents m.hulls.(0) m.submodels.(0).headnode.(0) p)

(* SV_RecursiveHullCheck: false when the segment was stopped *)
let rec check (h : hull) (root : int) (num : int) (p1f : float) (p2f : float)
    (p1 : vec) (p2 : vec) (st : state) : bool =
  if num < 0 then begin
    if num <> -2 then st.sallsolid <- false else st.sstartsolid <- true;
    true
  end
  else begin
    let pl = h.cplanes.(num) in
    let t1 = plane_dist pl p1 and t2 = plane_dist pl p2 in
    if t1 >= 0. && t2 >= 0. then check h root h.front.(num) p1f p2f p1 p2 st
    else if t1 < 0. && t2 < 0. then check h root h.back.(num) p1f p2f p1 p2 st
    else begin
      (* the crossing, put DIST_EPSILON on the near side *)
      let frac =
        if t1 < 0. then (t1 +. dist_epsilon) /. (t1 -. t2)
        else (t1 -. dist_epsilon) /. (t1 -. t2)
      in
      let frac = Float.max 0. (Float.min 1. frac) in
      let at (f : float) : float * vec =
        (p1f +. ((p2f -. p1f) *. f), add p1 (scale f (sub p2 p1)))
      in
      let midf, mid = at frac in
      let near, far =
        if t1 < 0. then (h.back.(num), h.front.(num))
        else (h.front.(num), h.back.(num))
      in
      if not (check h root near p1f midf p1 mid st) then false
      else if hull_point_contents h far mid <> -2 then
        check h root far midf p2f mid p2 st
      else if st.sallsolid then false
      else begin
        (* the other side is solid: the impact *)
        st.snormal <- (if t1 < 0. then scale (-1.) pl.normal else pl.normal);
        (* (backed up while in solid: the floats of the hulls) *)
        let frac = ref frac
        and midf = ref midf
        and mid = ref mid
        and gave_up = ref false in
        while (not !gave_up) && hull_point_contents h root !mid = -2 do
          frac := !frac -. 0.1;
          if !frac < 0. then gave_up := true
          else begin
            let f, q = at !frac in
            midf := f;
            mid := q
          end
        done;
        st.sfraction <- !midf;
        st.send <- !mid;
        false
      end
    end
  end

let hull_check (m : Model.t) (hull_num : int) (headnode : int) (start : vec)
    (finish : vec) : trace =
  let h = m.hulls.(hull_num) in
  let st =
    {
      sfraction = 1.;
      send = finish;
      snormal = zero;
      sstartsolid = false;
      sallsolid = true;
    }
  in
  ignore (check h headnode headnode 0. 1. start finish st);
  {
    fraction = st.sfraction;
    endpos = st.send;
    normal = st.snormal;
    startsolid = st.sstartsolid;
    allsolid = st.sallsolid;
    hit = -1;
  }

let move (m : Model.t) (hull_num : int) (start : vec) (finish : vec)
    (solids : (int * int * vec) list) : trace =
  let world =
    hull_check m hull_num m.submodels.(0).headnode.(hull_num) start finish
  in
  List.fold_left
    (fun (best : trace) ((ent, k, origin) : int * int * vec) ->
      (* (the segment in the model's space) *)
      let t =
        hull_check m hull_num
          m.submodels.(k).headnode.(hull_num)
          (sub start origin) (sub finish origin)
      in
      let t = { t with endpos = add t.endpos origin; hit = ent } in
      if t.allsolid || t.startsolid || t.fraction < best.fraction then
        (* (SV_ClipToLinks: a start in solid wins) *)
        if best.startsolid then { t with startsolid = true } else t
      else best)
    world solids

(* SV_HullForBox's question for a segment: where it enters the box
 * (mins, maxs), by the slabs, the box already grown by the mover's
 * own (an entity's box is a hull of its own in world.c) *)
let box (start : vec) (finish : vec) (mins : vec) (maxs : vec) : trace option =
  let d = sub finish start in
  let enter = ref (-1.) and leave = ref 2. and normal = ref zero in
  let ok = ref true in
  let axis (s : float) (dv : float) (lo : float) (hi : float) (n : vec) : unit =
    if dv = 0. then (if s <= lo || s >= hi then ok := false)
    else begin
      let t1 = (lo -. s) /. dv and t2 = (hi -. s) /. dv in
      let tin, tout, nin =
        if t1 < t2 then (t1, t2, scale (-1.) n) else (t2, t1, n)
      in
      if tin > !enter then begin
        enter := tin;
        normal := nin
      end;
      if tout < !leave then leave := tout
    end
  in
  axis start.x d.x mins.x maxs.x { x = 1.; y = 0.; z = 0. };
  axis start.y d.y mins.y maxs.y { x = 0.; y = 1.; z = 0. };
  axis start.z d.z mins.z maxs.z { x = 0.; y = 0.; z = 1. };
  if (not !ok) || !enter > !leave || !enter > 1. || !leave < 0. then None
  else if !enter < 0. then
    Some
      {
        fraction = 0.;
        endpos = start;
        normal = zero;
        startsolid = true;
        allsolid = !leave > 1.;
        hit = -1;
      }
  else
    (* (1/32 back, DIST_EPSILON, as the hull's) *)
    let len = length d in
    let f = Float.max 0. (!enter -. if len > 0. then 0.03125 /. len else 0.) in
    Some
      {
        fraction = f;
        endpos = add start (scale f d);
        normal = !normal;
        startsolid = false;
        allsolid = false;
        hit = -1;
      }
