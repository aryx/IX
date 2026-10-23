(* Monsters: the kinds of monsters of LibreQuake's first level, as their
 * QuakeC wrote them (grunt.qc the soldier, rottweiler.qc the dog,
 * enforcer.qc the enforcer): their frames, what each does, their
 * attacks, their pains and deaths.
 *
 * A model's frames are numbered in the order its QuakeC declares them
 * ($frame stand1 stand2 ... death1 ...): each kind's [layout] says
 * those runs, and a sequence takes its frames from them. The soldier:
 *
 *   stand  8 frames, ai_stand           run  8, ai_run 11 15 10 10 ...
 *   atk    shoot1-9: ai_face, the 5th fires 4 pellets (FireBullets,
 *          aimed behind a moving player: where it was 0.2 s ago)
 *   pain, painb, painc   staggers (ai_pain, ai_painforward)
 *   die, cdie   the 3rd frame not solid, the backpack (5 shells)
 *
 * The attacks: the soldier's chance to shoot is 0.9 within 120 units,
 * 0.4 within 500, 0.05 within 1,000 (SoldierCheckAttack), then a pause
 * of 1 to 2 s; the enforcer's (CheckAttack) 0.4 and 0.1, its laser a
 * missile (600 a second, 15); the dog bites within 120
 * ((3 randoms) x 8) and leaps from 80 to 150 (300 forward and 200
 * up, 10 to 20 on contact).
 *
 * Where it stands in mini-quake: Game spawns the map's monster_army,
 * monster_dog, monster_enforcer by [spawn]; Monster_ai runs their frames. *)

(* [spawn w classname origin yaw]: the monster, standing, on the
 * floor (walkmonster_start); None for a kind not here *)
val spawn : Edict.world -> string -> Model.vec -> float -> Edict.t option

(* the models and sounds the kinds use (precache) *)
val models : string list
val sounds : string list
