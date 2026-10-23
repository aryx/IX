(* Items: what the player picks up (Quake's items.qc): the weapons and
 * armor standing in the level (Things), and the backpacks the dead
 * drop.
 *
 * An item is a trigger: a box touched when the player's box overlaps
 * it. A weapon gives itself and some ammunition (the super shotgun 5
 * shells, the nailgun 30 nails, the launchers 5 rockets), and is
 * switched to if it is better than the one in hand; an armor is taken
 * only if it is worth more than the one worn (its points times the
 * part of the damage it takes: green 100 x 0.3, yellow 150 x 0.6); a
 * backpack gives what its owner had.
 *
 * Not here: the health and ammunition boxes and the exploding box:
 * QuakeC made them brush models of their own (maps/b_*.bsp), not
 * compiled here (plan_quake.md).
 *
 * Where it stands in mini-quake: Game asks it each frame; Monster_ai drops the
 * backpacks. *)

(* [touch_things w things]: the level's items the player is on, taken *)
val touch_things : Edict.world -> Things.thing list -> unit

(* [drop_backpack w e]: DropBackpack: its shells, tossed up *)
val drop_backpack : Edict.world -> Edict.t -> unit

(* the weapons, best last (W_BestWeapon's order) *)
val rank : Edict.weapon -> int
