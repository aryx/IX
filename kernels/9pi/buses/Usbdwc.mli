(* The USB host controller's driver (principia's usbdwc.c): the
 * Synopsys DWC2 of the BCM2835, an endpoint's transfers and the root
 * port. A transfer is kernels/lib_machine's usb.c's: one host channel, the data
 * through its DMA page, polled to its end (9pi's waits for the FIQ's
 * wakeup); a NAK tried again after a sleep (an interrupt endpoint's
 * polling interval), a STALL the endpoint's "endpoint stalled"; the data
 * toggles kept in the endpoint (usb.c's usb_pid). Split transactions are
 * skipped, as 9pi's are under emulation (QEMU's dwc2 routes a packet by
 * its address alone).
 *
 *     a transfer: the host speaks first, always
 *     host:    a token: IN, to address 3, endpoint 1
 *     device:  DATA1 and 8 bytes        or   NAK: nothing to say now
 *     host:    ACK                           (asked again later)
 *
 * The two data names, DATA0 and DATA1, alternate at each packet
 * that got through (the toggle): a packet seen twice with the same
 * name is a repeat whose ACK was lost.
 *
 * terminology:
 * USB's four kinds of transfer are named for what they are used
 * for, not how they work. Control: a request of 8 bytes, data one
 * way, a status the other (Usbdesc); every device has it, on
 * endpoint 0. Bulk: as many bytes as wanted, when the bus is free
 * (a disk; Etherusb). Interrupt: no interrupt at all, a small
 * packet asked for at a regular interval (a keyboard: Hid).
 * Isochronous: a share of every millisecond, with no retry (sound).
 * And an endpoint is one direction of one such conversation with a
 * device: its address on the bus is the device's number and its
 * own. *)

open Usb

(* the controller started (init: DMA, the root port powered) *)
val init : unit -> unit

(* the root port's (hub replies to usbd, devusb's root hub): enable,
 * reset, status (HP bits) *)
val portenable : int -> bool -> int
val portreset : int -> bool -> int
val portstatus : int -> int

(* an endpoint opened, closed; read (n bytes at most), written (the
 * bytes taken) *)
val epopen : ep -> unit
val epclose : ep -> unit
val epread : ep -> int -> string
val epwrite : ep -> string -> int

(* claude: [inpoll ep n]: an IN transfer of up to n bytes kept pending
 * on the controller's second channel: a finished one's bytes, or None
 * (the next one started); from the clock (Etherusb's poll) *)
val inpoll : ep -> int -> string option

(* claude: [intry ep n]: an IN transfer tried once, not waited on: its
 * bytes, or None for a NAK (a keyboard with nothing to say); for the
 * clock (Kusb) *)
val intry : ep -> int -> string option

(* each transfer printed on the console (debugging) *)
val debug : bool ref

(* the controller's type ("dwcotg"), what reset prints *)
val hcitype : string
