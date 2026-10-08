(* '#u', USB (principia's devusb.c): the host controller's endpoints as
 * files, for usbd (the bus's enumeration, in user space) and the
 * devices' drivers (usb/kb...): #u/usb/ctl, and a directory epN.M (the
 * device N's endpoint M) per endpoint, its data (the transfers) and ctl
 * (its settings; ep0's: "new" endpoints, "newdev" devices on a hub...).
 * The root hub is a toy: its port's status, reset and enable. *)

(* claude: the enabled devices' endpoints 0, hubs' not; [newdevep ep0 nb
 * ttype mode] another endpoint of ep0's device (a kernel driver's:
 * Etherusb, its bulk endpoints) *)
val devices : unit -> Usb.ep list
val newdevep : Usb.ep -> int -> Usb.ttype -> int -> Usb.ep

(* claude: the kernel as its own usbd (Kusb), with no file between: a
 * device's ctl line; a hub's new device (its endpoint 0, held: not a
 * program's to open), of a speed, at a port; a control request (its 8
 * bytes and what it sends), count bytes of answer (the root hub's toy
 * answers too); the root hub's endpoint 0, once there. A write of
 * "kernel" to #u/usb/ctl calls [!kernel] (Kusb's start: it is linked
 * after, and says so here). *)
val control : Usb.ep -> string -> unit
val child : Usb.ep -> string -> int -> Usb.ep
val request : Usb.ep -> string -> int -> string
val the_root : Usb.ep option ref
val kernel : (unit -> unit) ref

(* the controller reset (usbreset, usbinit: its root hub, ep1.0) and the
 * device registered *)
val init : unit -> unit
