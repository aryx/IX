(* Draws a list of Playground shapes into a framebuffer, using only the
 * from-scratch algorithms of graphics/ -- the software
 * rasterizer's counterpart of playground/platforms/native/Shape_render_native.ml,
 * which asks Cairo to do the same job. *)
(* ix: the author's playground's playground/platforms/software/Shape_render_software.mli (docs/plans/plan_playground.md) *)

(* ix: of the playground's options, the two that are not debug views;
 * render's options and scale are said (they were optional: the
 * defaults, and 1.); no render_region nor pixel_bounds. *)

(* Rendering features that can be turned on or off *)
type options = {
  (* false: no Porter-Duff blending; a faded shape is either drawn
   * fully opaque (alpha > 0) or not at all (alpha = 0) *)
  alpha_blending : bool;
  (* true: smooth edges, pixels partly covered drawn partly transparent
   * (Fill.polygons_aa, Line.draw_aa); false: all-or-nothing pixels,
   * "jaggies" *)
  antialiasing : bool;
}

(* blending on, antialiased *)
val default_options : options

(* [render ~options ~scale fb shapes]: the shapes drawn into [fb], the
 * playground's (0, 0) at its center; [scale] pixels per playground unit,
 * e.g. 0.48 to draw the 1000 units of a game's screen into a 480-wide
 * framebuffer *)
val render : options:options -> scale:float -> Framebuffer.t -> Playground.shape list -> unit
