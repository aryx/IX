(* The mixer: every sound that is playing, summed into the samples that
 * the sound card takes (see notes_audio.md sections 5 and 10). It is
 * the stateful part of audio/: the sounds come and go as the game
 * plays them.
 *
 *    play blip ---------.                        the one-shots are rendered
 *    play jump ---------+--> [ + ] --> tanh -->  once, and read through as
 *    keep "thrust" -----+      ^       samples   the samples go out; the
 *    instrument "moog" -'      |                 continuous ones advance
 *                              |                 frame by frame; the
 *                     pull n: the next n         instruments are asked for
 *                                                the next block
 *
 * There are two clocks: the game's, 60 frames a second, and the sound
 * card's, 44,100 samples a second, which pulls on its own
 * (notes_audio.md section 10). The platform calls [pull] with how many
 * samples the card needs. Natively, SDL's queue is topped up to about
 * 50 ms ahead; in a golden run, it is exactly 735 a frame (44,100 /
 * 60). So the mixer never waits and never rushes. A one-shot starts at
 * the next sample pulled. A continuous sound is [keep]ed each frame;
 * when a [pull] finds that it was not kept since the last pull, it
 * fades out over that pull and is gone.
 *
 * The sum goes through tanh (Mix.soft_clip), so that many sounds at
 * once are squeezed rather than cut flat. At most [max_playing]
 * one-shots play at once, and past that the oldest is dropped, so that
 * a backend that does not pull (the web one before phase 4) cannot
 * pile them up forever.
 *
 * References: Game Programming Patterns, "Event Queue" (Robert
 * Nystrom, 2014: playing sounds from game code, and why a queue); SDL's
 * SDL_QueueAudio, https://wiki.libsdl.org/SDL2/SDL_QueueAudio *)

(* ix: copied from libs/audio/Mixer.mli
 * in the author's playground (docs/plans/plan_audio.md). Its optional
 * arguments are required here. *)

(*****************************************************************************)
(* {1 The mixer} *)
(*****************************************************************************)

type t

val create : unit -> t

(* how many one-shots may play at once *)
val max_playing : int

(* when false, every pull is mixed down to one channel, the same in
 * both (the software backend's "m" key, to hear what panning does);
 * true by default *)
val stereo : bool ref

(*****************************************************************************)
(* {1 Playing sounds} *)
(*****************************************************************************)

(* [play m s] plays [s] from the next sample pulled *)
val play : t -> Signal.stereo -> unit

(* [play_at m x ~volume ~pan] plays the recording [x] made louder and
 * panned (as Synth.louder and Synth.Panned do). The samples are the
 * same, but they are mixed from [x] itself as it is pulled, so no new
 * arrays are made at each play *)
val play_at : t -> Signal.t -> volume:float -> pan:float -> unit

(* [loop m name s] plays [s] over and over, from the next sample,
 * unless a loop [name] is already playing (so calling it every frame
 * is harmless). It is for background music *)
val loop : t -> string -> Signal.stereo -> unit

(* [change m name s] makes the loop [name] play [s] from now on, from
 * the same point (the same fraction of the way through, so a tune made
 * faster goes on from the same note), and its clock ([played]) goes
 * on. It starts a new loop if none is playing *)
val change : t -> string -> Signal.stereo -> unit

(* ix's own: [loop_prepared m name s prepare] and [change_prepared] are
 * [loop] and [change], with [prepare pos n] called before each pull to
 * say that the [n] samples of [s] from [pos] (wrapping around its end)
 * are about to be read. They are for a loop whose samples are computed
 * as it is played (Synth.pieces), [s] being zeros until then. *)
val loop_prepared : t -> string -> Signal.stereo -> (int -> int -> unit) -> unit
val change_prepared : t -> string -> Signal.stereo -> (int -> int -> unit) -> unit

(* [stop m name] stops the loop or the instrument [name], if it is
 * playing: it fades out over its next pull *)
val stop : t -> string -> unit

(* [keep ~filter ~pan m name v] keeps the continuous voice [name]
 * playing [v] until the next pull at least. It goes through [filter]
 * if there is one: the filter's cutoff stays at [cutoff], and when the
 * filter changes from frame to frame, its memory is kept. It is panned
 * by [pan] (0 is the middle), and when the pan changes from frame to
 * frame, it glides over the pull *)
val keep : filter:Synth.filter option -> pan:float -> t -> string -> Synth.voice -> unit

(* [instrument m name i] makes the instrument [i] (Instrument.mli) play
 * from the next pull, a block of it at each pull, until [stop m name].
 * It does nothing if an instrument [name] is already playing (so
 * asking for it every frame is harmless, as for [loop]). Its notes and
 * knobs are the caller's business, through [i]'s functions: the mixer
 * only pulls. *)
val instrument : t -> string -> Instrument.t -> unit

(*****************************************************************************)
(* {1 Pulling samples} *)
(*****************************************************************************)

(* [pull m n] gives the next [n] samples, in both channels *)
val pull : t -> int -> Signal.stereo

(* when false, the mixing is done in float arrays, the old way (with
 * the same samples); when true, the default, it is done in flat
 * arrays, which mini-ml makes without a block for each sample *)
val flat : bool ref

(*****************************************************************************)
(* {1 What is playing} *)
(*****************************************************************************)

(* the one-shots playing and the continuous voices kept (for tests and
 * debugging) *)
val playing : t -> int * int

(* the loops playing *)
val looping : t -> string list

(* the instruments playing (not those being stopped) *)
val instruments : t -> string list

(* [played m name] is how many samples of the loop [name] have gone
 * out, counting every time round. It is the loop's own clock, which,
 * unlike its read position, does not go back to 0 at the end. It is
 * None if no such loop is playing. A rhythm game has to time its steps
 * by it (Audio.mli's [position], TinyDDR.ml): the frame clock is the
 * game's, and this one is the music's. *)
val played : t -> string -> int option
