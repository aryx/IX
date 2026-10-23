(* Cdaudio: the level's music (Quake's cd_audio.c: the CD's track the
 * level asks, worldspawn's "sounds"; the ports since play it from
 * music/trackNN.ogg, as LibreQuake ships it).
 *
 * Quake's music was audio tracks on its CD (Trent Reznor's), the data
 * on track 1; the engine asked the drive to play track n and loop it,
 * and nothing of it went through the game's mixer. LibreQuake's tracks
 * are Ogg Vorbis files, here decoded as they play (lib_audio's Vorbis,
 * the playground's) and looped by Audio.
 *
 * Where it stands in mini-quake: Quake.ml starts it with the level. *)

(* [track level]: music/trackNN.ogg, NN the level's "sounds" (2 if it
 * says none) *)
val track : Model.t -> string

(* [play bytes]: the track's .ogg, looped *)
val play : string -> unit
