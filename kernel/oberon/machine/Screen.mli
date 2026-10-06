(* Not a link: what machine/Usbhost (mini-xv6's USB, by its link) calls
 * when the mouse moves, a module of this name. mini-xv6's Screen moves
 * its console's cursor; here it is Oberon's Input that is told. *)
val pointer : int -> int -> int -> unit
