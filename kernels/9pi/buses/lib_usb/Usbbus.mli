(* The USB devices found and started (what Plan 9's usbd does, called
 * the enumeration): from the root hub, the controller's own, each
 * hub's ports are looked at, by requests to the hub. At a port where
 * something is plugged: the port is reset (the device then listens at
 * address 0), a new device is made for it, it is told its address,
 * and asked what it is. A hub is one more hub to look at; a keyboard
 * or a mouse is set up (Hid) and handed to the caller.
 *
 * Written once for a program and for the kernel: what differs is in
 * ['d io], how a device (a ['d]: its endpoint 0) is reached. An io's
 * function that fails raises Failure.
 *
 *     the root hub (the controller's)       ['d] is     its requests go
 *       port 1: a hub         device 2      for usbd    through files
 *         port 1: a keyboard  device 3      Usbdev.t    (#u: Devusb)
 *         port 2: a mouse     device 4      for Kusb    straight to
 *         port 3: nothing                   Usb.ep      Devusb's code
 *
 * A hub is a device like another whose requests are about its
 * ports: is something there, reset it, is it low or full speed. So
 * finding everything is a walk of a tree, and [look] done again and
 * again is all that plugging and unplugging need.
 *
 * design:
 * One driver, two homes. The record of functions is the driver's
 * whole view of the world; hand it the kernel's own or a program's
 * files and the same 150 lines run in either place. It is how ix
 * keeps one FAT too (lib_fat's Fat under Kdos and under dossrv),
 * and what makes the question of where a driver should live one
 * that can be tried both ways rather than argued. *)

type 'd io = {
  name : 'd -> string;                                (* for a message: ep3.0 *)
  number : 'd -> int;                                 (* the address it is to have: 3 *)
  (* a control request with no answer; one with an answer, count bytes
   * at most (Usbdesc.setup's arguments) *)
  send : 'd -> int -> int -> int -> int -> string -> unit;
  ask : 'd -> int -> int -> int -> int -> int -> string;
  (* what the kernel's Devusb is told of a device, as the words of its
   * ctl file: "hub", "address", "maxpkt 8", "detach" *)
  set : 'd -> string -> unit;
  (* a new device at a hub's port, of a speed ("low", "full", "high"),
   * its endpoint 0 ready for requests; a device let go *)
  child : 'd -> string -> int -> 'd;
  drop : 'd -> unit;
  (* a wait, in ms *)
  pause : int -> unit;
  (* a keyboard's or a mouse's reports are to be read from now on: the
   * device, its interface's endpoint *)
  drive : 'd -> Hid.kind -> Usbdesc.endpoint -> unit;
  (* what is started, said (usbd's "usb/kb... ") *)
  say : string -> unit;
}

(* the hubs known, and what is at their ports *)
type 'd t

(* from the root hub, which has so many ports; nothing looked at yet *)
val start : 'd io -> 'd -> int -> 'd t
(* every port of every hub looked at once: a device that came is
 * started, one that went is forgotten; true when something changed *)
val look : 'd t -> bool

(* each step said (what a port answers, what a device says it is): to
 * find why a board's device is not started, which an emulator's is *)
val verbose : bool ref
