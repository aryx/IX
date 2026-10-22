(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Render.mli *)

type t = View.t

let create = View.create

let screen (r : View.t) : Bytes.t = r.screen
let width (r : View.t) : int = r.width
let height (r : View.t) : int = r.height
let segs_drawn (r : View.t) : int = r.segs
let planes_drawn (r : View.t) : int = r.nplanes

(* R_RenderView *)
let frame (r : View.t) (level : Level.t) (textures : Textures.t) (sprites : Things.sprites) (things : Things.mobj list array) (tic : int)
    (x : float) (y : float) (z : float) (angle : float) : unit =
  r.viewx <- x;
  r.viewy <- y;
  r.viewz <- z;
  r.viewangle <- View.norm angle;
  r.segs <- 0;
  r.nplanes <- 0;
  r.drawsegs <- [];
  r.vissprites <- [];
  r.frame_number <- r.frame_number + 1;
  if Array.length r.sector_seen <> Array.length level.sectors then r.sector_seen <- Array.make (Array.length level.sectors) (-1);
  r.solidsegs <- [];
  Array.fill r.ceilingclip 0 r.width (-1);
  Array.fill r.floorclip 0 r.width r.height;
  Bsp.render_node r textures level sprites things tic (Level.root level);
  Planes.draw_planes r textures;
  Sprites.draw_masked r textures level
