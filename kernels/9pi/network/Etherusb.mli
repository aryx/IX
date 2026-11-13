(* The driver, in the kernel, of a USB Ethernet adapter (the plan's
 * decision 5b; the idea is 9pi's etherusb.c). It finds the adapter
 * among the devices usbd enumerated (usbd has no driver for it and
 * leaves it alone). It knows two adapters, told apart by who made the
 * device:
 *
 * - QEMU's usb-net, a CDC Ethernet (ECM) device, which is the class USB
 *   has for an adapter. The driver sets its configuration 1 (ECM,
 *   because QEMU lists RNDIS first), and reads its MAC address from its
 *   string descriptor. A transfer is a frame: it goes out on its bulk
 *   endpoint in 64-byte packets (with a zero-length packet after a
 *   multiple of 64), and it comes in the same way.
 * - the Pi 1's and the Pi 2's own adapter, SMSC's LAN9512 and LAN9514
 *   (a hub and an adapter in one chip: the board's USB ports are that
 *   hub's). It is of no class: its registers are read and written by
 *   two requests of the vendor's, and the driver sets it up as
 *   principia's smsc.c does (reset, the address, the transceiver's
 *   negotiation with the other end of the cable, and turning frames
 *   on). Its address is not in the chip: it is the firmware's, asked
 *   for by Machine.board_mac. A transfer in holds several frames, each
 *   behind a word that gives its length; a transfer out is one frame
 *   behind two words.
 *   **This was written from that driver and Linux's, and it has not run
 *   on a board yet**: no emulator here has the chip.
 *
 * Frames come in on bulk IN, by a transfer kept pending on the
 * controller's second channel and polled from the clock
 * (Usbdwc.inpoll). The frames of each finished transfer are taken, and
 * another transfer is started and asked for at once, so that a tick
 * takes all the frames that wait.
 *
 * References: principia's kernel/buses/user/usb/ether/smsc.c; Linux's
 * drivers/net/usb/smsc95xx.c; SMSC, "LAN9512: USB 2.0 Hub and 10/100
 * Ethernet Controller" (the data sheet, for the registers and the
 * words before a frame). *)

(* finds the adapter and sets it up, and returns its MAC address (6
 * bytes), or None when there is no adapter *)
val probe : unit -> string option

(* sends a frame (padded to 60 bytes) *)
val send : string -> unit

(* the frames that came in since the last poll (the clock calls it) *)
val poll : unit -> string list
