(* View: the renderer's state and what all its parts share (Quake's
 * r_main.c, r_misc.c, r_local.h, d_local.h): the picture and its
 * colormap, the eye and its axes, the projection, the four planes of
 * the view, the frame's counters, the light styles' values.
 *
 * The eye looks along vpn (forward), vright and vup its other axes;
 * a point is seen at
 *
 *     x = dot (p - origin) vright, y = ... vup, z = ... vpn
 *     u = xcenter + xscale x / z,  v = ycenter - yscale y / z
 *
 * xscale is the width over the field of view's 2 tan (fov / 2): 160
 * for 90 degrees at 320 wide. Quake drew 320 by 200 for a 4:3 screen,
 * its pixels taller than wide (yscale = xscale x 0.83); this picture
 * is shown with square pixels, so yscale = xscale.
 *
 *              left plane          right plane
 *                   \                 /     the four planes through the
 *                    \   in view     /      eye, their normals inward:
 *                     \             /       a box wholly inside one
 *                      \           /        needs no clip by it, wholly
 *                       \         /         outside is not drawn
 *                           eye
 *
 * Where it stands in mini-quake: Render makes one (create) and sets
 * the eye each frame (setup); Bsp, Edges, Scan, Surfcache and Spans
 * all read it. *)

(* a plane of the view: its normal in the world, its distance *)
type clip = { mutable cnormal : Model.vec; mutable cdist : float }

type t = {
  width : int;
  height : int;
  (* the picture, a byte of the palette a pixel *)
  screen : Bytes.t;
  (* 1/z of each pixel, x 2^24: the world's spans write it, the models
   * read it (Alias) *)
  zbuffer : int array;
  (* 64 rows of 256: row 0 the brightest, 32 the colours as they are,
   * 63 the darkest; the last 32 colours (fullbright) the same in all *)
  colormap : string;
  (* the projection (R_ViewChanged) *)
  xcenter : float;
  ycenter : float;
  xscale : float;
  yscale : float;
  xscaleinv : float;
  yscaleinv : float;
  (* the view's planes in its own space: left, right, top, bottom *)
  screenedge : Model.vec array;
  (* the eye (R_SetupFrame) *)
  mutable origin : Model.vec;
  mutable vpn : Model.vec;
  mutable vright : Model.vec;
  mutable vup : Model.vec;
  (* the eye in the space of the model drawn: the world's, or a brush
   * model's (a door: its origin moved) *)
  mutable modelorg : Model.vec;
  (* the planes in the world (R_TransformFrustum), and for each, which
   * corner of a box is the farthest in and the farthest out
   * (R_SetUpFrustumIndexes: 0 the min, 1 the max of each axis) *)
  clips : clip array;
  frustum_indexes : int array array;
  mutable framecount : int;
  mutable visframecount : int;
  mutable oldviewleaf : int;
  (* the order of what the walk reaches, front to back: a surface's or
   * a leaf's key *)
  mutable currentkey : int;
  (* each light style's value, 256 the light as baked ('m': 264) *)
  lightstyles : int array;
  (* the time, in seconds: the textures' animations, the water, the sky *)
  mutable time : float;
}

(* [create colormap width height] *)
val create : string -> int -> int -> t

(* [setup v origin pitch yaw]: the eye there, looking that way
 * (degrees; pitch down positive, as Quake's), the planes moved *)
val setup : t -> Model.vec -> float -> float -> unit

(* [transform v p]: a direction in the eye's axes (TransformVector) *)
val transform : t -> Model.vec -> Model.vec

(* [transform_frustum v]: the planes again, for v.modelorg *)
val transform_frustum : t -> unit

(* [angle_vectors pitch yaw]: forward, right, up (AngleVectors) *)
val angle_vectors : float -> float -> Model.vec * Model.vec * Model.vec

(* [minmax mins maxs k]: coordinate k (0 to 5: the mins then the
 * maxs, x y z) of a box, as id's minmaxs *)
val minmax : Model.vec -> Model.vec -> int -> float

(* world.qc's light styles: the strings, a letter a tenth of a second,
 * 'a' dark, 'm' normal, 'z' twice as bright *)
val styles : (int * string) list

(* [animate_lights v strings]: the styles' values at v.time
 * (R_AnimateLight); strings the styles said so far (by the level's
 * switches too) *)
val animate_lights : t -> string array -> unit
