(* Tiny sound is the part of the kernel that makes audio samples
 * (plan_tiny_audio.md), as KGraphics is the part that makes pixels. It
 * needs only two functions to reach the machine's bytes, KRaw's peekb
 * and pokeb.
 *
 * {b The kernel makes the samples; a program only says what to play},
 * as for the screen. A program writes a message to /dev/audio,
 * `s wave hz to_hz ms volume` (a letter, then 16-bit numbers, encoded
 * as TinyLibDraw encodes them). The kernel then adds the sound to
 * tiny-machine's ring, where the other programs' sounds already are.
 * A sound is sfxr's recipe (lib_audio's Sfx.mli) cut down to those five
 * numbers: a wave, a pitch that slides, and a volume that falls to
 * nothing at the end:
 *
 *       volume
 *         |\                   a square wave at 784 Hz for 60 ms:
 *         | \                  480 samples, each +v or -v, with v
 *         |  \                 falling from the volume to 0
 *         |   \
 *         +----+---> time
 *         0    ms
 *
 * Why not let the program write samples, as Plan 9's and m-ix's
 * /dev/audio do? Because a game's sound is a recipe, and making the
 * samples in tiny-ml code cost 2,750 instructions a sample (measured
 * when tiny-ml had no Bytes, so each sample was a string and a cons).
 * The 0.7 s of Tetris's game-over sound took two seconds of an 8 MHz
 * machine. In the kernel, a sample is made where it is played, with no
 * allocation: it takes about 230 instructions for a square wave, and
 * 260 for a triangle. (The clamp is written out inline, because with
 * the prelude's min and max, each a call to the runtime's compare, a
 * sample cost 535.) A sound also crosses a pipe as 11 bytes instead of
 * 5,600. A tune in two parts costs 3.9 million instructions a second,
 * which is half of an 8 MHz machine, or a fifth of the 20 MHz that
 * tiny-machine runs at in a window. For what is not a recipe, such as
 * playing a WAV file (TinyPlay.ml), there is also a message carrying
 * raw samples (`p`).
 *
 * twin:
 * The twins are mini-9pi's /dev/audio (Devaudio in kernels/9pi/, after
 * Plan 9's audio(3)) and lib_audio. There the device takes only
 * samples, of 16 bits, in two channels, 44,100 a second, and from one
 * program at a time (an open while another program has the device fails
 * with Einuse, as in principia's devaudio.c). A program makes and mixes
 * its sounds itself, with lib_audio's Sfx and Mixer.
 *
 * dropped:
 * Most of sfxr's recipe, which lib_audio's Sfx keeps, is dropped: the
 * sine wave, an attack and a sustain (a sound here only falls, after a
 * fixed rise of 2 ms against the click), vibrato, a jump in pitch, the
 * filters, the echo and the reverb. Voices are added and clamped, so loud ones
 * together clip, where lib_audio's Mixer squeezes their sum through
 * tanh. There is no /dev/volume as in mini-9pi, so a program cannot
 * turn the sound down.
 *
 * twist:
 * Unlike the twin, the recipe and the mixing moved into the kernel, so
 * each open of /dev/audio is a voice and several programs are heard at
 * once. A sample is one byte, there is one channel, and there are 8,000
 * samples a second. That is what a game's beeps and a melody need, and
 * no more.
 *
 * cs-history:
 * This is the bargain the sound chips made. The Atari 2600's TIA
 * (1977), General Instrument's AY-3-8910 (1978), the Commodore 64's SID
 * (1982) and the NES's APU (1983) each had a few voices with a wave, a
 * pitch and an envelope. A program set their registers instead of
 * computing samples, which those CPUs could not afford. Samples came
 * once CPUs could afford them (the Amiga's Paula in 1985, which still
 * mixed four voices in the chip; the PC's Sound Blaster in 1989), and
 * a game's sound effects stayed sfxr's few numbers. tiny-machine is
 * one of those slow CPUs again.
 *)

(* [per_ms] is the number of samples per millisecond (8,000 a
 * second). *)
val per_ms : int

(* In a message the wave is 0 to 3 and the volume is 0 to 127. The pitch
 * slides from t_hz to t_to_hz. *)
type wave = Square | Triangle | Sawtooth | Noise
type tone =
  { t_wave : wave; t_hz : int; t_to_hz : int; t_samples : int;
    t_volume : int }

(* [mix ring size at tone] adds tone to the ring at address [ring], of
 * [size] samples (a power of two), from sample [at] (at modulo size).
 * Each sum is clamped to -128..127. *)
val mix : int -> int -> int -> tone -> unit

(* A sound that is not a recipe, such as a file's, is sent as samples:
 * `p n` then n bytes, like a row of /dev/draw. The samples are signed
 * bytes. *)
type sound = Tone of tone | Samples of string
val sound_length : sound -> int
val mix_sound : int -> int -> int -> sound -> unit

(* [sounds s] decodes messages `s wave hz to_hz ms volume` or `p n`.
 * Bad_sound is raised when a message is incomplete or has a value out
 * of range. *)
exception Bad_sound
val sounds : string -> sound list
