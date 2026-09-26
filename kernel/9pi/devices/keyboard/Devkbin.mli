(* '#Ι', the keyboard's scan codes from outside the kernel (principia's
 * devkbin.c): usb/kb writes the USB keyboard's keys, as a PC keyboard's
 * scan codes, to #Ι/kbin (one writer at a time); Kbd turns them into
 * the console's input. *)

(* the device registered *)
val init : unit -> unit
