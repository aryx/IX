(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Render.mli *)

type t = {
  view : View.t;
  edges : Edges.t;
  spans : Spans.t;
  cache : Surfcache.t;
}

let width = 320
let height = 200

let create (m : Model.t) (colormap : string) : t =
  {
    view = View.create colormap width height;
    edges = Edges.create height;
    spans = Spans.create m;
    cache = Surfcache.create ();
  }

let frame (r : t) (m : Model.t) (eye : Model.vec) (pitch : float) (yaw : float)
    (time : float) (styles : string array)
    (bmodels : (int * int * Model.vec * int) list) (things : Things.thing list)
    : unit =
  let v = r.view in
  v.time <- time;
  View.animate_lights v styles;
  View.setup v eye pitch yaw;
  Bsp.mark_leaves v m (Model.leaf_at m eye);
  Edges.clear r.edges;
  v.currentkey <- 0;
  Bsp.render_world r.edges v m;
  Bsp.render_bmodels r.edges v m
    (List.map
       (fun ((ent, k, o, _) : int * int * Model.vec * int) -> (ent, k, o))
       bmodels);
  (* the entities' origins and frames, by their numbers *)
  let n =
    List.fold_left
      (fun (n : int) ((ent, _, _, _) : int * int * Model.vec * int) ->
        max n (ent + 1))
      1 bmodels
  in
  let origins = Array.make n Model.zero and frames = Array.make n 0 in
  List.iter
    (fun ((ent, _, o, f) : int * int * Model.vec * int) ->
      origins.(ent) <- o;
      frames.(ent) <- f)
    bmodels;
  Scan.scan_edges r.edges v (fun () ->
      Spans.draw r.spans r.edges v m r.cache origins frames);
  (* the models, over the world, by its z-buffer *)
  Things.draw v m things time
