(* Sound: what the player hears (Doom's s_sound.c, and i_sound.c's
 * loading), through lib_playground's Audio.
 *
 * A sound effect is a lump of the WAD, DS and its name (DSPISTOL),
 * DMX's format: 3, its rate (11,025 samples a second in id's WADs,
 * 22,050 and others in Freedoom's), its length, then bytes of 8 bits
 * (128 the silence), the first and last 16 a pad. Here each is made a
 * WAV of 16 bits once, the first time it is heard, and Audio.wav plays
 * it (Audio resamples it to its 44,100).
 *
 * Where a sound comes from changes it (S_AdjustSoundParams): from the
 * player itself, as it is; from a place, quieter with the distance
 * (id's own, without a square root: P_AproxDistance), full within 160,
 * silent past 1,200, and to the side it is on, at most three quarters
 * of the way to a speaker:
 *
 *   loudness 1 |------.
 *              |       `-.             the pan: -0.75 sin a, a the
 *              |          `-.          angle from where the player
 *            0 +------+-------`----    looks to the sound (to the
 *                    160      1200     left: the left speaker)
 *
 * With sound=3d, the playground's Audio3d instead (its ears where the
 * eye is: the distance's law, the air dulling what is far, the time
 * between the ears; a unit of Doom's taken as 1/32 of a meter, the
 * player being 56 high).
 *
 * The music: the level's D_ lump (D_E1M1), MUS or MIDI (Mus), looped
 * by Audio's MIDI player, its 8-bit band.
 *
 * Where it stands in mini-doom: Doom.ml plays each tic's sounds
 * (World's [sounds]) and starts the level's music. *)

type t

(* [create wad three_d]: the sounds of the WAD, made when first heard *)
val create : Wad.t -> bool -> t

(* [play s world]: the sounds of the last tics, from where they were
 * made, heard where the player is now *)
val play : t -> World.t -> unit

(* [music wad map]: the level's music, looping, if the WAD has it *)
val music : Wad.t -> string -> unit

(* [dmx_to_wav lump]: a DS lump as a WAV file's bytes (16 bits, one
 * channel, its rate); None if it is not one *)
val dmx_to_wav : string -> string option
