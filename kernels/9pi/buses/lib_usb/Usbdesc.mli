(* What a USB device says of itself, and how it is asked (in USB's
 * standard, chapter 9's requests and descriptors). This is the part of
 * a USB driver that is the same wherever it runs. This directory is
 * used by a program (mini-usbd, in ../user/usbd) and by the kernel
 * (Kusb), so it keeps to what the compilers of both have.
 *
 *     three requests a new device is sent, on its endpoint 0
 *
 *     setup 0x00 5 3 0 0           00 05 03 00 00 00 00 00
 *       SET_ADDRESS: it is device 3 from now on
 *     setup 0x80 6 0x0100 0 18     80 06 00 01 00 00 12 00
 *       GET_DESCRIPTOR, the device's: 18 bytes come back, with who
 *       made it, what it is, how many configurations it has
 *     setup 0x80 6 0x0200 0 n      80 06 00 02 00 00 n ...
 *       GET_DESCRIPTOR, a configuration's: its interfaces and their
 *       endpoints, one after the other, each with a length, a type
 *       and its fields ([interfaces] reads them)
 *
 * A device describes itself: the host needs no table of what exists to
 * learn that this one is a keyboard (an interface of class 3) with one
 * endpoint to ask at the interval it names. One device may be several
 * things at once, with an interface for each. *)

(* [setup kind request value index count] makes a control request's
 * first 8 bytes. kind has the direction (0x80: the device answers),
 * whose request it is (0 for the standard's, 0x20 for a class's), and
 * what it is for (0 for the device, 1 for an interface, 3 for another
 * thing, such as a hub's port). count is how many bytes follow, or are
 * asked for. *)
val setup : int -> int -> int -> int -> int -> string

(* a number of two bytes in a descriptor, the low one first *)
val le16 : string -> int -> int

(* A configuration's descriptor gives the device's interfaces. Each
 * interface has a class of device (3: HID, 9: a hub), a subclass, a
 * protocol, and its endpoints. Each endpoint has a number, the
 * direction, the kind (3: interrupt), the largest packet, and how often
 * it is to be asked (in ms). *)
type endpoint = { number : int; input : bool; kind : int; maxpkt : int; interval : int }
type interface = { iface : int; cls : int; sub : int; proto : int; endpoints : endpoint list }

val interfaces : string -> interface list
