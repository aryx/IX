(* A keyboard and a mouse (USB's class of "human interface devices";
 * principia's usb/kb): each an interface of a device, with an endpoint
 * that is asked again and again and gives a report, the device's
 * state. By the boot protocol, the one every keyboard and mouse has
 * for a BIOS, a report's bytes are fixed: no report descriptor to
 * read. A keyboard's becomes scancodes, a PC keyboard's, written to
 * the kernel's #Ι/kbin (its Kbd does the rest: the characters, Shift,
 * Alt); a mouse's becomes a line for #m/mousein, how far it moved and
 * its buttons. So the driver of a device is a program, and the kernel
 * has two files for it to write. *)

type caps = < Usbdev.caps; Cap.fork >

(* a device's interface, if a keyboard's or a mouse's: set up, and a
 * process started that reads its reports until the device is gone;
 * false for another interface *)
val start : < caps; .. > -> Usbdev.t -> Usbdev.interface -> bool

(* a keyboard's report (its 8 bytes: the modifiers, 0, six keys held)
 * after another: the scancodes for what changed, each a string to
 * write (one byte, or two: 0xe0 first) *)
val scancodes : string -> string -> string list
(* a mouse's report (the buttons, how far right, how far down, the
 * wheel): the line for the kernel *)
val mouse_line : string -> string
