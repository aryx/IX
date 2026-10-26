(* Mesh: the scene's solids, written as the playground's 3D writes them
 * (polygon3d, box, group3d, move3d, rotate3d, scale3d), and made once
 * into arrays that a frame reads without building anything.
 *
 * A shape is a list of flat faces, each a colour and its corners,
 * counterclockwise as seen from outside (the face's front: the side
 * its normal points to, by Newell's method, Vec3.face_normal):
 *
 *     polygon3d red [ a; b; c; d ]          d +-------+ c
 *                                             |       |    seen from
 *     box red 2. 1. 1.: six of them,          |  -->  |    its front:
 *     each wound the same way                 |       |    a b c d go
 *                                           a +-------+ b  counterclockwise
 *
 * and [make] turns a shape into a mesh: the corners of all its faces
 * in three Float.Array (x, y, z), where face k's are [first.(k)] to
 * [first.(k + 1) - 1]; each face's colour and normal; a sphere around
 * it all (the renderer's test of whether the mesh is in view at all).
 * The colour a face is drawn in, its palette's index once lit by the
 * sun ([light]), is computed once too, for a mesh that never moves.
 *
 *   the playground's TinyVirtuaRacing          here
 *   a frame:  the scene's lists of shapes,     a frame:  the meshes in
 *             walked, every face made a                  view, their arrays
 *             triangle with closures                     read (Render)
 *
 * The survey (plan_virtuaracing.md) found the playground's frame a
 * third the GC and the lists: the scene was made again at each frame
 * from its groups. A mesh is made at the course's start.
 *
 * What is ours: the shapes' functions are the playground's
 * (Playground3d), so the courses read as TinyVirtuaRacing's; a shape is
 * only a list of faces here (no texture, no alpha, no cache: the game
 * has none of them), its transforms applied to the points at once, as
 * there. *)

(* 0xRRGGBB *)
type color = int

val rgb : int -> int -> int -> color
val white : color
val black : color
val red : color
val yellow : color

(* the colours of the rainbow, the playground's (Playground.rainbow) *)
val rainbow : color list

(*****************************************************************************)
(* Shapes *)
(*****************************************************************************)

type shape

(* [polygon3d color points]: one flat face, at least three points,
 * counterclockwise seen from its front *)
val polygon3d : color -> Vec3.t list -> shape

val group3d : shape list -> shape

(* [box color width height depth]: centered on the origin, its six
 * faces outward *)
val box : color -> float -> float -> float -> shape

val move3d : float -> float -> float -> shape -> shape
val move_x3d : float -> shape -> shape
val move_y3d : float -> shape -> shape

(* [rotate3d ax ay az shape]: degrees around the origin, first around
 * x, then y, then z *)
val rotate3d : float -> float -> float -> shape -> shape

(* [scale3d s shape]: s times larger, from the origin *)
val scale3d : float -> shape -> shape

val is_empty : shape -> bool

(*****************************************************************************)
(* Meshes *)
(*****************************************************************************)

type t = {
  xs : Float.Array.t;
  ys : Float.Array.t;
  zs : Float.Array.t;
  (* face k's corners: first.(k) to first.(k + 1) - 1; one more than
   * the faces *)
  first : int array;
  colors : color array;
  (* the faces' unit normals, x, y and z *)
  nxs : Float.Array.t;
  nys : Float.Array.t;
  nzs : Float.Array.t;
  (* each face's palette index, lit by the sun ([light]) *)
  shades : Bytes.t;
  (* the sphere around the corners: its center and radius *)
  cx : float;
  cy : float;
  cz : float;
  radius : float;
}

val make : shape -> t

(* the number of faces *)
val faces : t -> int

(* [light m index]: each face's shade, [index color brightness] (the
 * palette's), its brightness the sun's on its normal (Lighting) *)
val light : t -> (color -> float -> int) -> unit
