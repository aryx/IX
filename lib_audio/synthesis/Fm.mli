(* FM synthesis: a rich, changing spectrum from two sines (see
 * notes_audio.md section 7).
 *
 * John Chowning (Stanford, 1967, published 1973) let one sine wobble
 * the phase of another, at an audio rate:
 *
 *     out(t) = sin (2 pi fc t + I sin (2 pi fm t))
 *
 * Here fc is the carrier (the pitch heard), fm is the modulator, and I
 * is the index (how far it wobbles). When the modulator is slow, it is a
 * vibrato. When it is as fast as the carrier, it is a new timbre: the
 * spectrum has the carrier, and sidebands on each side at fc +- k fm,
 * where the k-th one has the amplitude J_k(I), a Bessel function:
 *
 *     amplitude          fc = 400, fm = 100, I = 1
 *        |                   |
 *        |                   |          J0(1) = 0.77 at fc
 *        |              |    |    |     J1(1) = 0.44 at fc +- fm
 *        |              |    |    |     J2(1) = 0.11 at fc +- 2 fm
 *        |         |    |    |    |    |    J3(1) = 0.02
 *        +----+----+----+----+----+----+----> Hz
 *            100  200  300  400  500  600
 *
 * Two numbers then choose the sound. The ratio fm / fc sets where the
 * sidebands fall. A whole number puts them on the harmonics (1 gives
 * all of them, like brass; 2 gives the odd ones, like a clarinet), and
 * any other ratio puts them between the harmonics, which is inharmonic
 * (1.4 gives a bell, a gong). The index sets how many sidebands are loud
 * (about I + 1 on each side), which is the brightness. Chowning's
 * insight was to make the index follow the envelope, so that a note is
 * bright when struck and darker as it dies away, like every real
 * instrument; Synth does this for a fading FM voice. Sidebands that
 * fall below 0 Hz fold back, inverted, onto the positive ones, and that
 * is part of the character.
 *
 * Yamaha licensed FM from Stanford. It made the DX7 (1983), with six
 * "operators" wobbling each other, and the sound chips of the Sega
 * Genesis and of the PC's AdLib and Sound Blaster (the OPL2, with two
 * operators per voice). This was the sound of the games of the 1980s
 * and early 1990s, after the NES's squares.
 *
 * (Strictly, this is phase modulation, the formula that every "FM"
 * synthesizer since the DX7 computes. For a sine modulator it gives the
 * same spectrum as modulating the frequency itself.)
 *
 * References: John Chowning, "The Synthesis of Complex Audio Spectra by
 * Means of Frequency Modulation", Journal of the Audio Engineering
 * Society 21(7), 1973; Curtis Roads, The Computer Music Tutorial,
 * 1996, chapter 6. *)

(* ix: copied from libs/audio/synthesis/Fm.mli
 * in the author's playground (docs/plans/plan_audio.md). *)

(* [wave ~index carrier modulator] is the formula above, with the two
 * phases in [0, 1) *)
val wave : index:float -> float -> float -> float

(* [render ~carrier ~ratio ~index seconds] renders the sound, with the
 * modulator at [ratio] times the carrier, both from phase 0 *)
val render : carrier:float -> ratio:float -> index:float -> float -> Signal.t
