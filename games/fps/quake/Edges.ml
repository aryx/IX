(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Edges.mli *)

open Model

type t = {
  u : int array;
  u_step : int array;
  surf_trail : int array;
  surf_lead : int array;
  next : int array;
  prev : int array;
  next_remove : int array;
  mutable num_edges : int;
  newedges : int array;
  removeedges : int array;
  key : int array;
  last_u : int array;
  spanstate : int array;
  snext : int array;
  sprev : int array;
  insubmodel : bool array;
  face : int array;
  entity : int array;
  nearzi : float array;
  zistepu : float array;
  zistepv : float array;
  ziorigin : float array;
  spans : int array;
  mutable num_surfaces : int;
  span_u : int array;
  span_v : int array;
  span_count : int array;
  span_next : int array;
  mutable num_spans : int;
  mutable in_submodel : bool;
  mutable current_entity : int;
  mutable lastvertvalid : bool;
  mutable u1 : float;
  mutable v1 : float;
  mutable lzi1 : float;
  mutable ceilv1 : int;
  mutable nearzi_face : float;
  mutable nearzi_only : bool;
  mutable emitted : bool;
  mutable left_clipped : bool;
  mutable right_clipped : bool;
  mutable left_enter : vec;
  mutable left_exit : vec;
  mutable right_enter : vec;
  mutable right_exit : vec;
}

let head = 0
let tail = 1
let after_tail = 2
let sentinel = 3
let background = 1
let shift = 16

(* (id's NUMSTACKEDGES and NUMSTACKSURFACES were 2,400 and 800; each
 * face here makes its own edges) *)
let max_edges = 8000
let max_surfaces = 3000
let max_spans = 16000

let create (height : int) : t =
  let ints (n : int) : int array = Array.make n 0
  and floats (n : int) : float array = Array.make n 0. in
  {
    u = ints max_edges;
    u_step = ints max_edges;
    surf_trail = ints max_edges;
    surf_lead = ints max_edges;
    next = ints max_edges;
    prev = ints max_edges;
    next_remove = ints max_edges;
    num_edges = 4;
    newedges = Array.make height (-1);
    removeedges = Array.make height (-1);
    key = ints max_surfaces;
    last_u = ints max_surfaces;
    spanstate = ints max_surfaces;
    snext = ints max_surfaces;
    sprev = ints max_surfaces;
    insubmodel = Array.make max_surfaces false;
    face = ints max_surfaces;
    entity = ints max_surfaces;
    nearzi = floats max_surfaces;
    zistepu = floats max_surfaces;
    zistepv = floats max_surfaces;
    ziorigin = floats max_surfaces;
    spans = Array.make max_surfaces (-1);
    num_surfaces = 2;
    span_u = ints max_spans;
    span_v = ints max_spans;
    span_count = ints max_spans;
    span_next = ints max_spans;
    num_spans = 0;
    in_submodel = false;
    current_entity = 0;
    lastvertvalid = false;
    u1 = 0.;
    v1 = 0.;
    lzi1 = 0.;
    ceilv1 = 0;
    nearzi_face = 0.;
    nearzi_only = false;
    emitted = false;
    left_clipped = false;
    right_clipped = false;
    left_enter = zero;
    left_exit = zero;
    right_enter = zero;
    right_exit = zero;
  }

let clear (e : t) : unit =
  e.num_edges <- 4;
  Array.fill e.newedges 0 (Array.length e.newedges) (-1);
  Array.fill e.removeedges 0 (Array.length e.removeedges) (-1);
  (* the background: the farthest, drawn where nothing else is *)
  e.key.(background) <- max_int;
  e.face.(background) <- -1;
  e.spans.(background) <- -1;
  e.insubmodel.(background) <- false;
  e.spanstate.(background) <- 0;
  e.num_surfaces <- 2;
  e.num_spans <- 0

(*****************************************************************************)
(* An edge (R_EmitEdge) *)
(*****************************************************************************)

