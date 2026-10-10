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
 * modules every kernel links (mkkernel's LIB_ML): a kernel names it.
 *
 * USB is a tree with the computer at its root, and only the root
 * speaks: a device answers when it is asked, never by itself.
 *
 *     the controller (DWC2), the host
 *        '-- its one port: a hub, address 1
 *              |-- port 1: a keyboard, address 2
 *              '-- port 2: a mouse, address 3
 *
 * A device just plugged answers at address 0. Finding it (its
 * enumeration) is a conversation on its endpoint 0, each step a
 * control transfer of 8 bytes that say what is asked: its device
 * descriptor's first 8 bytes (which give the size of its packets),
 * an address set, its configuration descriptor, read for an
 * interface of class 3 (HID, human interface device), subclass 1
 * (boot), protocol 1 (a keyboard) or 2 (a mouse) and for that
 * interface's interrupt endpoint; then the configuration is set and
 * the boot protocol asked for. The hub is found the same way, and
 * its ports are then powered and reset one by one through it.
 *
 * After that, a report at each poll of the interrupt endpoint (the
 * name is USB's: there is no interrupt, the host asks at an
 * interval), in the boot protocol's fixed shapes:
 *
 *     a keyboard, 8 bytes    modifiers (bits: 0x11 the Controls, 0x22
 *                            the Shifts), 0, then up to 6 keys held,
 *                            each a usage: 0x04 is a, 0x1e is 1
 *     a mouse, 3 bytes       the buttons, dx, dy (signed)
 *
 * A keyboard says what is held, not what happened: a key is new, and
 * given to [key], when it is in this report and was not in the last.
 * A key held does not repeat.
 *
 * terminology:
 * The boot protocol is HID's simple half. A HID device describes its
 * reports in a small language (the report descriptor: which bits are
 * what), and a full driver interprets it; a keyboard or a mouse may
 * also be told to send the fixed reports above, so that a BIOS
 * could read keys without that interpreter. A kernel that wants
 * only keys and moves is in the BIOS's place.
 *
 * others:
 * A driver that polls and waits for each transfer's end holds the
 * processor meanwhile: right for a kernel with one thing to do at a
 * tick, wrong for a system. mini-9pi's is Plan 9's: the controller's
 * driver in the kernel (Usbdwc, by interrupts), the devices as files
 * (Devusb), and the enumeration and the hubs in a user program
 * (usbd) that reads and writes those files.
 *
 * References: "Universal Serial Bus Specification", revision 2.0
 * (2000), chapter 9 for the requests and the descriptors, 11 for
 * the hub's; "Device Class Definition for Human Interface Devices
 * (HID)", version 1.11 (2001), appendix B for the boot reports, and
 * the "HID Usage Tables" for a key's number. The DWC2 controller is
 * Synopsys's DesignWare Hi-Speed USB 2.0 On-The-Go core; the Pi's
 * registers are read off other drivers (xv6 arm-pi1's CSUD, Plan
 * 9's usbdwc.c), its manual not being public. *)

(* the controller started, the devices found (none: nothing).
 * [init key pointer]: [key c] is called for a key pressed, its
 * character's code (US keys, Shift, Control: a letter's low 5 bits),
 * as the UART's are; [pointer dx dy buttons] for the mouse's report
 * (dy downwards, the buttons' bits as the HID's: 1 left, 2 right, 4
 * middle) *)
val init : (int -> unit) -> (int -> int -> int -> unit) -> unit

(* the devices' reports read, the keys and moves handled *)
val poll : unit -> unit
