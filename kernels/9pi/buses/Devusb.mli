(* '#u', USB (principia's devusb.c): the host controller's endpoints as
 * files, for usbd (the bus's enumeration, in user space) and the
 * devices' drivers (usb/kb...): #u/usb/ctl, and a directory epN.M (the
 * device N's endpoint M) per endpoint, its data (the transfers) and ctl
 * (its settings; ep0's: "new" endpoints, "newdev" devices on a hub...).
 * The root hub is a toy: its port's status, reset and enable.
 *
 * USB in mini-9pi, a key's way from the keyboard to a program:
 *
 *     the keyboard            holds the keys' state; says it when asked
 *     Usbdwc                  the controller: a transfer on an endpoint
 *     Devusb  #u              the endpoint as files: ep3.1/data
 *     - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 *     usbd, a program         or      Kusb, in the kernel
 *       Usbdev: the files               Usbdwc called directly
 *       Usbbus: find the devices        Usbbus: the same code
 *       Hid: a report to scan codes     Hid: the same code
 *       write to kbin (Devkbin)         Kbd.kbdputsc
 *     - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 *     Kbd                     scan codes to runes
 *     Devcons                 the console's input: a program's read
 *
 * What this file gives a program is only transport: bytes
 * to an endpoint, bytes from it, and the endpoint's settings as
 * words written to its ctl. Which device is a keyboard, and what
 * its bytes mean, the kernel does not know on this path.
 *
 * plan9-is-cleaner:
 * A USB driver is a program that opens files. The kernel has the
 * controller's driver and this device, some 3,000 lines in 9pi,
 * and everything about kinds of devices (hubs, keyboards, disks,
 * audio, serial lines) is outside, started by usbd as devices are
 * plugged. A driver's bug kills a program. Linux allows the same
 * (usbfs, libusb) but its drivers are by habit kernel modules.
 *
 * cs-history:
 * USB (1996, from a group of computer makers, Intel among them)
 * replaced the PC's separate plugs for keyboard, mouse, printer and
 * serial line with one bus where the host asks and devices only
 * answer: a device cannot interrupt, so a keyboard is polled, many
 * times a second, and a tree of hubs can be walked from the root to
 * find what is there. That walk, and the descriptors a device
 * answers with, are Usbbus and Usbdesc.
 *
 * References: usb(3) and usb(4) in the Plan 9 manual. The USB 2.0
 * specification (2000), chapters 5 (transfers), 9 (requests and
 * descriptors) and 11 (hubs). principia's Kernel.nw (devusb.c). *)

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
