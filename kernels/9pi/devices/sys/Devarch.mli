(* '#P' holds the machine's files (principia's arm devarch.c):
 * - cputype, whose last word is the processor's speed in MHz, measured
 *   at each read when the board can say it;
 * - cputemp, the chip's temperature in degrees;
 * - cputhrottle, which is ix's own: the firmware's throttling
 *   (under-voltage, the frequency capped, throttled, the soft
 *   temperature limit), now and since the boot. A board that slows
 *   itself down under a long load shows it there. *)

(* the processor's speed in MHz, measured at the start (Machine.cpu_mhz).
 * It is cputype's last word, and the one on the banner's "cpu0:" line. *)
val mhz : int

(* the processor's name: "1176JZF-S", "Cortex-A7", "Cortex-A53", "Cortex-A72" *)
val cpu : string

(* the firmware's revision, which is the number on 9pi's banner (the
 * second, counted since 1970, at which its files were built; it is
 * 346337 under the emulators), and the day that second falls on, such
 * as "2026-09-14" *)
val firmware : string
val firmware_date : string

(* registers the device *)
val init : unit -> unit
