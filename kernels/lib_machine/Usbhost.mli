(* The kernels' USB keyboard and mouse (as xv6 arm-pi1's CSUD finds its
 * keyboard, simpler): the DWC2 controller (usb.c's two primitives, both
 * boards), the hub on its root port (QEMU puts one there), and behind
 * the hub the HID devices in their boot protocol -- a keyboard, a
 * mouse. Everything is polled: the transfers to their end, and the
 * devices' interrupt endpoints at each tick (a NAK: nothing new).
 *
 * Written for mini-xv6 and once its own; here since other kernels use
 * it (mini-oberon), each saying at [init] what a key and a move are to
 * it. mini-9pi has its own (its usbd is a program). Not one of the
 * modules every kernel links (mkkernel's LIB_ML): a kernel names it. *)

(* the controller started, the devices found (none: nothing).
 * [init key pointer]: [key c] is called for a key pressed, its
 * character's code (US keys, Shift, Control: a letter's low 5 bits),
 * as the UART's are; [pointer dx dy buttons] for the mouse's report
 * (dy downwards, the buttons' bits as the HID's: 1 left, 2 right, 4
 * middle) *)
val init : (int -> unit) -> (int -> int -> int -> unit) -> unit

(* the devices' reports read, the keys and moves handled *)
val poll : unit -> unit
