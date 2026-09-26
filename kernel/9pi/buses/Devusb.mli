(* '#u', USB (principia's devusb.c): the host controller's endpoints as
 * files, for usbd (the bus's enumeration, in user space) and the
 * devices' drivers (usb/kb...): #u/usb/ctl, and a directory epN.M (the
 * device N's endpoint M) per endpoint, its data (the transfers) and ctl
 * (its settings; ep0's: "new" endpoints, "newdev" devices on a hub...).
 * The root hub is a toy: its port's status, reset and enable. *)

(* the controller reset (usbreset, usbinit: its root hub, ep1.0) and the
 * device registered *)
val init : unit -> unit
