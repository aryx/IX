(* Tiny sound: TinyKernel.ml's part that makes the samples
 * (plan_tiny_audio.md), as TinyKernelGraphics.ml is its part that
 * makes the pixels. Not a program: tiny-ml's ML, which is OCaml's too,
 * so that it is tested on the host first:
 *
 *     tiny-ml -tm -o kernel.tm memory.ml ... TinyKernelAudio.ml TinyKernel.ml   (TinyKernel/Makefile)
 *     dune build ./tiny/tests/TinyKernelAudio_tests/Host.exe                    (TinyKernelAudio_test.sh)
 *
 * It asks two functions of its machine's bytes, TinyMemory's peekb and
 * pokeb.
 *
 * {b The kernel has the samples, a program says what}, as for the
 * screen: a program writes a message to /audio, `s wave hz to_hz ms
 * volume` (a letter, then numbers of 16 bits, TinyLibDraw's), and the
 * kernel adds the sound to tiny-machine's ring, where the other
 * programs' sounds are already. A sound is sfxr's recipe (lib_audio's
 * Sfx.mli) cut to those five numbers: a wave, a pitch that slides, a
 * volume that falls to nothing at the end:
 *
 *       volume
 *         |\                   a square from 784 Hz, 60 ms:
 *         | \                  480 samples, each +v or -v, v
 *         |  \                 falling from the volume to 0
 *         |   \
 *         +----+---> time
 *         0    ms
 *
 * Why not samples written by the program, as Plan 9's /dev/audio and
 * m-ix's take them: a game's sound is a recipe, and made by tiny-ml's
 * code it was 2,750 instructions a sample (before tiny-ml had Bytes: a
 * string and a cons for each), the 0.7 s of Tetris's game over two
 * seconds of an 8 MHz machine. Here a sample is made where it is
 * played, a few instructions and no allocation, and a sound crosses a
 * pipe as 11 bytes, not 5,600. Samples are a message too (`p`), for
 * what is no recipe: a WAV played (TinyPlay.ml).
 *
 * cs-history:
 * This is a sound chip's bargain: the Atari 2600's TIA (1977), General
 * Instrument's AY-3-8910 (1978), the Commodore 64's SID (1982), the
 * NES's APU (1983) each had a few voices, a wave, a pitch, an envelope,
 * and a program set their registers instead of making samples, which
 * those CPUs could not afford. Samples came when CPUs could (the
 * Amiga's Paula, 1985, still with four voices mixed by the chip; the
 * PC's Sound Blaster, 1989), and a game's sound effects stayed sfxr's
 * few numbers. tiny-machine is one of those CPUs again.
 *)

(* the samples a millisecond (8,000 a second) *)
val per_ms : int

(* [mix ring size at wave hz to_hz n volume]: a sound of n samples added
 * to the ring of [size] samples at [ring] (size a power of two), from
 * the sample numbered [at] (the ring's place: at modulo size), each
 * sum kept from -128 to 127. The wave: 0 a square, 1 a triangle, 2 a
 * sawtooth, 3 noise; the pitch from hz to to_hz, a volume 0 to 127. *)
val mix : int -> int -> int -> int -> int -> int -> int -> int -> unit

(* A message's sound: a tone (wave, hz, to_hz, samples, volume, as
 * [mix]'s), or samples, a byte each, signed, 8,000 a second (`p n`
 * then the n bytes, as /draw's row of pixels: what is no recipe, a
 * file's sound); its length in samples; added to a ring as [mix] adds *)
type sound = Tone of int * int * int * int * int | Samples of string
val sound_length : sound -> int
val mix_sound : int -> int -> int -> sound -> unit

(* The sounds of messages, each `s wave hz to_hz ms volume` or `p n`
 * and n samples; Bad_sound when one is not a whole message or says
 * something out of range *)
exception Bad_sound
val sounds : string -> sound list
