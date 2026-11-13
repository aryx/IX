(* A keyboard and a mouse (USB's class of "human interface devices";
 * principia's usb/kb). Each is an interface of a device, with an
 * endpoint that is asked again and again and gives a report: the
 * device's state. In the boot protocol, which every keyboard and mouse
 * has for a BIOS, a report's bytes are fixed, and there is no report
 * descriptor to read. This module says what a report means. Reading
 * the endpoint, and sending the keys and the moves somewhere, is the
 * caller's job (a process of mini-usbd's that writes the kernel's
 * files, or the kernel's clock).
 *
 *     a keyboard's report        02 00 04 00 00 00 00 00
 *                                |     '- the keys held, 6 at most:
 *                                |        4 is A's number
 *                                '- the modifiers, a bit each:
 *                                   02 is the left Shift
 *     the report before had neither: the scan codes 2a, then 1e
 *     (a PC keyboard's Shift down, A down: Kbd makes the rune A)
 *
 *     a mouse's report           01 03 01
 *                                the left button, 3 right, 1 down
 *
 * A report is a state, not an event: it says what is held now. The
 * events a PC keyboard sends (down, up) are the difference between
 * two reports, which is why [typed] carries the report before.
 *
 * cs-history:
 * HID in full has each device describe its own reports, in a small
 * language of fields and usages that covers joysticks, tablets and
 * dials, and reading it takes a parser. The boot protocol is the fixed
 * subset that a PC's firmware could handle in its setup screen with no
 * such parser, and every keyboard and mouse still offers it. It allows
 * six keys at once at most, which is where that limit of cheap
 * keyboards comes from. *)

(* A mouse's report, read by its own description. The layout says where
 * its fields are: the generic desktop's X, Y and wheel, and the buttons
 * by their number (1 left, 2 right, 3 middle). A field is located
 * after the report's number, if it has one, by the bit it starts at
 * and how many bits it has, and it is signed or not. A mouse is read
 * either by the boot protocol's 3 bytes, or by its layout: in the boot
 * protocol a mouse need not say its wheel, and a real one does not
 * (the author's, on the Pi 2: "the mouse wheel didn't seem to work";
 * QEMU's sends a 4th byte anyway). *)
type field = { at : int; bits : int; signed : bool }
type layout = {
  id : int;
  x : field;
  y : field;
  wheel : field option;
  buttons : (int * field) list;
}

type mouse = Boot | Report of layout
type kind = Keyboard | Mouse of mouse

(* [driven iface] tells whether an interface is a keyboard's or a
 * mouse's (class 3, the boot subclass), and returns the endpoint its
 * reports come from (a mouse is Boot until its layout is read) *)
val driven : Usbdesc.interface -> (kind * Usbdesc.endpoint) option

(* how often the device is to say its state unasked, in units of 4 ms
 * (USB's SET_IDLE): a keyboard every 32 ms, and a mouse only when its
 * state changes *)
val idle : kind -> int

(* A keyboard's reports (8 bytes: the modifiers, 0, and six keys held)
 * come one after the other. [typed state report] returns the scancodes
 * to give for the report, a PC keyboard's (each is a string of one
 * byte, or of two with 0xe0 first; a key up has 0x80 added), and the
 * state for the next report. A key held repeats: the keyboard says its
 * state every 32 ms, changed or not, and a key held for 5 reports (160
 * ms) is given again at each one. This needs no clock and no extra
 * process (kb.c has one for that). *)
type keyboard
val keyboard : keyboard

(* [report_length conf iface] returns how long the interface's report
 * descriptor is (as its HID descriptor, in the configuration's
 * descriptor, says), or 0 if it is not said *)
val report_length : string -> int -> int

(* [layout desc] reads a report descriptor, and returns the mouse's
 * layout, or None when no X and Y are found. Plan 9's usb/kb reads it
 * too. It handles the subset of HID that a mouse uses: Input items,
 * usages, usage ranges and report numbers. *)
val layout : string -> layout option
val typed : keyboard -> string -> keyboard * string list

(* [moved mouse report] reads a mouse's report (in the boot protocol:
 * the buttons, how far right, how far down, and maybe the wheel;
 * otherwise by its layout). It returns how far the mouse moved, and
 * its buttons as Plan 9 numbers them (1 left, 2 middle, 4 right; 8 for
 * the wheel turned away, 16 for towards you). It returns None for a
 * report that is not the mouse's (too short, or with another report's
 * number). *)
val moved : mouse -> string -> (int * int * int) option
