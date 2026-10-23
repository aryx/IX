(* Enemy: what the monsters do (Doom's p_enemy.c): wait, wake up, chase,
 * attack, flinch, die -- the actions of their states (Info).
 *
 * A monster stands in its spawn states, looking (A_Look) every 10
 * tics: it wakes when it sees the player in front of it (P_CheckSight,
 * the eighth of a turn behind it blind but within 64), or when the
 * player's shot was heard in its sector (P_NoiseAlert: the sound
 * flooded through the open lines from the player's sector, across one
 * sound-blocking line at most). Awake, it chases (A_Chase), each 2 to 4
 * tics:
 *
 *   in melee range (an imp's claws, a demon's bite)? the melee states
 *   moved since its last shot, and the dice say so (the further, the
 *     less likely: P_CheckMissileRange)? the missile states
 *   else a step of its speed in its direction (P_Move); blocked, or
 *     its steps counted down: a new direction (P_NewChaseDir)
 *
 * id's way is to go as the crow flies: the diagonal towards the player
 * first, then the axis of the larger distance, then the other, the old
 * direction, any, and back last. A monster behind a wall slides along
 * it or turns back; it never finds the door. With ai=ways (World.Ways)
 * the playground's AI (Ways, over Ai.flow) gives a monster that cannot
 * see the player its way through the level instead, and its aim error
 * (Ai.aim_error: off when it first sees, better as it keeps seeing),
 * where id's is the same spread throughout.
 *
 * Where it stands in mini-doom: it fills Mobj.act; Play wakes the
 * monsters when the player shoots ([noise_alert]). *)

(* [noise_alert t]: P_NoiseAlert: the player's shot heard from its
 * sector *)
val noise_alert : World.t -> unit

(* [act t m action]: a state's action (Mobj.act's) *)
val act : World.t -> Things.mobj -> Info.action -> unit

(* P_CheckSight from a thing to a target: its eye, three quarters up *)
val sees : World.t -> Things.mobj -> Things.target -> bool
