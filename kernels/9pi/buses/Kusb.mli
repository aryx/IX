(* The kernel as its own usbd: the kernel finds the USB keyboard and
 * mouse and reads them, with no program. Plan 9's way is a program,
 * usbd (ix's is in ../buses/user/usbd). This is the other way, the
 * usual one for a kernel, with the same code: lib_usb's Usbbus and
 * Hid. The boot script chooses between them: it runs either "echo
 * kernel > '#u/usb/ctl'" or usbd.
 *
 * The bus is walked once, when asked, in the process that asked (that
 * process may wait, because a port's reset takes time). Then each
 * device's reports are read from the clock, up to 16 of them a tick (a
 * device is asked again while it answers), and the clock must not
 * wait. A keyboard's scancodes go to Kbd, and a mouse's moves go to
 * Devmouse; this is what usbd's processes write to #Ι/kbin and
 * #m/mousein.
 *
 * A device plugged or unplugged later is seen by a process of the
 * kernel's own, which looks at the ports once a second (a look waits,
 * which the clock cannot do). It is mini-9pi's first kernel process. *)

(* walks the bus now (Devusb calls it when "kernel" is written to its
 * ctl) *)
val start : unit -> unit
(* at a tick, asks each keyboard and mouse for a report *)
val clock : unit -> unit
