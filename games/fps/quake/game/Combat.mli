(* Combat: what a hit does (Quake's combat.qc: T_Damage, Killed,
 * T_RadiusDamage, CanDamage; player.qc's pain and death; ThrowGib).
 *
 * T_Damage: the armor takes its part first (green 30%, yellow 60%, as
 * long as it has points), the rest comes off the health; the blow
 * pushes the player away from where it came (its damage times 8 units
 * a second: a rocket jump is this); a monster hurt turns on who hurt
 * it, even another monster (but not one of its own kind, the soldiers
 * apart: infighting), then flinches (its kind's pain: a frame
 * sequence, at most so often). At 0 it dies: far below 0 (its kind's
 * gib health) it bursts into gibs and a head, else its death frames.
 *
 * A blast (T_RadiusDamage: a rocket, a grenade) hurts every box it
 * can reach (CanDamage: a line to its middle or a corner the level
 * does not cut), its damage less half the distance, the shooter's own
 * halved.
 *
 * Where it stands in mini-quake: Weapons' and Monsters' attacks call
 * it. *)

(* [damage w target from attacker amount]: T_Damage, [from] where the
 * blow came from *)
val damage : Edict.world -> Edict.who -> Model.vec -> Edict.who -> float -> unit

(* [radius_damage w origin attacker amount ignore]: T_RadiusDamage *)
val radius_damage :
  Edict.world -> Model.vec -> Edict.who -> float -> Edict.who -> unit

(* [explode w e]: a rocket's or a grenade's end where it is: the blast
 * (120), its sound, its particles, removed *)
val explode : Edict.world -> Edict.t -> unit

(* [fire_bullets w shooter src dir n (sx, sy)]: FireBullets: n
 * pellets of 4 damage, spread (QuakeC's '0.1 0.1 0') *)
val fire_bullets :
  Edict.world ->
  Edict.who ->
  Model.vec ->
  Model.vec ->
  int ->
  float * float ->
  unit

(* [launch w owner classname model src dir speed touch]: a missile *)
val launch :
  Edict.world ->
  Edict.who ->
  string ->
  string ->
  Model.vec ->
  Model.vec ->
  float ->
  (Edict.world -> Edict.t -> Edict.who -> unit) ->
  Edict.t
