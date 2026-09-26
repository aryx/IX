(* A USB Ethernet adapter's driver in the kernel (the plan's decision 5b;
 * 9front's etherusb.c's idea): a CDC Ethernet (ECM) device, QEMU's
 * usb-net, found among those usbd enumerated (usbd has no driver for
 * it and leaves it be), its configuration 1 set (ECM: QEMU lists RNDIS
 * first), its MAC address from its string descriptor. A frame goes out
 * on its bulk OUT endpoint in 64-byte packets (a zero-length one after
 * a multiple of 64); frames come in on bulk IN, a transfer kept pending
 * on the controller's second channel, polled from the clock
 * (Usbdwc.inpoll): each finished one a frame. *)

(* the adapter found and set up, or not: its MAC address (6 bytes) *)
val probe : unit -> string option

(* a frame sent (padded to 60 bytes) *)
val send : string -> unit

(* the frames that came in since the last poll (the clock's) *)
val poll : unit -> string list
