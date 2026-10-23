(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Bsp.mli *)

open Model

let marked = ref 0

let mark_leaves (v : View.t) (m : Model.t) (leaf : leaf) : unit =
  if v.oldviewleaf <> leaf.lindex then begin
    v.oldviewleaf <- leaf.lindex;
    v.visframecount <- v.visframecount + 1;
    let vis = Model.pvs m leaf in
    let n = m.submodels.(0).visleafs in
    marked := 0;
    for i = 0 to n - 1 do
      if Char.code (Bytes.get vis (i lsr 3)) land (1 lsl (i land 7)) <> 0 then begin
        let l = m.leaves.(i + 1) in
        incr marked;
        l.lvisframe <- v.visframecount;
        (* the parents, up to one already marked *)
        let rec up (p : node option) : unit =
          match p with
          | Some p when p.nvisframe <> v.visframecount ->
              p.nvisframe <- v.visframecount;
              up p.nparent
          | _ -> ()
        in
        up l.lparent
      end
    done
  end

(* the box against the planes still to clip by: -1 out of one, else
 * the planes it crosses (R_RecursiveWorldNode's test, R_BmodelCheckBBox) *)
let clip_box (v : View.t) (mins : vec) (maxs : vec) (clipflags : int) : int =
  let flags = ref clipflags and out = ref false in
  for i = 0 to 3 do
    if (not !out) && !flags land (1 lsl i) <> 0 then begin
      let idx = v.frustum_indexes.(i) and c = v.clips.(i) in
      let corner (o : int) : vec =
        {
          x = View.minmax mins maxs idx.(o);
          y = View.minmax mins maxs idx.(o + 1);
          z = View.minmax mins maxs idx.(o + 2);
        }
      in
      (* the corner farthest out: if out, all is *)
      if dot (corner 0) c.cnormal -. c.cdist <= 0. then out := true
      else if dot (corner 3) c.cnormal -. c.cdist >= 0. then
        (* the farthest in is in: no clip by it *)
        flags := !flags land lnot (1 lsl i)
    end
  done;
  if !out then -1 else !flags

let backface_epsilon = 0.01

let rec world_node (e : Edges.t) (v : View.t) (m : Model.t) (c : child)
    (clipflags : int) : unit =
  match c with
  | Leaf l ->
      if l.contents <> Solid && l.lvisframe = v.visframecount then begin
        let flags =
          if clipflags = 0 then 0 else clip_box v l.lmins l.lmaxs clipflags
        in
        if flags >= 0 then begin
          (* its faces may be drawn, when their node is reached *)
          Array.iter (fun (s : surface) -> s.visframe <- v.framecount) l.marks;
          l.key <- v.currentkey;
          (* (all brush models in a leaf share its key) *)
          v.currentkey <- v.currentkey + 1
        end
      end
  | Node n ->
      if n.nvisframe = v.visframecount then begin
        let flags =
          if clipflags = 0 then 0 else clip_box v n.nmins n.nmaxs clipflags
        in
        if flags >= 0 then begin
          let p = n.nplane in
          let d = dot v.modelorg p.normal -. p.dist in
          let side = if d >= 0. then 0 else 1 in
          (* the eye's side first *)
          world_node e v m n.children.(side) flags;
          if n.num_surfaces > 0 then begin
            (* the node's faces that look at the eye, those marked by
             * the leaves reached *)
            for k = n.first_surface to n.first_surface + n.num_surfaces - 1 do
              let s = m.surfaces.(k) in
              if
                s.visframe = v.framecount
                && ((s.back && d < -.backface_epsilon)
                   || ((not s.back) && d > backface_epsilon))
              then Edges.render_face e v m s flags None
            done;
            (* (all the faces of a node share a key: they are on one
             * plane, none hides another) *)
            v.currentkey <- v.currentkey + 1
          end;
          world_node e v m n.children.(1 - side) flags
        end
      end

let render_world (e : Edges.t) (v : View.t) (m : Model.t) : unit =
  v.modelorg <- v.origin;
  View.transform_frustum v;
  e.in_submodel <- false;
  e.current_entity <- 0;
  world_node e v m (submodel_root m 0) 15

(*****************************************************************************)
(* The brush models (R_DrawBEntitiesOnList) *)
(*****************************************************************************)

(* the box's sides of a plane: 1 in front, 2 behind, 3 both
 * (BOX_ON_PLANE_SIDE) *)
let box_side (mins : vec) (maxs : vec) (p : plane) : int =
  let n = p.normal in
  let near =
    {
      x = (if n.x >= 0. then mins.x else maxs.x);
      y = (if n.y >= 0. then mins.y else maxs.y);
      z = (if n.z >= 0. then mins.z else maxs.z);
    }
  in
  let far =
    {
      x = (if n.x >= 0. then maxs.x else mins.x);
      y = (if n.y >= 0. then maxs.y else mins.y);
      z = (if n.z >= 0. then maxs.z else mins.z);
    }
  in
  (if dot far n -. p.dist >= 0. then 1 else 0)
  lor if dot near n -. p.dist < 0. then 2 else 0

(* the node whose plane splits the box first, or the one leaf it is
 * in, among those seen (R_SplitEntityOnNode2) *)
let rec top_node (v : View.t) (mins : vec) (maxs : vec) (c : child) :
    child option =
  match c with
  | Leaf l ->
      if l.lvisframe = v.visframecount && l.contents <> Solid then Some c
      else None
  | Node n ->
      if n.nvisframe <> v.visframecount then None
      else begin
        let sides = box_side mins maxs n.nplane in
        if sides = 3 then Some c
        else
          top_node v mins maxs n.children.(if sides land 1 <> 0 then 0 else 1)
      end

(* a brush model's face cut by the world's planes, each piece in a leaf
 * drawn with that leaf's key (R_RecursiveClipBPoly) *)
let rec clip_bpoly (e : Edges.t) (v : View.t) (fa : surface) (clipflags : int)
    (origin : vec) (edges : (vec * vec) list) (c : child) : unit =
  match c with
  | Leaf l ->
      if l.lvisframe = v.visframecount && l.contents <> Solid then
        Edges.render_poly e v fa clipflags
          (fun (f : vec -> vec -> unit) ->
            List.iter (fun ((a, b) : vec * vec) -> f a b) edges)
          (Some l.key) false
  | Node n ->
      if n.nvisframe = v.visframecount then begin
        (* (the plane in the model's space: its origin moved) *)
        let p = n.nplane in
        let dist = p.dist -. dot origin p.normal in
        let side (q : vec) : int =
          if dot q p.normal -. dist > 0. then 0 else 1
        in
        let front = ref []
        and back = ref []
        and enter = ref None
        and exit = ref None in
        List.iter
          (fun ((a, b) : vec * vec) ->
            let sa = side a and sb = side b in
            if sa = sb then
              if sa = 0 then front := (a, b) :: !front
              else back := (a, b) :: !back
            else begin
              let da = dot a p.normal -. dist and db = dot b p.normal -. dist in
              let mid = add a (scale (da /. (da -. db)) (sub b a)) in
              let put (s : int) (x : vec * vec) : unit =
                if s = 0 then front := x :: !front else back := x :: !back
              in
              put sa (a, mid);
              put sb (mid, b);
              if sb = 0 then enter := Some mid else exit := Some mid
            end)
          edges;
        (* the cut's own edge, on both sides, opposite ways *)
        (match (!enter, !exit) with
        | Some en, Some ex ->
            front := (ex, en) :: !front;
            back := (en, ex) :: !back
        | _ -> ());
        if !front <> [] then
          clip_bpoly e v fa clipflags origin (List.rev !front) n.children.(0);
        if !back <> [] then
          clip_bpoly e v fa clipflags origin (List.rev !back) n.children.(1)
      end

let render_bmodels (e : Edges.t) (v : View.t) (m : Model.t)
    (entities : (int * int * vec) list) : unit =
  e.in_submodel <- true;
  List.iter
    (fun ((ent, k, origin) : int * int * vec) ->
      let sm = m.submodels.(k) in
      let mins = add origin sm.mins and maxs = add origin sm.maxs in
      v.modelorg <- v.origin;
      View.transform_frustum v;
      let clipflags = clip_box v mins maxs 15 in
      if clipflags >= 0 then
        match top_node v mins maxs (submodel_root m 0) with
        | None -> ()
        | Some top ->
            e.current_entity <- ent;
            (* the eye in the model's space, and the view's planes *)
            v.modelorg <- sub v.origin origin;
            View.transform_frustum v;
            for f = sm.first_face to sm.first_face + sm.num_faces - 1 do
              let s = m.surfaces.(f) in
              let p = s.plane in
              let d = dot v.modelorg p.normal -. p.dist in
              if
                (s.back && d < -.backface_epsilon)
                || ((not s.back) && d > backface_epsilon)
              then
                match top with
                | Leaf l -> Edges.render_face e v m s clipflags (Some l.key)
                | Node _ ->
                    let edges =
                      List.init s.num_edges (fun (i : int) ->
                          let k = m.surfedges.(s.first_edge + i) in
                          if k >= 0 then
                            (m.vertexes.(m.edge0.(k)), m.vertexes.(m.edge1.(k)))
                          else
                            ( m.vertexes.(m.edge1.(-k)),
                              m.vertexes.(m.edge0.(-k)) ))
                    in
                    clip_bpoly e v s clipflags origin edges top
            done)
    entities;
  e.in_submodel <- false;
  e.current_entity <- 0;
  v.modelorg <- v.origin;
  View.transform_frustum v
