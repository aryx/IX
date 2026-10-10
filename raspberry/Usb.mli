(* USB devices, as QEMU's (plan_pi.md, phases B and J): the hub QEMU puts
 * on a one-port controller when a device is attached (hw/usb/dev-hub.c:
 * 8 ports, no power switching), its usb-kbd (hw/usb/dev-hid.c: a
 * full-speed boot keyboard) and usb-mouse (a boot mouse: 5 buttons,
 * relative motion, a wheel), with their descriptors byte for byte and
 * the requests the kernels send: the standard ones (descriptors,
 * address, configuration, status), the hub's (port status and
 * features: a port reset enables its device), the keyboard's (its
 * report of the keys held, idle, protocol, LEDs). A device's serial
 * number ends with its port path, as QEMU writes it ("68284-1.1").
 *
 * Endpoint 0's control transfers, and endpoint 1, the interrupt one
 * (claude: Plan 9's usb/kb reads the keyboard there, where CSUD, xv6's
 * driver, polls it with GET_REPORT): the keyboard's events queued and
 * reported one at a time, NAK when none (or no idle report due), as
 * QEMU's hid.c.
 *
 * A USB device says nothing by itself: the host asks, always, and
 * the device answers or says it has nothing (NAK). What is plugged
 * in is found by asking too, which is why a driver's first work is
 * a conversation, the enumeration. For the keyboard behind the hub,
 * each line a control transfer on endpoint 0, a SETUP packet of 8
 * bytes ([setup]) then data one way ([data_in], [data_out]):
 *
 *     the port is reset: the device answers at address 0
 *     80 06 00 01 00 00 12 00   GET_DESCRIPTOR, device, 18 bytes:
 *                               who are you? a vendor, a product
 *     00 05 02 00 00 00 00 00   SET_ADDRESS 2: from now on, device 2
 *     80 06 00 02 ...           GET_DESCRIPTOR, configuration: its
 *                               interfaces (a HID, boot keyboard)
 *                               and endpoints (1, in, interrupt)
 *     00 09 01 00 00 00 00 00   SET_CONFIGURATION 1: start
 *
 * and then, as often as the endpoint's descriptor asks, the host
 * reads endpoint 1, and gets the keyboard's whole state in 8 bytes,
 * not an event:
 *
 *     02 00 04 00 00 00 00 00   Shift is down (a bit of byte 0), and
 *                               the key 0x04, which is "a": an A.
 *                               Up to six keys, by where they are
 *                               on the keyboard, not by letter.
 *
 * The driver finds what changed since the last report, and it is
 * the kernel's table that makes 0x04 an a, or a q on a French
 * keyboard. A hub is a device like another, whose requests are
 * about its ports; the tree of hubs and devices is the bus.
 *
 * Where it stands: Dwc2, the controller, carries the kernel's
 * transfers to [setup], [data_in] and [data_out]; Main turns the
 * host's keys and mouse into [key] and [pointer]; Usernet is behind
 * [net]. The other side is the kernel's USB stack, a large driver
 * for what a PS/2 keyboard did with one interrupt and one byte a
 * key.
 *
 * design:
 * Descriptors make the bus self-describing: a device carries, in a
 * fixed format, what it is and how to talk to it, and a class (HID,
 * mass storage, hub) is a contract that lets one driver serve every
 * device of that kind from any maker. The boot protocol of
 * keyboards, the fixed 8 bytes above, is the same idea pushed
 * further for a BIOS, which has no room to read a report's
 * description.
 *
 * References: USB 2.0 specification, chapters 9 and 11 (from memory);
 * HID 1.11 (from memory); QEMU's hw/usb/dev-hub.c, dev-hid.c, desc.c
 * (read 2026-09-25). *)

type device

type result = Data of string | Stall | Nak | Babble

(* a hub on [path] with devices on its first ports *)
val hub : path:string -> device list -> device

(* a keyboard, a mouse on [path] *)
val keyboard : path:string -> unit -> device
val mouse : path:string -> unit -> device

(* claude: QEMU's usb-net (its CDC Ethernet configuration: frames on
 * bulk endpoints 0x82, 0x02) on [path]; a frame given to the guest
 * (queued: its bulk IN's next reads), and where the guest's go *)
val net : path:string -> unit -> device
val net_input : device -> string -> unit
val net_output : device -> (string -> unit) -> unit

(* a bus reset: address 0, unconfigured; a hub's ports powered, a
 * device on one connected (a change) *)
val reset : device -> unit

(* the device of an address, under this one through hubs' enabled ports *)
val find : device -> int -> device option

(* the packets: endpoint 0's SETUP (8 bytes), its data stage's IN (up to
 * a length) or OUT, its status stage's empty ones; endpoint 1's IN,
 * the interrupt endpoint (the keyboard's reports, the hub's changes);
 * [now] the board's time in microseconds (the keyboard's idle rate) *)
val setup : device -> now:int -> string -> result
val data_in : device -> now:int -> ep:int -> int -> result
val data_out : device -> ep:int -> string -> result

(* a key pressed or released on a keyboard, by its HID usage (0x04 a,
 * 0x28 Enter, 0xe0-0xe7 the modifiers): queued, the reports applying
 * the events one at a time *)
val key : device -> int -> bool -> unit

(* the LEDs the host set (bit 0 Num Lock, 1 Caps Lock, 2 Scroll Lock) *)
val leds : device -> int

(* the host's input to a mouse, as QEMU's input events: relative
 * motion, a button (its bit: 1 left, 2 right, 4 middle) down or up, the
 * wheel (-1 up); [pointer d inputs] applies them, then syncs (one event
 * the guest will read, or motion added to the unread one before) *)
type input = Rel_x of int | Rel_y of int | Button of int * bool | Wheel of int
val pointer : device -> input list -> unit
