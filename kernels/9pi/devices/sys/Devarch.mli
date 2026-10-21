(* '#P', the machine's files (principia's arm devarch.c): cputype (its
 * last word the processor's speed in MHz, measured now when the board
 * says it), cputemp (the chip's degrees); and cputhrottle, ix's: the
 * firmware's throttling (under-voltage, the frequency capped,
 * throttled, the soft temperature limit), now and since the boot. A
 * board slowing itself under a long load shows there. *)

(* the processor's speed in MHz, measured at the start (Machine.cpu_mhz):
 * cputype's last word, the banner's "cpu0:" line *)
val mhz : int

(* the processor's name: "1176JZF-S", "Cortex-A7", "Cortex-A53", "Cortex-A72" *)
val cpu : string

(* the firmware's revision: 9pi's banner's number (the second its files
 * were built at, since 1970; 346337 under the emulators), and the day
 * that is, "2026-09-14" *)
val firmware : string
val firmware_date : string

(* the device registered *)
val init : unit -> unit
