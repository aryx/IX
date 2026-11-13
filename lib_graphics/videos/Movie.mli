(* Movie is a video as a player sees it, whatever its format (a GIF's
 * frames, Y4M, FLI, AVI, and MPEG-1 in time): pictures, each with the
 * time it starts, decoded when they are asked for.

   A minute of 320 x 240 is 1,800 pictures of 300 KB each, which is
   half a gigabyte decoded. So a movie is not its pictures but what
   gives them one at a time. Also, most formats can only go forward. A
   delta frame (FLI's frames, MPEG's P frames) is the one before it
   plus what changed, so frame 100 needs frame 99, which needs 98, and
   so on back to the last frame stored whole, a **key frame**.
   [sequential] keeps the decoder's state at the last frame given, and
   goes on from there. It keeps the frame before that one too, as
   decoders keep their reference frames (and as a player that compares
   a frame with the one before it needs):

     asked:    0   1   2   3   2   0      (seeks back)
     decoded:  0   1   2   3   -   0      the one before is kept; further
                                          back, from the start again

   This is why a player seeks to key frames, and why a movie that is
   only key frames (Motion JPEG) seeks anywhere at once.

   The times array says when a frame plays: times.(i) is when frame i
   starts, in seconds, times.(0) = 0, and the frame lasts until the
   next one (the last frame lasts until [duration]). A fixed rate gives
   times.(i) = i / rate, and a GIF's frames each have their own
   delay. *)

type t = {
  width : int;
  height : int;
  times : float array; (* when each frame starts, increasing, times.(0) = 0 *)
  duration : float; (* when the last frame ends *)
  frame : int -> Rgba_image.t; (* frame i, 0 <= i < Array.length times *)
}

val frame_count : t -> int

(* [of_frames frames] is a movie of pictures already decoded, each with
 * how long it shows, in seconds (as a GIF's are) *)
val of_frames : (Rgba_image.t * float) list -> t

(* [sequential ~width ~height ~times ~start ~next] is a movie decoded
 * forward only. [start ()] is the decoder's state before frame 0, and
 * [next s] gives frame i from the state after frame i - 1, and the
 * state after frame i. Asking again for the frame just given, or for
 * the one before it, costs nothing; asking for the next one costs one
 * [next]; asking for an earlier one costs [start] again and every
 * frame up to it. *)
val sequential : width:int -> height:int -> times:float array -> duration:float -> start:(unit -> 's) -> next:('s -> 's * Rgba_image.t) -> t

(* [index_at m t] is the frame showing at [t] seconds (the first frame
 * before 0, and the last one after [duration]) *)
val index_at : t -> float -> int

(* [frame_at m t] is that frame's picture *)
val frame_at : t -> float -> Rgba_image.t
