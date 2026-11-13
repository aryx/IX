(* A plucked string: the Karplus-Strong algorithm (see notes_audio.md
 * section 8).
 *
 * Every other sound here is an oscillator, a formula of the phase, or
 * noise. A plucked string is neither, and yet it takes a dozen lines.
 * Kevin Karplus and Alex Strong (Stanford, 1983) found that a delay line
 * one period long, filled with noise and read around and around, with
 * each sample written back as the average of two neighbours, sounds like
 * a guitar string:
 *
 *        +-------------------------------+
 *        |  delay line, p samples: noise | ---+---> out
 *        +-------------------------------+    |
 *                    ^                        |
 *                    +-- (x[n] + x[n+1]) / 2 -+   the average: a low-pass
 *
 * Why does it work? Read around and around, the line repeats every p
 * samples, so whatever is in it becomes a periodic wave, with a pitch of
 * rate / p. The noise gives that wave every harmonic at once, like a
 * plucked string (a sharp pluck is a jump, rich in harmonics). The
 * averaging is a gentle low-pass applied once per period, so the high
 * harmonics die first and the low ones last. That is exactly what a real
 * string does (its energy leaks faster at high frequencies): the bright
 * twang turns to a mellow hum. Nothing models a string; the ear only
 * hears the spectrum's shape over time, and that shape is right.
 *
 * The pitch: the average of two neighbours is half a sample late, so the
 * period is p + 1/2 samples, and p = round (rate / frequency - 1/2).
 * Since p is whole, it can be off by up to half a sample. At A4, p = 100
 * gives 438.8 Hz, 5 cents flat (up to 9 cents at that length), and it is
 * worse for high notes (at 2 kHz, p = 22 gives 1960 Hz, 35 cents flat, a
 * third of a semitone). The fix (David Jaffe and Julius Smith, 1983) is
 * a first-order all-pass filter in the loop, which delays by the
 * fraction of a sample, delta, that the line cannot:
 * y[n] = C x[n] + x[n-1] - C y[n-1], with C = (1 - delta) / (1 + delta).
 * It lets every frequency through at the same level (so it does not dull
 * the string), only later. [~tuned:true] adds it. Measured
 * (the playground's Unit_pluck), at 2 kHz it goes from 35 cents flat to within
 * a cent. [decay] shortens the ring a little more at each pass, for the high
 * notes, whose line is short and goes round often. The noise comes from
 * 5000 steps into the LFSR's sequence, because its first bits, from 1,
 * are mostly 0s (a first try averaged -0.49, a string of three quarters
 * -1s). And the noise has its average taken out. 200 random -1s and 1s
 * do not add up to 0 exactly, and the averaging, being a low-pass,
 * would keep that constant (0 Hz passes), so the string would ring
 * around an offset.
 *
 * Example: for A3 (220 Hz), p = round (200.45 - 0.5) = 200. The period
 * is then 200.5 samples, which gives 219.95 Hz untuned. Tuned, the line
 * is 199 samples and the all-pass gives 0.95, which makes 220 Hz. The
 * centroid of the spectrum falls as the string rings, from 3803 Hz at
 * the pluck to 642 Hz 1.5 s later (the playground's Unit_pluck): the twang,
 * then the hum. (A first version wrote back the average of a sample and the
 * *next* one, y[n + p] = (y[n] + y[n + 1]) / 2, which is half a sample
 * early. Its period was p - 1/2, 12.5 cents sharp at 440 Hz where the
 * formula said 4.7 flat, and the tuning test caught it.)
 *
 * References: Kevin Karplus, Alex Strong, "Digital Synthesis of
 * Plucked-String and Drum Timbres", Computer Music Journal 7(2), 1983;
 * David Jaffe, Julius O. Smith, "Extensions of the Karplus-Strong
 * Plucked-String Algorithm", Computer Music Journal 7(2), 1983. *)

(* ix: copied from libs/audio/synthesis/Pluck.mli
 * in the author's playground (docs/plans/plan_audio.md). Its optional
 * arguments are required here. *)

(* [period frequency] is p, the delay line's length (200 for 220 Hz) *)
val period : float -> int

(* [render ~decay ~tuned ~frequency seconds] is the string, plucked and
 * ringing. [decay] is the loss at each pass on top of the averaging's
 * (0.996 is the usual, and 1 means none). [tuned] adds the all-pass's
 * fraction of a sample (true is the usual; false keeps the whole
 * samples only, as the first version did). The noise comes from the
 * NES's LFSR, so the sound is the same every time. *)
val render : decay:float -> tuned:bool -> frequency:float -> float -> Signal.t
