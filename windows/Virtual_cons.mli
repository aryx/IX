(* A window's console (rio's Qcons, Qconsctl; xix's Virtual_cons; and
 * 9front's kbd): what a program in a window opens as /dev/cons. *)

(* read: a line typed in the window, when there is one (the keys as
 * they come, when raw); written: text for the window *)
val cons : Device.t
(* "rawon" and "rawoff" written: the keys as they are typed, no line
 * kept and no echo; closed: the lines again *)
val consctl : Device.t
(* the keys held, for a program that asks (a game): a read is the next
 * change, as the kernel's /dev/kbd says it; kept from when it is opened *)
val kbd : Device.t
