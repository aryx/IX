(* Particles: Quake's points of colour (r_part.c, d_part.c): the blood
 * of a hit, the puff of a bullet on a wall, an explosion, the trails
 * of rockets and grenades.
 *
 * A particle is a place, a velocity, a colour of the palette and a
 * time to die; each frame it moves, and its kind changes it:
 *
 *   slowgrav   blood, a puff: falls slowly (gravity x 0.05)
 *   fire       a trail's: rises, its colour along ramp3 (yellow to
 *              dark red), gone at the ramp's end
 *   explode    half an explosion's: speeds up, ramp1 (yellow, orange,
 *              red, dark), in 0.8 s
 *   explode2   the other half: slows down, ramp2, faster
 *
 * An explosion is 1,024 of them, 16 around its centre, flying at up to
 * 256 units a second; a trail a particle every 3 units of the
 * missile's way. Each is drawn as a square of 1 to 4 pixels, bigger
 * nearer (D_DrawParticle), against the z-buffer the world and the
 * models wrote, which it writes too.
 *
 * Where it stands in mini-quake: Game gives it the effects of the
 * frame; Quake.ml draws them after the models. *)

type t

val create : unit -> t

(* [blood p org count]: R_RunParticleEffect's blood (colour 73) *)
val blood : t -> float -> Model.vec -> int -> unit

(* [gunshot p org]: a bullet's puff on a wall (colour 0, 20) *)
val gunshot : t -> float -> Model.vec -> unit

(* [explosion p time org]: R_ParticleExplosion *)
val explosion : t -> float -> Model.vec -> unit

(* [trail p time from to_ kind]: R_RocketTrail (1 a rocket's fire, 2 a
 * grenade's smoke) *)
val trail : t -> float -> Model.vec -> Model.vec -> int -> unit

(* [run p time dt]: dt seconds of their lives *)
val run : t -> float -> float -> unit

(* [draw v p]: into v.screen, against v.zbuffer *)
val draw : View.t -> t -> unit
