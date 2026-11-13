(* '#u' is USB (principia's devusb.c): the host controller's endpoints
 * as files, for usbd (the bus's enumeration, in user space) and for
 * the devices' drivers (usb/kb...). There is #u/usb/ctl, and a
 * directory epN.M (the device N's endpoint M) for each endpoint. That
 * directory has a data file (for the transfers) and a ctl file (for
 * the endpoint's settings; ep0's ctl also takes "new" for new
 * endpoints, "newdev" for devices on a hub, and so on). The root hub is
 * a toy: it has only its port's status, reset and enable.
 *
 * Here is USB in mini-9pi, as the way of a key from the keyboard to a
 * program:
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
 * What this file gives a program is only transport: bytes to an
 * endpoint, bytes from it, and the endpoint's settings as words
 * written to its ctl. On this path, the kernel does not know which
 * device is a keyboard, nor what its bytes mean.
 *
 * plan9-is-cleaner:
 * A USB driver is a program that opens files. The kernel has the
 * controller's driver and this device, some 3,000 lines in 9pi, and
 * everything about kinds of devices (hubs, keyboards, disks, audio,
 * serial lines) is outside, in programs that usbd starts as devices
 * are plugged. A bug in a driver kills a program. Linux allows the
 * same (usbfs, libusb), but by habit its drivers are kernel modules.
 *
 * cs-history:
 * USB (1996, from a group of computer makers, Intel among them)
 * replaced the PC's separate plugs for keyboard, mouse, printer and
 * serial line with one bus, where the host asks and the devices only
 * answer. A device cannot interrupt, so a keyboard is polled, many
 * times a second, and a tree of hubs can be walked from the root to
 * find what is there. That walk, and the descriptors a device answers
 * with, are in Usbbus and Usbdesc.
 *
 * References: usb(3) and usb(4) in the Plan 9 manual. The USB 2.0
 * specification (2000), chapters 5 (transfers), 9 (requests and
 * descriptors) and 11 (hubs). principia's Kernel.nw (devusb.c). *)

(* [devices ()] returns the endpoints 0 of the enabled devices, except
 * the hubs'. [newdevep ep0 nb ttype mode] makes another endpoint of
 * ep0's device (for a kernel driver: Etherusb makes its bulk endpoints
 * this way). *)
val devices : unit -> Usb.ep list
val newdevep : Usb.ep -> int -> Usb.ttype -> int -> Usb.ep

(* The kernel as its own usbd (Kusb), with no file between:
 * - [control ep line] writes a line to a device's ctl;
 * - [child hub speed port] makes a hub's new device, of a speed, at a
 *   port, and returns its endpoint 0, held (it is not a program's to
 *   open);
 * - [request ep s count] makes a control request (its 8 bytes and what
 *   it sends) and returns count bytes of answer (the root hub's toy
 *   answers too);
 * - [the_root] is the root hub's endpoint 0, once it is there.
 * A write of "kernel" to #u/usb/ctl calls [!kernel], which is Kusb's
 * start: Kusb is linked after this module, and sets it here. *)
val control : Usb.ep -> string -> unit
val child : Usb.ep -> string -> int -> Usb.ep
val request : Usb.ep -> string -> int -> string
val the_root : Usb.ep option ref
val kernel : (unit -> unit) ref

(* resets the controller (usbreset, usbinit: its root hub, ep1.0) and
 * registers the device *)
val init : unit -> unit
