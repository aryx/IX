(* Weapons: the player's hand (Doom's p_pspr.c): the weapon held, raised,
 * lowered, fired, and its flash, each a picture with its own states
 * (a psprite: Info's PISTOL, PISTOL1 ...), drawn over the view.
 *
 *   PISTOL (A, Weapon_ready: the attack key? PISTOL1)
 *     PISTOL1 (A, 4) -> PISTOL2 (B, 6, Fire_pistol: a bullet, and the
 *       flash's psprite set to PISTOLFLASH) -> PISTOL3 (C, 4) ->
 *       PISTOL4 (B, 5, Refire: the key still held? PISTOL1 again)
 *       -> PISTOL
 *   another weapon asked (or the player dead): PISTOLDOWN (Lower, 6
 *     rows a tic down to 128), then the new one's UP (Raise, up to 32),
 *     then its ready state
 *
 * A bullet of the player's goes where the player looks, up or down to
 * the first thing ahead (P_BulletSlope: the aim, or a 32nd of a turn
 * to either side); the first of a series straight, the next ones
 * spread (P_GunShot's accurate). Each shot is heard by the monsters
 * (Enemy.noise_alert). The fist and the chainsaw reach 64.
 *
 * Where it stands in mini-doom: Play gives it the attack key and the
 * weapon asked each tic; Doom.ml draws the psprites (Render). *)

(* P_SetupPsprites: the weapon held raised from below *)
val setup : World.t -> unit

(* [tic t attack change]: P_MovePsprites, with the tic's attack key held
 * and the weapon asked for, if any (the keys 1 to 4: 1 the fist, or
 * the chainsaw when held; 2 the pistol; 3 the shotgun) *)
val tic : World.t -> bool -> Info.weapon option -> unit
