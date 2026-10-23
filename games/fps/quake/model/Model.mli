(* Model: a Quake level, its .bsp's lumps made records (id's model.c,
 * Mod_LoadBrushModel), what the renderer, the hulls and light walk.
 *
 * A level is a BSP tree of 3D space: each node a plane, each side a
 * child, down to the leaves, convex pieces of space that are empty
 * (air), water, slime, lava, sky or solid rock:
 *
 *         node: z = 64
 *         /          \
 *    node: x = 0     leaf: solid
 *     /       \
 *   leaf:    leaf:          a face lies on its node's plane, and the
 *   empty    water          leaves it is seen from list it (marks)
 *
 * The faces are polygons, each a loop of edges (surfedges: an edge's
 * number, negative when it is walked backwards), a texinfo (how the
 * texture lies on it: s and t of a point are dot products, and the
 * texture repeats), and lightmaps: a byte every 16 texels, the face's
 * extents rounded out to 16s, one map a light style.
 *
 *     texturemins (s, t) +----16----+----------+
 *                        |  x       x          x   a sample of the
 *                        16         |          |   lightmap at each
 *                        |  x       x          x   corner of the 16 by
 *                        +----------+----------+   16 blocks: (extents
 *                           x       x          x   / 16 + 1) squared
 *
 * Besides the tree drawn (hull 0, the nodes), the bodies move in
 * clipnodes: the same space with the walls pushed out by a box's size,
 * so a box is traced as a point (Trace): hull 1 the player's (32 by 32
 * by 56), hull 2 a big monster's (64 by 64 by 88).
 *
 * Model 0 is the world; the others are brush models, the doors, lifts
 * and buttons, each a tree of its own, moved by the game.
 *
 * Where it stands in mini-quake: made once from Bspfile; everything
 * else reads it. Its mutable fields are the frame's marks
 * (visframe, key), as id's.
 *
 * history:
 * id's (1996); the tree is the BSP of Fuchs, Kedem and Naylor (1980),
 * of 3D space, built by qbsp from the map's brushes; Doom's was of 2D
 * (mini-doom's Level). *)

type vec = { x : float; y : float; z : float }

(* a plane: the points p with dot normal p = dist; kind 0, 1, 2 when
 * the normal is the x, y, z axis (a test of one coordinate) *)
type plane = { normal : vec; dist : float; kind : int }
type contents = Empty | Solid | Water | Slime | Lava | Sky | Other of int

(* a texture and its four mips, a byte a pixel; an animation's frames
 * (+0name, +1name ...: two tenths of a second each) and its other set
 * (+aname ...: a button pressed) *)
type texture = {
  tname : string;
  width : int;
  height : int;
  mips : string array;
  mutable anim_total : int;
  mutable anim_min : int;
  mutable anim_max : int;
  mutable anim_next : texture option;
  mutable alternate : texture option;
}

(* how a texture lies on a face: s = dot s point + s_offset, the same
 * for t; special: the sky or a liquid, no lightmap *)
type texinfo = {
  s : vec;
  s_offset : float;
  t : vec;
  t_offset : float;
  texture : texture;
  special : bool;
}

type kind = Normal | Sky | Turbulent

type surface = {
  index : int;
  plane : plane;
  (* the face's front is the plane's back *)
  back : bool;
  first_edge : int;
  num_edges : int;
  texinfo : texinfo;
  kind : kind;
  (* where the face's texture starts, rounded down to 16s, and its size
   * rounded out to them (s, t) *)
  texturemins : int * int;
  extents : int * int;
  (* the light styles of its lightmaps (255: none), and where the first
   * is in the lighting (-1: none) *)
  styles : int array;
  samples : int;
  mutable visframe : int;
}

type node = {
  nplane : plane;
  children : child array;
  (* the box, as shorts *)
  nmins : vec;
  nmaxs : vec;
  first_surface : int;
  num_surfaces : int;
  mutable nvisframe : int;
  mutable nparent : node option;
}

and leaf = {
  lindex : int;
  contents : contents;
  (* where its row of the PVS is in the visibility (-1: none) *)
  visofs : int;
  lmins : vec;
  lmaxs : vec;
  marks : surface array;
  mutable lvisframe : int;
  (* the order it was reached in this frame: its faces' and models' *)
  mutable key : int;
  mutable lparent : node option;
}

and child = Node of node | Leaf of leaf

(* a hull: clipnodes, each a plane and two children, a child >= 0 a
 * clipnode and < 0 contents (-1 empty, -2 solid ...) *)
type hull = {
  cplanes : plane array;
  front : int array;
  back : int array;
  (* the box the hull is for, around a body's origin *)
  clip_mins : vec;
  clip_maxs : vec;
}

(* a model's box, its trees' roots (a hull each: 0 the nodes, 1 and 2
 * clipnodes), its leaves in the PVS (the world's), its faces *)
type submodel = {
  mins : vec;
  maxs : vec;
  origin : vec;
  headnode : int array;
  visleafs : int;
  first_face : int;
  num_faces : int;
}

type t = {
  vertexes : vec array;
  (* edge e from vertex edge0.(e) to edge1.(e) *)
  edge0 : int array;
  edge1 : int array;
  surfedges : int array;
  planes : plane array;
  textures : texture option array;
  surfaces : surface array;
  nodes : node array;
  leaves : leaf array;
  (* hull 0 made of the nodes (Mod_MakeHull0), hulls 1 and 2 qbsp's *)
  hulls : hull array;
  submodels : submodel array;
  visibility : string;
  lighting : string;
  entities : (string * string) list list;
}

val load : Bspfile.t -> t

(* [contents_of k]: a leaf's or a clipnode's contents number *)
val contents_of : int -> contents

(* [child m k]: a node's child as the .bsp numbers it (>= 0 a node,
 * else leaf -1 - k) *)
val child : t -> int -> child

(* [submodel_root m k]: the root of model k's tree *)
val submodel_root : t -> int -> child

(* [leaf_at m p]: the leaf of the world point p is in (Mod_PointInLeaf) *)
val leaf_at : t -> vec -> leaf

(* [pvs m leaf]: the leaves seen from it (Mod_LeafPVS): bit i of the
 * string is leaf i + 1; all of them when vis was not run *)
val pvs : t -> leaf -> Bytes.t

(* [vertex m surface i]: the i-th corner of a face, in its edges'
 * order *)
val vertex : t -> surface -> int -> vec

(* the entities' text parsed: each a list of (key, value) *)
val parse_entities : string -> (string * string) list list
val value : (string * string) list -> string -> string option

(* vectors *)
val dot : vec -> vec -> float
val add : vec -> vec -> vec
val sub : vec -> vec -> vec
val scale : float -> vec -> vec
val length : vec -> float
val normalize : vec -> vec
val cross : vec -> vec -> vec
val zero : vec

(* [vec_of_string "x y z"] *)
val vec_of_string : string -> vec
