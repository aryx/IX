(* Sound: what the player hears (Quake's snd_dma.c: S_StartSound,
 * SND_Spatialize; snd_mem.c: a sound's WAV loaded), through
 * lib_playground's Audio.
 *
 * A sound is a WAV of sound/ (sound/weapons/bounce.wav), 8 or 16
 * bits, at its own rate (Audio.wav takes either, and resamples it),
 * loaded the first time it is heard (Quake's precache did it at the
 * level's start).
 *
 * Where it comes from changes it (SND_Spatialize): quieter with the
 * distance, by the sound's attenuation (1 a monster's or a weapon's,
 * 2 an idle growl's: twice as fast), silent at 1,000 units over the
 * attenuation; and to the side it is on, by the dot of the listener's
 * right with the way to the sound:
 *
 *   loudness = 1 - distance x attenuation / 1000 (times the master
 *              volume, 0.5)
 *   pan = right . (source - ear) / |source - ear|      (-1 left, 1 right)
 *
 * With sound=3d, the playground's Audio3d (the distance's law, the
 * air's dulling, the time between the ears; 32 units a meter).
 *
 * Where it stands in mini-quake: Quake.ml plays each frame's sounds
 * (Game's), from where the player is. *)

type t

(* [create read three_d]: [read] a file beside the level (sound/x.wav) *)
val create : (string -> string option) -> bool -> t

(* [play s sounds eye yaw]: the sounds, heard at eye facing yaw
 * (degrees) *)
val play : t -> Edict.sound list -> Model.vec -> float -> unit
