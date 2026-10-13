(* The BCM2835's system timer (base + 0x3000): a free-running 64-bit
 * counter of microseconds (CLO, CHI) and four compares (C0-C3); when
 * the counter's low word reaches a compare, its bit in CS is set and
 * its interrupt line (0-3) raised, until the kernel writes the bit to
 * CS. Time advances when the board says (instructions counted,
 * plan_pi.md decision 6), so a compare the counter jumps over still
 * matches.
 *
 *     0x00 CS    which compares matched; write a 1 to clear one
 *     0x04 CLO   the counter, low 32 bits       0x08 CHI   high
 *     0x0c C0  0x10 C1  0x14 C2  0x18 C3        the compares
 *
 * How a kernel gets its clock from it, a tick every 10 ms:
 *
 *     at boot:        C3 = CLO + 10000; enable line 3 in Intc
 *     10 ms later:    CLO reaches C3: CS bit 3, line 3, the IRQ
 *     the handler:    CS = 8 (the line falls); C3 = C3 + 10000;
 *                     count a tick, perhaps switch process
 *
 * That interrupt is the only reason a kernel ever runs without
 * having been called: without it, a program that loops keeps the
 * processor for ever. Preemption is this device and a few lines of
 * the kernel.
 *
 * Where it stands: Board calls [advance] with the instructions run
 * made microseconds, and [until_next] when the kernel waits (wfi)
 * to skip the idle time to the next alarm in one step. The Pi 4's
 * kernels use the processor's own timer instead (Pi4).
 *
 * others:
 * A counter that never stops and compares set each time is a
 * one-shot timer: the kernel chooses each delay, and may set a far
 * one when it has nothing to do. The PC's first timer (the 8253)
 * was periodic, an interrupt at a fixed rate whether wanted or not;
 * kernels that stop the tick when idle (Linux's tickless) came back
 * to the one-shot.
 *
 * Reference: BCM2835 ARM Peripherals, chapter 12. *)

type t

val create : line:(int -> bool -> unit) -> t

(* the counter moved on by microseconds *)
val advance : t -> int -> unit

(* the microseconds until the next compare (for an idle CPU) *)
val until_next : t -> int

val device : t -> Memory.device

(* the counter, microseconds *)
val now : t -> int
