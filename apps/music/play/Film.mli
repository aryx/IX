(* Film: mini-play's window, a film as a Playground program.

       the file --Y4m, Fli, Avi, Gif, Mpeg1--> Movie.t, its sound
                                          |          | pulled by the mixer,
                                          |          v block by block (Audio)
                     the frame at the -- index_at <-- the sound's position
                     sound's clock

   The picture follows the sound and not the other way round: a frame
   skipped is hardly seen, a sound skipped is always heard. Until the sound
   has begun, and for a film without one, a timer runs the picture, so that
   a machine with no sound does not stay on the first frame.

   cs-history:
   Muybridge's horse (1878) made a movement into a row of pictures, and film
   stayed that for a century. On a computer the trouble was the size: at 320
   by 240, 25 pictures a second is 5.7 MB of them a second, against a CD-ROM's
   150 KB. FLI (Autodesk Animator, 1989) stores only what changed; AVI
   (Video for Windows, 1992) separates a container from its codec; MPEG-1
   (1993) moves blocks of the last picture. Movie.mli says what they share. *)

type t = {
  movie : Movie.t;
  sound : Signal.stereo option; (* at Signal.rate *)
  loops : bool; (* begun again at its end: a GIF's way *)
}

(* can [kind] (File_kind's) be read as a film? *)
val is_film : string -> bool

(* the file's bytes and its kind; Error in words *)
val read : kind:string -> string -> (t, string) result

(* the window: space pauses, q leaves *)
val run : Cap.all_caps -> t -> unit
