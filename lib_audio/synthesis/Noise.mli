(* Noise: random samples, for wind, explosions and drums (see
 * notes_audio.md section 3).
 *
 * A computer's randomness comes from a pseudo-random generator. The
 * NES's noise channel (in the APU of the 2A03, 1983) used a 15-bit
 * linear-feedback shift register (LFSR). At each step, the XOR of two of
 * its bits is fed back in at the top, as the other bits shift down one
 * place, and the lowest bit is the output.
 *
 *     bit 14 ...          bit 1  bit 0 --> out
 *       ^                   |      |
 *       |                   +-XOR--+       (long mode: bits 0 and 1)
 *       +-------------------------'        (short mode: 0 and 6)
 *
 * It is cheap, and deterministic: the noise is the same every time, so
 * it can be tested and replayed. From 1, the long mode goes through all
 * 32,767 non-zero 15-bit values before coming back (it is a
 * maximal-length LFSR), which sounds as a hiss. The short mode loops
 * after 93 steps, which sounds as a pitched, metallic buzz, the "short
 * noise" of 8-bit games. The first steps from 1 are 16384, 8192, 4096,
 * ... (the fed-back 1 enters at bit 14, then slides down).
 *
 * A step per sample gives the highest-pitched noise. The NES stepped
 * its register at one of 16 rates, its 1.79 MHz clock divided by 4 to
 * 4068, from 447 kHz down to 440 Hz, which gave the noise its "pitch".
 * [render ~rate] holds each value for 44,100 / rate samples.
 *
 * White noise has all frequencies equally, as this noise does. Pink
 * noise has less of the high ones (-3 dB an octave, which sounds like
 * rain rather than hiss); nothing in ix makes it.
 *
 * References: Solomon Golomb, Shift Register Sequences, 1967; the NES
 * APU's noise channel, https://www.nesdev.org/wiki/APU_Noise *)

(* ix: copied from libs/audio/synthesis/Noise.mli
 * in the author's playground (docs/plans/plan_audio.md). Its optional
 * arguments are required here. *)

type mode = Long | Short

(* [step mode register] is the register one step later *)
val step : mode -> int -> int

(* [period mode] is how many steps it takes from 1 to come back to 1:
 * 32,767 (long) or 93 (short) *)
val period : mode -> int

(* [render ~mode ~rate seconds] gives [seconds] of noise, with the
 * register stepped [rate] times a second from 1 (each value is held in
 * between), and the lowest bit given as 1. or -1. *)
val render : mode:mode -> rate:float -> float -> Signal.t

(*****************************************************************************)
(* {1 Random numbers, not noise} *)
(*****************************************************************************)
(* A sample-and-hold's steps and an oscillator's drift need a random
 * *number* every so often, and the LFSR is a poor source of those. Each
 * state is the last one shifted by a bit, so successive values (16384,
 * 8192, 4096 from 1) are halves of each other. A linear congruential
 * generator (Lehmer, 1949) is the classic source:
 *
 *     x' = (1664525 x + 1013904223) mod 2^32
 *
 * (with the constants of Numerical Recipes, Press et al., 1986). From 0
 * it gives 1013904223, 1196435762 and 3519870697, which are -0.528,
 * -0.443 and 0.639 as numbers from -1 to 1 (x / 2^32, stretched). Its
 * low bits are poor (the lowest one alternates), so a value is read
 * from all the bits, as x / 2^32, never as x mod something small. It is
 * deterministic, from a seed, so the drift and the random steps are the
 * same at every run. *)

(* [lcg x] is the next state, as a signed 32-bit number (3519870697
 * above comes out as 3519870697 - 2^32 = -775096599), the same natively
 * and in a browser *)
val lcg : int -> int

(* [uniform x] is a state as a number from -1 to 1 *)
val uniform : int -> float
