(* A keyboard and a mouse (USB's class of "human interface devices";
 * principia's usb/kb): each an interface of a device, with an endpoint
 * that is asked again and again and gives a report, the device's
 * state. By the boot protocol, the one every keyboard and mouse has
 * for a BIOS, a report's bytes are fixed: no report descriptor to
 * read. Here is what a report means; who reads the endpoint, and where
 * the keys and the moves go, is the caller's (a process of mini-usbd's
 * that writes the kernel's files; the kernel's clock).
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
 * A report is a state, not an event: what is held now. The events
 * a PC keyboard sends (down, up) are the difference between two
 * reports, which is why [typed] carries the one before.
 *
 * cs-history:
 * HID in full has each device describe its own reports, in a small
 * language of fields and usages that covers joysticks, tablets and
 * dials; reading it is a parser. The boot protocol is the fixed
 * subset a PC's firmware could handle in its setup screen with no
 * such parser, and every keyboard and mouse still offers it: six
 * keys at once at most, which is where that limit of cheap
 * keyboards comes from. *)

(* A mouse's report by its own description: where its fields are (a
 * field: after the report's number if it has one, from which bit, how
 * many, signed or not), the generic desktop's X, Y and wheel and the
 * buttons by their number (1 left, 2 right, 3 middle). A mouse is read
 * by the boot protocol's 3 bytes, or by its layout: by the boot
 * protocol a mouse need not say its wheel, and a real one does not
 * (the author's on the Pi 2: "the mouse wheel didn't seem to work";
 * QEMU's sends a 4th byte anyway) *)
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

(* an interface that is a keyboard's or a mouse's (class 3, the boot
 * subclass), with the endpoint its reports come from (a mouse: Boot,
 * until its layout is read) *)
val driven : Usbdesc.interface -> (kind * Usbdesc.endpoint) option

(* how often the device is to say its state unasked, in 4 ms (USB's
 * SET_IDLE): a keyboard every 32 ms, a mouse only when it changes *)
val idle : kind -> int

(* A keyboard's reports (8 bytes: the modifiers, 0, six keys held), one
 * after the other: [typed state report] is the scancodes to give for
 * it, a PC keyboard's (each a string: one byte, or two, 0xe0 first; a
 * key up has 0x80 more), and the state for the next report. A key
 * held repeats: the keyboard says its state every 32 ms, changed or
 * not, and a key held 5 reports (160 ms) is given again at each one:
 * no clock, no process more (kb.c has one for that). *)
type keyboard
val keyboard : keyboard

(* [report_length conf iface]: how long the interface's report
 * descriptor is (its HID descriptor, in the configuration's), 0 if
 * not said *)
val report_length : string -> int -> int

(* a report descriptor read: the mouse's layout, or None (no X and Y
 * found). Plan 9's usb/kb reads it too; the subset of HID a mouse uses:
 * Input items, usages, usage ranges, report numbers *)
val layout : string -> layout option
val typed : keyboard -> string -> keyboard * string list

(* a mouse's report (by the boot protocol: the buttons, how far right,
 * how far down, maybe the wheel; else by its layout): how far it moved,
 * and its buttons as Plan 9's (1 left, 2 middle, 4 right; 8 the wheel
 * turned away, 16 towards you); None for a report that is not it (too
 * short, another report's number) *)
val moved : mouse -> string -> (int * int * int) option
