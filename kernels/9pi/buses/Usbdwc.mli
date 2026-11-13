(* The driver of the USB host controller (principia's usbdwc.c): the
 * Synopsys DWC2 of the BCM2835. It makes an endpoint's transfers and
 * drives the root port. A transfer is done by kernels/lib_machine's
 * usb.c, on one host channel, with the data going through its DMA
 * page, and it is polled until it ends (9pi's waits for the FIQ's
 * wakeup). A NAK is tried again after a sleep (an interrupt endpoint's
 * polling interval), and a STALL becomes the endpoint's "endpoint
 * stalled" error. The data toggles are kept in the endpoint (usb.c's
 * usb_pid). Split transactions are skipped, as 9pi's are under
 * emulation (QEMU's dwc2 routes a packet by its address alone).
 *
 *     a transfer: the host always speaks first
 *     host:    a token: IN, to address 3, endpoint 1
 *     device:  DATA1 and 8 bytes        or   NAK: nothing to say now
 *     host:    ACK                           (asked again later)
 *
 * The two data names, DATA0 and DATA1, alternate at each packet that
 * got through (this is the toggle), so a packet seen twice with the
 * same name is a repeat whose ACK was lost.
 *
 * terminology:
 * USB's four kinds of transfer are named for what they are used for,
 * not for how they work:
 * - Control: a request of 8 bytes, data one way, and a status the
 *   other way (Usbdesc). Every device has it, on endpoint 0.
 * - Bulk: as many bytes as wanted, when the bus is free (a disk;
 *   Etherusb).
 * - Interrupt: there is no interrupt at all, but a small packet asked
 *   for at a regular interval (a keyboard; Hid).
 * - Isochronous: a share of every millisecond, with no retry (sound).
 * An endpoint is one direction of one such conversation with a device.
 * Its address on the bus is the device's number and its own. *)

open Usb

(* starts the controller (init: the DMA, and the root port powered) *)
val init : unit -> unit

(* the root port's operations (the hub's replies to usbd, devusb's root
 * hub): enable, reset, and status (HP bits) *)
val portenable : int -> bool -> int
val portreset : int -> bool -> int
val portstatus : int -> int

(* open and close an endpoint; read from it (n bytes at most), and
 * write to it (returning how many bytes were taken) *)
val epopen : ep -> unit
val epclose : ep -> unit
val epread : ep -> int -> string
val epwrite : ep -> string -> int

(* [inpoll ep n] keeps an IN transfer of up to n bytes pending on the
 * controller's second channel. It returns a finished transfer's bytes,
 * or None; when no transfer is pending, it starts the next one and
 * returns None. It is called from the clock (Etherusb's poll). *)
val inpoll : ep -> int -> string option

(* [intry ep n] tries an IN transfer once, without waiting on it. It
 * returns its bytes, or None for a NAK (a keyboard with nothing to
 * say). It is for the clock (Kusb). *)
val intry : ep -> int -> string option

(* when true, each transfer is printed on the console (for debugging) *)
val debug : bool ref

(* the controller's type ("dwcotg"), which reset prints *)
val hcitype : string
