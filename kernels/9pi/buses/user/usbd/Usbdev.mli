(* A USB device as the kernel gives it to a program (#u: principia's
 * devusb.c, ix's Devusb; usbd's library, its dev.c): a directory
 * #u/usb/epN.M for the endpoint M of the device of number N, with two
 * files. ctl takes the endpoint's settings, as words; data is the
 * endpoint itself: for an endpoint 0, a write is a control request
 * (its 8 bytes, then what it sends) and a read gives what the device
 * answered. What fails raises Failure (the kernel's words). *)

type t = {
  name : string;                       (* ep3.0 *)
  id : int;                            (* the device's number: 3 *)
  ctl : Unix.file_descr;
  mutable data : Unix.file_descr option;
}

type caps = < Cap.open_in; Cap.open_out >

(* an endpoint by its name, its ctl opened; its data, for reading (0)
 * or for both (2) *)
val open_ : < caps; .. > -> string -> t
val open_data : < caps; .. > -> t -> int -> unit
val close : t -> unit

(* a line written to its ctl; what its ctl says *)
val ctl : t -> string -> unit
val said : t -> string

(* a control request to the device (Usbdesc.setup's arguments): one
 * with no answer; one with an answer, count bytes at most *)
val send : t -> int -> int -> int -> int -> string -> unit
val ask : t -> int -> int -> int -> int -> int -> string
