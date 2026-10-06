(* The kernel as its own usbd: the USB keyboard and mouse found and
 * read by the kernel, with no program (Plan 9's way is a program,
 * usbd: ../buses/user/usbd is ix's; this is the other way, a kernel's
 * usual one, with the same code: lib_usb's Usbbus and Hid). The boot
 * script chooses: "echo kernel > '#u/usb/ctl'", or usbd.
 *
 * The bus is walked once, when asked, in the process that asked (it
 * may wait: a port's reset takes time). Then each device's reports
 * are read from the clock, a try a tick: mini-9pi has no process of
 * the kernel's own, and the clock must not wait. A keyboard's
 * scancodes go to Kbd, a mouse's moves to Devmouse: what usbd's
 * processes write to #Ι/kbin and #m/mousein.
 *
 * A device plugged or unplugged later is seen by a process of the
 * kernel's own, which looks at the ports once a second (a look waits,
 * which the clock cannot): mini-9pi's first kernel process. *)

(* the bus walked now (Devusb calls it: "kernel" written to its ctl) *)
val start : unit -> unit
(* a tick: each keyboard and mouse asked for a report *)
val clock : unit -> unit
