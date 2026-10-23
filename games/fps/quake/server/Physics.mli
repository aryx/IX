(* Physics: how the entities move (Quake's sv_phys.c and sv_move.c, and
 * world.c's SV_Move with the entities).
 *
 * A move is a trace: the entity's box from where it is to where it
 * would be, through the level (Trace, the hull its size picks: a point
 * for a missile, the player's for a monster) and through the other
 * solid entities' boxes; the nearest impact wins, and what was hit
 * is touched (SV_Impact: the rocket's touch explodes it).
 *
 *   Toss, Bounce   gravity (800 a second, squared), the trace; on a
 *                  plane the velocity loses its part into it, a bounce
 *                  half of it back again (backoff 1.5: a grenade jumps
 *                  off walls), and a floor stops it once slow
 *   Fly_missile    straight on, no gravity, until it touches something
 *   Step           a monster: a step is asked by its AI (move_step),
 *                  18 up, the move, then down to the floor; a step off
 *                  a ledge is refused (monsters do not fall off); in
 *                  the air (a dog's leap) it falls as a toss
 *
 * The walk towards a goal (SV_MoveToGoal) is Doom's: the way it faces
 * if it can, else a new direction, the diagonal towards the goal
 * first, then the axes, the old way, any, back (SV_NewChaseDir).
 *
 * Where it stands in mini-quake: Game runs [run] for each entity a
 * frame, Monster_ai walks the monsters by [move_to_goal] and [walk_move],
 * Weapons and Combat trace their shots and sights by [trace]. *)

type hit = {
  fraction : float;
  endpos : Model.vec;
  normal : Model.vec;
  startsolid : bool;
  allsolid : bool;
  what : Edict.who; (* Nobody: the level *)
  sky : bool; (* the level's sky was hit: a missile vanishes *)
}

(* [trace w start mins maxs finish pass]: a box (mins, maxs: zero a
 * point) moved from start to finish through the level, its doors, and
 * the solid entities and the player, but [pass] and what [pass] owns
 * (a missile and its shooter), and [pass]'s owner *)
val trace :
  Edict.world ->
  Model.vec ->
  Model.vec ->
  Model.vec ->
  Model.vec ->
  Edict.who ->
  hit

(* [traceline w start finish pass]: a point's trace (QuakeC's
 * traceline); [monsters] false: through the monsters (visible) *)
val traceline :
  Edict.world -> Model.vec -> Model.vec -> bool -> Edict.who -> hit

(* [walk_move w e yaw dist]: QuakeC's walkmove: a step that way *)
val walk_move : Edict.world -> Edict.t -> float -> float -> bool

(* [change_yaw e]: turned towards its ideal_yaw, its yaw_speed (20
 * degrees a think) at most *)
val change_yaw : Edict.t -> unit

(* [step_direction w e yaw dist]: SV_StepDirection: turned that way, a
 * step if it faces it *)
val step_direction : Edict.world -> Edict.t -> float -> float -> bool

(* [new_chase_dir w e goal dist]: SV_NewChaseDir *)
val new_chase_dir : Edict.world -> Edict.t -> Model.vec -> float -> unit

(* [move_to_goal w e dist]: SV_MoveToGoal, towards its enemy *)
val move_to_goal : Edict.world -> Edict.t -> float -> unit

(* [run w e dt]: SV_Physics for one entity: its move by its movetype,
 * then its think if its time came *)
val run : Edict.world -> Edict.t -> float -> unit
val gravity : float
