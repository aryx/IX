(* Bspfile: Quake's level file, a .bsp of version 29 (id's bspfile.h),
 * as its fifteen lumps' bytes. What qbsp writes, vis and light add to,
 * and the game reads:
 *
 *   0   the version, 29
 *   4   fifteen (offset, length) pairs, a lump each:
 *         0 ENTITIES   the map's entities, as text ("classname" ...)
 *         1 PLANES     20 bytes: a normal (3 floats), its distance,
 *                      its type (an axis, or none)
 *         2 TEXTURES   the miptex: each texture and its 3 smaller mips
 *         3 VERTEXES   3 floats
 *         4 VISIBILITY the PVS, each leaf's row of bits run-length
 *                      coded (vis's)
 *         5 NODES      24 bytes: a plane, two children, a box, faces
 *         6 TEXINFO    40 bytes: how a texture lies on a face
 *         7 FACES      20 bytes: a plane, its edges, a texinfo, four
 *                      light styles and where its lightmaps are
 *         8 LIGHTING   the lightmaps, a byte a sample (light's)
 *         9 CLIPNODES  8 bytes: the hulls the bodies move in
 *        10 LEAFS      28 bytes: contents, its row of the PVS, a box,
 *                      its faces
 *        11 MARKSURFACES  a leaf's faces, shorts
 *        12 EDGES      two vertices' numbers
 *        13 SURFEDGES  a face's edges, signed: -e is e backwards
 *        14 MODELS     64 bytes: the world (0), then the brush models
 *                      (doors, lifts), each its own tree
 *
 * Every number little-endian; floats IEEE single.
 *
 * Where it stands in mini-quake: what Model reads, and what
 * tools/Light.ml reads and writes again with its lightmaps.
 *
 * history:
 * id's format for Quake (1996), version 29; Half-Life's is 30 (colours
 * in the lightmaps, the textures' palettes), Quake II's IBSP 38,
 * Quake III's 46. ericw-tools' "BSP2" lifts its limits of shorts. *)

type t = { version : int; lumps : string array }

(* the lumps' numbers *)
val entities : int
val planes : int
val textures : int
val vertexes : int
val visibility : int
val nodes : int
val texinfo : int
val faces : int
val lighting : int
val clipnodes : int
val leafs : int
val marksurfaces : int
val edges : int
val surfedges : int
val models : int

(* [parse bytes]: a .bsp's lumps; Failure if it is not of version 29 *)
val parse : string -> t

(* [write bsp]: the file again, its lumps in their order *)
val write : t -> string

(* the numbers in a lump, at an offset: an unsigned byte, a short
 * (signed), an unsigned short, an int of 32 bits (signed; on 31-bit
 * ints only the small ones are right, every offset and count of a
 * .bsp), a float of 32 bits, and a name of [n] bytes, its zeros cut *)
val u8 : string -> int -> int
val short : string -> int -> int
val ushort : string -> int -> int
val int32 : string -> int -> int
val float32 : string -> int -> float
val name : string -> int -> int -> string

(* the same, written into a Buffer *)
val add_short : Buffer.t -> int -> unit
val add_int32 : Buffer.t -> int -> unit
val add_name : Buffer.t -> int -> string -> unit
