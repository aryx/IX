(* A USB Ethernet adapter's driver in the kernel (the plan's decision 5b;
 * 9pi's etherusb.c's idea), found among the devices usbd enumerated
 * (usbd has no driver for it and leaves it be). Two adapters, told
 * apart by who made the device:
 *
 * - QEMU's usb-net, a CDC Ethernet (ECM) device, the class USB has
 *   for an adapter: its configuration 1 set (ECM: QEMU lists RNDIS
 *   first), its MAC address from its string descriptor. A transfer is
 *   a frame: out on its bulk endpoint in 64-byte packets (a
 *   zero-length one after a multiple of 64), in the same way.
 * - a Pi 1's and a Pi 2's own, SMSC's LAN9512 and LAN9514 (a hub and
 *   an adapter in one chip: the board's USB ports are that hub's).
 *   It is of no class: its registers are read and written by two
 *   requests of the vendor's, and the driver sets it up as
 *   principia's smsc.c does (reset, the address, the transceiver's
 *   negotiation with the other end of the cable, frames on). Its
 *   address is not in the chip: the firmware's, asked by
 *   Machine.board_mac. A transfer in is several frames, each behind
 *   a word of its length; one out is a frame behind two.
 *   **Written from that driver and Linux's, and not run on a board
 *   yet**: no emulator here has the chip.
 *
 * Frames come in on bulk IN by a transfer kept pending on the
 * controller's second channel, polled from the clock (Usbdwc.inpoll):
 * each finished one its frames, and another started and asked at
 * once, so that a tick takes all that wait.
 *
 * References: principia's kernel/buses/user/usb/ether/smsc.c; Linux's
 * drivers/net/usb/smsc95xx.c; SMSC, "LAN9512: USB 2.0 Hub and 10/100
 * Ethernet Controller" (the data sheet: the registers, the words
 * before a frame). *)

(* the adapter found and set up, or not: its MAC address (6 bytes) *)
val probe : unit -> string option

(* a frame sent (padded to 60 bytes) *)
val send : string -> unit

(* the frames that came in since the last poll (the clock's) *)
val poll : unit -> string list
