(* '#Ι' takes the keyboard's scan codes from outside the kernel
 * (principia's devkbin.c). usb/kb writes the USB keyboard's keys to
 * #Ι/kbin, as a PC keyboard's scan codes (one writer at a time), and Kbd
 * turns them into the console's input. *)

(* registers the device *)
val init : unit -> unit
