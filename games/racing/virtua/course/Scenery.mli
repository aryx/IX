(* Scenery: the solids the courses are built of, and the things that
 * stand along them: pines, signs, the start's gantry and grandstand,
 * the amusement park's Ferris wheel and roller coaster.
 *
 * Each is a few flat faces, wound counterclockwise as seen from
 * outside (Mesh): flat shading lights a face from its normal, and a
 * face wound backwards is lit from inside, black in the sun. The
 * solids are made from sections ([loft]: a section at one z, another
 * at the next, the sides between):
 *
 *        b (at z1)                 a car's nose: a small section at
 *       +-----+                    its tip, a larger one at the tub;
 *      /|    /|                    a wheel: the same octagon twice
 *     +-----+ |   the sides, a
 *     | +---|-+   quad each, and
 *     |/    |/    the two ends
 *     +-----+
 *       a (at z0)
 *
 * Virtua Racing's courses were famous for these landmarks, each a heap
 * of polygons no sprite game could have turned around.
 *
 * Where it stands: Course places them along the road and on the land;
 * Cars builds the cars with [loft] and [wheel].
 *
 * What is ours: the playground's TinyVirtuaRacing's shapes, those Big
 * Forest has (Bay Bridge's and Acropolis' come with them, at
 * plan_virtuaracing.md's stage 3); [jitter] a hash of our own
 * (Heightmap.random), not OCaml's Hashtbl.hash, whose numbers are not
 * the same by mini-ml: so the trees are not where the playground's
 * are. *)

(* [jitter i k]: a number in [0, 1) for the k-th thing at i: the
 * scenery is the same at every run *)
val jitter : int -> int -> float

(* [loft color a b z0 z1]: a solid from the section [a] at [z0] to the
 * section [b] at [z1] (z1 > z0), both lists of (x, y), the same length,
 * counterclockwise seen from +z *)
val loft :
  Mesh.color -> (float * float) list -> (float * float) list -> float -> float ->
  Mesh.shape

(* [ring sides r]: a regular polygon, counterclockwise *)
val ring : int -> float -> (float * float) list

(* [wheel color sides r w]: [sides] around, [w] wide, its axle along x *)
val wheel : Mesh.color -> int -> float -> float -> Mesh.shape

(* [cone seed snow color sides r h]: a peak on the ground, its facets
 * each one flat colour; the top [snow] of its height (0: none) white *)
val cone : int -> float -> Mesh.color -> int -> float -> float -> Mesh.shape

(* a pine, the k-th: a trunk and two cones *)
val pine : int -> Mesh.shape

(* the k-th pine seen from far (Course's far chunks): one cone of five
 * faces, as tall, where the pine has seventeen *)
val pine_far : int -> Mesh.shape

(* [column color sides r h]: a column of [sides] faces round, its top
 * capped; [roof color w h d]: a gable roof lofted along its depth *)
val column : Mesh.color -> int -> float -> float -> Mesh.shape
val roof : Mesh.color -> float -> float -> float -> Mesh.shape

(* Bay Bridge's palms (by the sea), Acropolis' cypresses and rocks; [k]
 * their seed (Scenery.jitter) *)
val palm : int -> Mesh.shape
val cypress : int -> Mesh.shape
val rock : int -> Mesh.shape

(* a sign by the road, every 150 segments *)
val sign : Mesh.shape

(* a chevron board on the outside of a sharp curve *)
val chevron : Mesh.shape

(* the grandstand at the start, along z, the road on its +x side; its
 * steps down to [ground], the land beside the road *)
val grandstand : float -> Mesh.shape

(* [gantry color half]: over a road [half] wide on each side: the
 * start's (blue), a checkpoint's (yellow) *)
val gantry : Mesh.color -> float -> Mesh.shape

(* [ferris_wheel angle]: turned [angle] degrees, its cars hanging
 * level *)
val ferris_wheel : float -> Mesh.shape

val roller_coaster : Mesh.shape

(* Bay Bridge's windmills, their sails at [angle]; its lighthouse *)
val windmill : float -> Mesh.shape
val lighthouse : Mesh.shape

(* Acropolis': a sailing boat in its sea, the ruins on their hill, a
 * house of the mountainside ([k] its seed) *)
val sailboat : Mesh.shape
val temple : Mesh.shape
val house : int -> Mesh.shape
