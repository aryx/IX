(* Palette: the course's 256 colours, chosen from the colours its faces
 * are lit in, by Heckbert's median cut; and a face's colour, lit, to
 * its index.
 *
 * The picture is a byte a pixel (Playground.pixels, as mini-doom's and
 * mini-quake's), and the game's look is many colours: about 120 before
 * the light, and every face lit its own way by the sun after (the
 * hills a patchwork of facets, no two alike). So the palette is made
 * for each course, at its start, from what its faces will be:
 *
 *   1. every face's colour at its brightness ([add]: the brightness
 *      in [levels] steps, the colour's channels times the step);
 *   2. the box of all of them in (r, g, b) cut in two at the median of
 *      its longest side, then the box with the longest side of all
 *      again, until there are 256 boxes ([make]):
 *
 *        g ^  . .  .  |  .         each box's colour the mean of
 *          | .  . .   |    . .     its own, by how many faces
 *          |   .  .   |  .   .     have each
 *          +----------+--------> r
 *                  the median
 *
 *   3. a colour, lit, its nearest of the 256 ([index], kept once
 *      asked).
 *
 * Where it stands: the meshes' faces are added at the course's start
 * (Mesh.light then asks each face's index), and what moves (the
 * cars) is lit at each frame by [index] too.
 *
 * cs-history: Paul Heckbert's "Color Image Quantization for Frame
 * Buffer Display" (SIGGRAPH 1982) is the median cut; the hardware of
 * the time had 256 colours at most, as did VGA's mode 13h, where
 * Doom and Quake drew (their palettes fixed by hand, a ramp of each
 * colour towards black for the light). Sega's Model 1 had no palette
 * to choose: Virtua Racing's faces were shaded by its own processor.
 *
 * What is ours: a colour is lit in whole numbers (no float rounding,
 * the same bytes by OCaml and by mini-ml); a face counts once, however
 * large on the screen. *)

type t

(* the brightness's steps: 0 black to [levels] - 1 the colour itself *)
val levels : int

val create : unit -> t

(* [lit color brightness]: the colour at that brightness (0 to 1), as
 * drawn *)
val lit : Mesh.color -> float -> Mesh.color

(* [add p color brightness]: one more face in that colour, lit *)
val add : t -> Mesh.color -> float -> unit

(* [add_mesh p m]: [add] of each of m's faces, by the sun *)
val add_mesh : t -> Mesh.t -> unit

(* [add_all_levels p color]: the colour at every brightness: for what
 * turns (the cars), lit otherwise at each frame *)
val add_all_levels : t -> Mesh.color -> unit

(* [make p]: the 256 colours chosen from what was added *)
val make : t -> unit

(* the 256 colours as r g b bytes, 768 of them (Playground.pixels's) *)
val colors : t -> string

(* [index p color brightness]: the nearest of the 256 to that colour,
 * lit *)
val index : t -> Mesh.color -> float -> int
