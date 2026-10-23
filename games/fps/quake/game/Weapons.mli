(* Weapons: the player's attacks (Quake's weapons.qc: W_Attack and the
 * W_Fire functions, W_ChangeWeapon, W_BestWeapon; player.qc's frames
 * of the weapon in hand).
 *
 *   1 the axe       64 units ahead, 20                      0.5 s
 *   2 the shotgun   6 pellets of 4, spread 0.04             0.5 s
 *   3 the super shotgun  14 pellets, 0.14 by 0.08, 2 shells 0.7 s
 *   4 the nailgun   a nail (1,000 a second, 9), from each barrel
 *                   in turn                                 0.2 s
 *   6 the grenade launcher  a grenade: 600 forward and 200 up, it
 *                   bounces (Physics' Bounce: half its speed back
 *                   off a wall, "weapons/bounce"), explodes on a
 *                   monster or after 2.5 s (120)            0.6 s
 *   7 the rocket launcher  a rocket (1,000 a second): 100 to 120 to
 *                   what it hits, and the blast (120)       0.8 s
 *
 * Every shot is aimed (QuakeC's aim (), the engine's PF_aim): the way
 * the player looks, unless a monster is within 0.93 of it (21 degrees)
 * that a line reaches: then up or down to it -- Quake's vertical
 * autoaim, which made a mouse's pitch optional. A shot wakes the
 * monsters near (show_hostile) and kicks the view (punchangle).
 *
 * The weapon in hand is a model drawn at the eye (v_shot.mdl ...), its
 * frames the attack's (weaponframe: 1 to 6 a tenth of a second each,
 * the nailgun's 1 to 8 while it fires).
 *
 * Where it stands in mini-quake: Game calls [frame] each frame with
 * the attack key and the weapon asked; [view_model] for Render. *)

(* [frame w attack impulse]: the weapon asked (1 to 7: the keys; 0
 * none), then an attack if the key is held and the last is done *)
val frame : Edict.world -> bool -> int -> unit

(* the model in hand and its frame *)
val view_model : Edict.world -> string * int

(* the weapon's ammunition, for the status line *)
val ammo : Edict.world -> int option

(* the models and sounds the weapons use (precache) *)
val models : string list
val sounds : string list
