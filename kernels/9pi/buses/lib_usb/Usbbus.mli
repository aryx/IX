(* This module finds the USB devices and starts them (what Plan 9's
 * usbd does, called the enumeration). Starting from the root hub, the
 * controller's own, it looks at each hub's ports, by requests to the
 * hub. At a port where something is plugged:
 * - the port is reset (the device then listens at address 0);
 * - a new device is made for it;
 * - the device is told its address;
 * - the device is asked what it is.
 * A hub is one more hub to look at; a keyboard or a mouse is set up
 * (Hid) and handed to the caller.
 *
 * It is written once, for a program and for the kernel. What differs
 * is in ['d io]: how a device (a ['d], which is its endpoint 0) is
 * reached. An io function that fails raises Failure.
 *
 *     the root hub (the controller's)       ['d] is     its requests go
 *       port 1: a hub         device 2      for usbd    through files
 *         port 1: a keyboard  device 3      Usbdev.t    (#u: Devusb)
 *         port 2: a mouse     device 4      for Kusb    straight to
 *         port 3: nothing                   Usb.ep      Devusb's code
 *
 * A hub is a device like any other, whose requests are about its
 * ports: is something there, reset it, is it low or full speed. So
 * finding everything is a walk of a tree, and doing [look] again and
 * again is all that plugging and unplugging need.
 *
 * design:
 * There is one driver, with two homes. The record of functions is the
 * driver's whole view of the world: hand it the kernel's own functions
 * or a program's files, and the same 150 lines run in either place.
 * This is also how ix keeps one FAT (lib_fat's Fat, under Kdos and
 * under dossrv). It turns the question of where a driver should live
 * into one that can be tried both ways rather than argued. *)

type 'd io = {
  name : 'd -> string;                                (* for a message: ep3.0 *)
  number : 'd -> int;                                 (* the address it is to have: 3 *)
  (* a control request with no answer, and one with an answer of count
   * bytes at most (with Usbdesc.setup's arguments) *)
  send : 'd -> int -> int -> int -> int -> string -> unit;
  ask : 'd -> int -> int -> int -> int -> int -> string;
  (* what the kernel's Devusb is told of a device, as the words of its
   * ctl file: "hub", "address", "maxpkt 8", "detach" *)
  set : 'd -> string -> unit;
  (* [child] makes a new device at a hub's port, of a speed ("low",
   * "full", "high"), with its endpoint 0 ready for requests; [drop]
   * lets a device go *)
  child : 'd -> string -> int -> 'd;
  drop : 'd -> unit;
  (* waits, in ms *)
  pause : int -> unit;
  (* says that a keyboard's or a mouse's reports are to be read from
   * now on, given the device and its interface's endpoint *)
  drive : 'd -> Hid.kind -> Usbdesc.endpoint -> unit;
  (* says what is started (usbd's "usb/kb... ") *)
  say : string -> unit;
}

(* the hubs known, and what is at their ports *)
type 'd t

(* [start io root nports] starts from the root hub, which has nports
 * ports; nothing is looked at yet *)
val start : 'd io -> 'd -> int -> 'd t
(* looks once at every port of every hub: a device that came is
 * started, and one that went is forgotten. It returns true when
 * something changed. *)
val look : 'd t -> bool

(* when true, each step is said (what a port answers, what a device says
 * it is), to find why a board's device is not started when an
 * emulator's is *)
val verbose : bool ref
