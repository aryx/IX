(* This is the DWC2 USB host controller (base + 0x980000), as QEMU's
 * raspi models it (hw/usb/hcd-dwc2.c). It has QEMU's id (2.94a, which
 * the kernels test to know they are "emulating") and QEMU's reset
 * values, and its resets finish at once. The root port is driven by
 * HPRT: the end of a reset enables the port and resets its device.
 * Then there are the host channels. A transfer runs whole, by DMA, as
 * soon as its channel is enabled. Afterwards HCTSIZ holds what is
 * left, and HCINT says the transfer is complete and the channel
 * halted. As in QEMU, there is no ACK, and a zero-length transfer
 * leaves the packet count unchanged (CSUD knows both quirks). Control,
 * bulk and interrupt transfers run the same way. A NAK halts an
 * interrupt channel; a control or bulk channel stays enabled and tries
 * again when its HCINT is read. *)

type t

(* [create] makes the controller, with a device on its root port (QEMU's
 * hub, with a keyboard on it) or none *)
(* [now] gives the board's time, in microseconds *)
val create : mem:Memory.t -> root:Usb.device option -> line:(bool -> unit) -> now:(unit -> int) -> t

val device : t -> Memory.device