(* a point projected: u, v (clamped to the screen), 1/z *)
let project (v : View.t) (p : vec) : float * float * float =
  let t = View.transform v (sub p v.modelorg) in
  (* (NEAR_CLIP: the clip by the view's planes leaves nothing behind
   * the eye, but a point on it) *)
  let z = Float.max t.z 0.01 in
  let lzi = 1. /. z in
  let clamp (lo : float) (hi : float) (x : float) : float =
    Float.max lo (Float.min hi x)
  in
  let u =
    clamp (-0.5) (float v.width -. 0.5) (v.xcenter +. (v.xscale *. lzi *. t.x))
  in
  let w =
    clamp (-0.5) (float v.height -. 0.5) (v.ycenter -. (v.yscale *. lzi *. t.y))
  in
  (u, w, lzi)

let emit_edge (e : t) (v : View.t) (pv0 : vec) (pv1 : vec) : unit =
  let u0, v0, lzi0, ceilv0 =
    if e.lastvertvalid then (e.u1, e.v1, e.lzi1, e.ceilv1)
    else begin
      let u0, v0, lzi0 = project v pv0 in
      (u0, v0, lzi0, int_of_float (Float.ceil v0))
    end
  in
  let u1, v1, lzi1 = project v pv1 in
  e.u1 <- u1;
  e.v1 <- v1;
  e.lzi1 <- lzi1;
  (* (the nearest of the face's points: its mip level) *)
  let lzi0 = Float.max lzi0 lzi1 in
  if lzi0 > e.nearzi_face then e.nearzi_face <- lzi0;
  if not e.nearzi_only then begin
    e.emitted <- true;
    e.ceilv1 <- int_of_float (Float.ceil v1);
    (* (a horizontal edge crosses no scanline's center) *)
    if ceilv0 <> e.ceilv1 && e.num_edges < Array.length e.u then begin
      let k = e.num_edges in
      e.num_edges <- k + 1;
      let surf = e.num_surfaces in
      let first, last, u, step =
        if ceilv0 < e.ceilv1 then begin
          (* going down: it trails *)
          e.surf_trail.(k) <- surf;
          e.surf_lead.(k) <- 0;
          let step = (u1 -. u0) /. (v1 -. v0) in
          (ceilv0, e.ceilv1 - 1, u0 +. ((float ceilv0 -. v0) *. step), step)
        end
        else begin
          (* going up: it leads, from v1 *)
          e.surf_trail.(k) <- 0;
          e.surf_lead.(k) <- surf;
          let step = (u0 -. u1) /. (v0 -. v1) in
          (e.ceilv1, ceilv0 - 1, u1 +. ((float e.ceilv1 -. v1) *. step), step)
        end
      in
      let one = float (1 lsl shift) in
      let w = float v.width in
      e.u_step.(k) <- int_of_float (Float.max (-.w) (Float.min w step) *. one);
      let lo = (1 lsl (shift - 1)) - 1 in
      (* (the pixel whose center is past u: + 0.99...) *)
      e.u.(k) <-
        max lo
          (min
             ((v.width lsl shift) + lo)
             (int_of_float (u *. one) + (1 lsl shift) - 1));
      (* sorted in its first scanline, a trailing edge after a leading
       * one at the same u *)
      let check = if e.surf_trail.(k) <> 0 then e.u.(k) + 1 else e.u.(k) in
      let h = e.newedges.(first) in
      if h < 0 || e.u.(h) >= check then begin
        e.next.(k) <- h;
        e.newedges.(first) <- k
      end
      else begin
        let p = ref h in
        while e.next.(!p) >= 0 && e.u.(e.next.(!p)) < check do
          p := e.next.(!p)
        done;
        e.next.(k) <- e.next.(!p);
        e.next.(!p) <- k
      end;
      e.next_remove.(k) <- e.removeedges.(last);
      e.removeedges.(last) <- k
    end
  end

(*****************************************************************************)
(* Its clips (R_ClipEdge) *)
(*****************************************************************************)

let rec clip_edge (e : t) (v : View.t) (pv0 : vec) (pv1 : vec)
    (planes : int list) : unit =
  match planes with
  | [] -> emit_edge e v pv0 pv1
  | i :: rest ->
      let c = v.clips.(i) in
      let d0 = dot pv0 c.cnormal -. c.cdist
      and d1 = dot pv1 c.cnormal -. c.cdist in
      let cut () : vec =
        let f = d0 /. (d0 -. d1) in
        add pv0 (scale f (sub pv1 pv0))
      in
      if d0 >= 0. then begin
        if d1 >= 0. then clip_edge e v pv0 pv1 rest
        else begin
          (* it leaves the view here *)
          let p = cut () in
          if i = 0 then begin
            e.left_clipped <- true;
            e.left_exit <- p
          end
          else if i = 1 then begin
            e.right_clipped <- true;
            e.right_exit <- p
          end;
          clip_edge e v pv0 p rest
        end
      end
      else if d1 >= 0. then begin
        (* it enters the view here *)
        e.lastvertvalid <- false;
        let p = cut () in
        if i = 0 then begin
          e.left_clipped <- true;
          e.left_enter <- p
        end
        else if i = 1 then begin
          e.right_clipped <- true;
          e.right_enter <- p
        end;
        clip_edge e v p pv1 rest
      end

(*****************************************************************************)
(* A face (R_RenderFace) *)
(*****************************************************************************)

(* a face's edges, given by [iter] (each from vertex a to vertex b,
 * clockwise), clipped and filed; its surface made, of the key given
 * or the next (R_RenderFace, R_RenderBmodelFace) *)
let render_poly (e : t) (v : View.t) (fa : surface) (clipflags : int)
    (iter : (vec -> vec -> unit) -> unit) (key : int option) (chained : bool) :
    unit =
  if
    e.num_surfaces < Array.length e.key
    && e.num_edges + fa.num_edges + 8 < Array.length e.u
  then begin
    let planes =
      List.filter
        (fun (i : int) -> clipflags land (1 lsl i) <> 0)
        [ 0; 1; 2; 3 ]
    in
    e.emitted <- false;
    e.nearzi_face <- 0.;
    e.nearzi_only <- false;
    e.lastvertvalid <- false;
    let make_left = ref false and make_right = ref false in
    iter (fun (a : vec) (b : vec) ->
        e.left_clipped <- false;
        e.right_clipped <- false;
        clip_edge e v a b planes;
        if e.left_clipped then make_left := true;
        if e.right_clipped then make_right := true;
        (* (the next edge starts where this one ended: its first point
         * already projected) *)
        e.lastvertvalid <- chained);
    (* the left border's edge, where the face went out of the view and
     * came back; the right's, only for the nearest 1/z *)
    if !make_left then begin
      e.lastvertvalid <- false;
      clip_edge e v e.left_exit e.left_enter
        (List.filter (fun (i : int) -> i <> 0) planes)
    end;
    if !make_right then begin
      e.lastvertvalid <- false;
      e.nearzi_only <- true;
      clip_edge e v e.right_exit e.right_enter
        (List.filter (fun (i : int) -> i > 1) planes)
    end;
    if e.emitted then begin
      let s = e.num_surfaces in
      e.num_surfaces <- s + 1;
      e.face.(s) <- fa.index;
      e.nearzi.(s) <- e.nearzi_face;
      e.insubmodel.(s) <- e.in_submodel;
      e.entity.(s) <- e.current_entity;
      e.spanstate.(s) <- 0;
      (match key with
      | Some k -> e.key.(s) <- k
      | None ->
          e.key.(s) <- v.currentkey;
          v.currentkey <- v.currentkey + 1);
      e.spans.(s) <- -1;
      (* 1/z on the screen: the plane's distance from the eye seen
       * through each pixel *)
      let p = fa.plane in
      let n = View.transform v p.normal in
      let distinv = 1. /. (p.dist -. dot v.modelorg p.normal) in
      e.zistepu.(s) <- n.x *. v.xscaleinv *. distinv;
      e.zistepv.(s) <- -.n.y *. v.yscaleinv *. distinv;
      e.ziorigin.(s) <-
        (n.z *. distinv)
        -. (v.xcenter *. e.zistepu.(s))
        -. (v.ycenter *. e.zistepv.(s))
    end
  end

let render_face (e : t) (v : View.t) (m : Model.t) (fa : surface)
    (clipflags : int) (key : int option) : unit =
  render_poly e v fa clipflags
    (fun (f : vec -> vec -> unit) ->
      for i = 0 to fa.num_edges - 1 do
        let k = m.surfedges.(fa.first_edge + i) in
        if k >= 0 then f m.vertexes.(m.edge0.(k)) m.vertexes.(m.edge1.(k))
        else f m.vertexes.(m.edge1.(-k)) m.vertexes.(m.edge0.(-k))
      done)
    key true
