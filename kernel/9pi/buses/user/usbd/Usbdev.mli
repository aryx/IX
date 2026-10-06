(* A USB device as the kernel gives it (#u: principia's devusb.c, ix's
 * Devusb; usbd's library, its dev.c and parse.c): a directory
 * #u/usb/epN.M for the endpoint M of the device of number N, with two
 * files. ctl takes the endpoint's settings, as words; data is the
 * endpoint itself: for an endpoint 0, a write is a control request
 * (its 8 bytes, then what it sends) and a read gives what the device
 * answered. *)

type t = {
  name : string;                       (* ep3.0 *)
  id : int;                            (* the device's number: 3 *)
  ctl : Unix.file_descr;
  mutable data : Unix.file_descr option;
}

type caps = < Cap.open_in; Cap.open_out >

(* an endpoint by its name, its ctl opened; its data, for reading (0),
 * writing (1) or both (2) *)
val open_ : < caps; .. > -> string -> t
val open_data : < caps; .. > -> t -> int -> unit
val close : t -> unit

(* a line written to its ctl; what its ctl says *)
val ctl : t -> string -> unit
val said : t -> string

(* a control request to the device: [send d kind request value index
 * data] has no answer; [ask d kind request value index count] gives
 * the device's, count bytes at most. kind has the direction, whose
 * request it is (the standard's 0, a class's 0x20) and for what (the
 * device 0, an interface 1, another: a hub's port, 3). Unix_error when
 * the device refuses (it stalls) or is gone. *)
val send : t -> int -> int -> int -> int -> string -> unit
val ask : t -> int -> int -> int -> int -> int -> string

(* What a device says of itself (its configuration's descriptor): its
 * interfaces, each a class of device (3: HID, 9: a hub), a subclass
 * and a protocol, and its endpoints: a number, the direction, the
 * kind (3: interrupt), the largest packet, how often it is to be
 * asked (ms). *)
type endpoint = { number : int; input : bool; kind : int; maxpkt : int; interval : int }
type interface = { iface : int; cls : int; sub : int; proto : int; endpoints : endpoint list }

val interfaces : string -> interface list
