(* The PL011 UART (the Pi's UART0, base + 0x201000): characters written
 * to DR go out at once (the transmit FIFO never fills: FR's TXFE set,
 * TXFF clear); characters received queue for DR, with the receive
 * interrupt (RXIM) and its timeout (RTIM) raised until the queue is
 * read empty; the transmit interrupt (TXIM) after each character, as
 * QEMU's model. The line is up while RIS and IMSC share a bit. Baud
 * rates and formats are kept, not used.
 *
 * The first device a kernel talks to, since two registers are
 * enough to print:
 *
 *     0x00 DR    write: a character out; read: the next one in
 *     0x18 FR    bit 4 RXFE: nothing to read; bit 5 TXFF: no room
 *                to write; bit 7 TXFE: all sent
 *     0x38 IMSC  which events interrupt (bit 4: a character
 *                received)        0x44 ICR   write to clear them
 *
 *     putc(c):  while (FR & TXFF) wait;  DR = c
 *     getc():   while (FR & RXFE) wait;  return DR
 *
 * A kernel prints so, by polling, from its first line of C, long
 * before it has interrupts or memory management; it reads by
 * interrupt later, enabling RXIM and line 57 in Intc, so as not to
 * wait in a loop for a person to type. A real UART sends a
 * character in about a tenth of a millisecond at 115200 baud and
 * the first loop matters; here a character is out when DR is
 * written, and the loop never turns.
 *
 * Where it stands: [output] is Main's, the terminal mini-qemu was
 * started in (or the page's text), and [input] gets what is typed
 * there; on the board's other side the kernel's console driver. The
 * Pi 4 has the same device at another address (Pi4), Miniuart is
 * the board's second serial line.
 *
 * terminology:
 * UART, universal asynchronous receiver-transmitter: a byte sent a
 * bit after the other on one wire, with a start and a stop bit and
 * no clock wire, each side counting time at an agreed rate, the
 * baud. It is the teletype's line, and why a kernel's console is
 * called a tty. PL011 is the number of ARM's design for one, a
 * "PrimeCell" a chip maker puts in its chip; the PC's was the 8250
 * and then the 16550, which the Pi's mini UART resembles.
 *
 * Reference: ARM PrimeCell UART (PL011) Technical Reference Manual
 * (ARM DDI 0183; from memory); QEMU's hw/char/pl011.c (from memory). *)

type t

val create : output:(char -> unit) -> line:(bool -> unit) -> t

(* a character from the host (the console's input) *)
val input : t -> char -> unit

(* nothing received waiting *)
val empty : t -> bool

val device : t -> Memory.device
