(* The kernels' USB keyboard and mouse, found as xv6 arm-pi1's CSUD
 * finds its keyboard, but more simply. It drives the DWC2 controller
 * (through usb.c's two primitives, on both boards), the hub on its root
 * port (QEMU puts one there), and, behind the hub, the HID devices in
 * their boot protocol: a keyboard and a mouse. Everything is polled:
 * it waits for each transfer to end, and it reads the devices'
 * interrupt endpoints at each tick (a NAK means nothing new).
 *
 * It was written for mini-xv6 and was once mini-xv6's own. It is here
 * because other kernels use it too (mini-oberon), each one saying at
 * [init] what a key and a move mean to it. mini-9pi has its own, since
 * its usbd is a program. It is not one of the modules every kernel
 * links (mkkernel's LIB_ML), so a kernel that wants it names it.
 *
 * USB is a tree with the computer at its root, and only the root
 * speaks: a device answers when it is asked, never by itself.
 *
 *     the controller (DWC2), the host
 *        '-- its one port: a hub, address 1
 *              |-- port 1: a keyboard, address 2
 *              '-- port 2: a mouse, address 3
 *
 * A device just plugged in answers at address 0. Finding it (its
 * enumeration) is a conversation on its endpoint 0, where each step is
 * a control transfer of 8 bytes that say what is asked:
 * - the first 8 bytes of its device descriptor, which give the size
 *   of its packets;
 * - an address is set;
 * - its configuration descriptor, which is searched for an interface
 *   of class 3 (HID, human interface device), subclass 1 (boot), and
 *   protocol 1 (a keyboard) or 2 (a mouse), and for that interface's
 *   interrupt endpoint;
 * - then the configuration is set and the boot protocol asked for.
 * The hub is found the same way, and its ports are then powered and
 * reset one by one through it.
 *
 * After that, each poll of the interrupt endpoint gives a report (the
 * name is USB's, but there is no interrupt: the host asks at an
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
 * reports in a small language (the report descriptor, which says which
 * bits are what), and a full driver interprets it. A keyboard or a
 * mouse may also be told to send the fixed reports above, so that a
 * BIOS could read keys without that interpreter. A kernel that wants
 * only keys and moves is in the BIOS's place.
 *
 * others:
 * A driver that polls and waits for each transfer to end holds the
 * processor meanwhile. That is right for a kernel with one thing to do
 * at a tick, and wrong for a system. mini-9pi's driver is Plan 9's:
 * the controller's driver is in the kernel (Usbdwc, by interrupts),
 * the devices are files (Devusb), and the enumeration and the hubs are
 * handled by a user program (usbd) that reads and writes those files.
 *
 * References: "Universal Serial Bus Specification", revision 2.0
 * (2000), chapter 9 for the requests and the descriptors, and chapter
 * 11 for the hub's; "Device Class Definition for Human Interface
 * Devices (HID)", version 1.11 (2001), appendix B for the boot
 * reports, and the "HID Usage Tables" for a key's number. The DWC2
 * controller is Synopsys's DesignWare Hi-Speed USB 2.0 On-The-Go core.
 * Its manual is not public, so the Pi's registers are read off other
 * drivers (xv6 arm-pi1's CSUD, Plan 9's usbdwc.c). *)

(* starts the controller and finds the devices (when there are none, it
 * does nothing). In [init key pointer], [key c] is called for each key
 * pressed, with its character's code, as the UART gives them (US keys,
 * with Shift, and Control giving a letter's low 5 bits). [pointer dx
 * dy buttons] is called for each mouse report (dy goes downwards, and
 * the buttons' bits are the HID's: 1 left, 2 right, 4 middle). *)
val init : (int -> unit) -> (int -> int -> int -> unit) -> unit

(* reads the devices' reports and handles the keys and moves *)
val poll : unit -> unit
