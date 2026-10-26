(* Land: the ground around a course, a grid of heights drawn as two
 * triangles a cell, each one flat colour picked by its height and a
 * hash, then lit by the sun by its slope: hundreds of facets, no two
 * alike, which is what Virtua Racing's hills looked like.
 *
 * A height is the course's own hills and mountains (smooth bumps, some
 * with a flat top), the rolling of a fractal (Heightmap, diamond-square)
 * on top, the sea sunk -- and, near the road, the road's own height,
 * the land blending from it to its own over 50 meters: the road runs
 * along embankments and through cuttings, never over a hole or under a
 * hill (but where it is meant to: a bridge, a tunnel).
 *
 *        cutting                              embankment
 *   \                  road          _____________________
 *    \___ ___________==========_____/       road            \
 *        (the band: the land takes the road's height, then its own)
 *
 * The grid is cut in tiles of 8 by 8 cells, a mesh each with its
 * middle: the game draws the tiles near the eye, and the renderer
 * leaves out those outside the view (Render).
 *
 * Where it stands: Course makes a course's land from its road; Course
 * and the cars ask [height] to stand things on it.
 *
 * What is ours: the playground's TinyVirtuaRacing's, but for the hash
 * that picks a facet's colour (Heightmap.random, the same by both
 * compilers). *)

(* a hill at (x, y) on the map in metres, [radius] and [top] (a flat
 * top's radius) in metres too, [height] *)
type hill = { hx : float; hz : float; radius : float; height : float; top : float }

(* the land's colours: the lowlands', the higher slopes', the rock's;
 * and snow on the tops or not *)
type palette = {
  low : Mesh.color list;
  mid : Mesh.color list;
  rock : Mesh.color list;
  snow : bool;
}

val green : palette

type t = {
  x0 : float;
  z0 : float;
  cell : float;
  nx : int;
  nz : int;
  (* the corners' heights, (nx + 1) by (nz + 1), row after row *)
  heights : float array;
  (* a corner under the sea *)
  wet : bool array;
  palette : palette;
}

(* the road's samples: where (x, z), how high, and lifted off the land
 * (a bridge, a tunnel) or not *)
type sample = { sx : float; sz : float; sy : float; lifted : bool }

(* [make samples hills sea palette ground verge]: the grid over the
 * road's samples and a margin around; the land [ground] below the
 * road near it, blending to its own from [verge] *)
val make :
  sample array -> hill list -> (float * float) list list -> palette -> float -> float -> t

(* [height l x z]: the land at (x, z), its cell's four corners mixed *)
val height : t -> float -> float -> float

(* [tiles l water]: the land's tiles of 8 by 8 cells, each with its
 * middle (x, z); the sea at [water] over the wet cells *)
val tiles : t -> float -> ((float * float) * Mesh.shape) list

(* a point in a polygon (crossing number): the sea *)
val inside : (float * float) list -> float * float -> bool
