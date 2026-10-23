(* Inter: the fights' consequences (Doom's p_inter.c, and p_map.c's
 * attacks): a shot aimed, a bullet's line, a blast; the damage, the
 * pain, the death; the items picked up.
 *
 * A bullet is not a thing: it is a line from the shooter's middle
 * (P_LineAttack), all at once, through the openings of the two-sided
 * lines, until a wall or a thing:
 *
 *        shooter            the line ahead, its intercepts in order
 *      +---+                      |        |            |
 *      | o-|---------------------[two-sided]--(thing)---[wall]
 *      +---+    the slope: the    |  the bullet passes
 *               aim's, or 0       |  if it is within the opening
 *
 * The aim (P_AimLineAttack) is the same walk, done first: the slope to
 * the first thing seen within the view's height, the openings
 * narrowing what is seen; so the player aims up and down by itself,
 * Doom having no looking up. The hit makes a puff (a wall) or blood (a
 * thing), and damage: the target's health, the armor taking a third
 * (green) or a half (blue) of the player's; a monster hurt may flinch
 * (its pain chance), turns on who hurt it, and dies at 0 (P_KillMobj):
 * its death states, a clip or a shotgun dropped, the kills counted.
 *
 * Where it stands in mini-doom: Weapons and Enemy shoot through it;
 * Mobj's missiles hit through it; Play picks up the items it is on. *)

(* [damage t target inflictor source amount]: P_DamageMobj, P_KillMobj:
 * [inflictor] where the blow came from (it pushes), [source] who is
 * to blame (a monster turns on it) *)
val damage : World.t -> Things.target -> float * float -> Things.target -> int -> unit

(* [aim t shooter x y z angle range]: P_AimLineAttack: the slope to the
 * first thing in the view's height ahead, and it; else 0 and Nobody *)
val aim :
  World.t -> Things.target -> float -> float -> float -> float -> float ->
  float * Things.target

(* [line_attack t shooter x y z angle range slope amount]:
 * P_LineAttack: a bullet *)
val line_attack :
  World.t -> Things.target -> float -> float -> float -> float -> float ->
  float -> int -> unit

(* [radius_attack t spot source amount]: P_RadiusAttack: a blast, the
 * damage less the distance, to what it can see *)
val radius_attack : World.t -> Things.mobj -> Things.target -> int -> unit

(* [missile_hit t missile target]: PIT_CheckThing's: a missile's
 * damage, 1 to 8 times its info's *)
val missile_hit : World.t -> Things.mobj -> Things.target -> unit

(* P_TouchSpecialThing: the items the player is on, picked up *)
val touch_specials : World.t -> unit

(* the target's place and box (the player's, or a thing's): x, y, the
 * feet, the height *)
val where : World.t -> Things.target -> float * float * float * float
