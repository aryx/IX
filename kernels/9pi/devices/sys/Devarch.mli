(* '#P', the machine's files (principia's arm devarch.c): cputype,
 * cputemp. *)

(* the processor's speed in MHz, measured at the start (Machine.cpu_mhz):
 * cputype's last word, the banner's "cpu0:" line *)
val mhz : int

(* the device registered *)
val init : unit -> unit
