(* Mixing: several sounds at once, and not too loud (see notes_audio.md
 * section 5).
 *
 * Two sounds at once are simply added, sample by sample, the way air
 * pressures add up. The catch is the range. Two sines at full volume add
 * up to 2, outside the -1 to 1 that a sound card takes, and the peaks
 * are cut flat. This is clipping, a harsh distortion (the flat tops have
 * sharp corners, which are new, high harmonics). There are two fixes:
 * turn each sound down (the mixer's gain), or bend the curve smoothly
 * near the limits instead of cutting it. The second is soft clipping
 * (tanh here), which distorts gently, like an overdriven tube
 * amplifier:
 *
 *     out                        hard: min 1 (max -1 x)
 *      1 |      .-------         soft: tanh x
 *        |    ,'  _.----
 *        |   / .-'                2 (two full sines' peak): hard 1,
 *      0 +--/-'---------> in         soft tanh 2 = 0.964
 *          0    1    2
 *
 * Loudness is measured in decibels, a logarithm: 20 log10 of the ratio
 * of the amplitudes. Half the amplitude is -6.02 dB, a tenth is -20 dB,
 * and a hundredth is -40 dB. The ear hears ratios, not differences (the
 * Weber-Fechner law), so a volume in dB feels even, and a volume in
 * plain amplitude does not: most of a linear slider's travel sounds
 * loud.
 *
 * References: Curtis Roads, The Computer Music Tutorial, 1996, chapter
 * 2; the bel is named after Alexander Graham Bell (Bell Labs, 1920s). *)

(* ix: copied from libs/audio/signal/Mix.mli
 * in the author's playground (docs/plans/plan_audio.md). Its optional
 * arguments are required here. *)

(* [add sounds] sums the sounds; the result is as long as the longest
 * (the shorter ones are silent after their end) *)
val add : Signal.t list -> Signal.t

(* [gain g s] multiplies each sample by [g] *)
val gain : float -> Signal.t -> Signal.t

(* [delay seconds s] is [s] starting [seconds] later, with silence
 * before *)
val delay : float -> Signal.t -> Signal.t

(* [then_ a b] plays [b] right after [a] *)
val then_ : Signal.t -> Signal.t -> Signal.t

(* [decibels ratio] is 20 log10 ratio: -6.02 for 0.5 *)
val decibels : float -> float

(* [of_decibels db] is the amplitude ratio: 0.1 for -20 *)
val of_decibels : float -> float

(* These keep one sample within [-1, 1]: [clip] cuts it flat, and
 * [soft_clip] bends it by tanh. The tanh is a rational function close
 * to it, unless [exact_tanh] is set, in which case it is libc's. *)
val clip : float -> float
val soft_clip : float -> float
val exact_tanh : bool ref

(* [limit ~soft s] clips every sample: hard, or soft if [soft] *)
val limit : soft:bool -> Signal.t -> Signal.t
