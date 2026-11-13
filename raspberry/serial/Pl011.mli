(* This is the PL011 UART (the Pi's UART0, base + 0x201000). Characters
 * written to DR go out at once, so the transmit FIFO never fills (FR's
 * TXFE is set and TXFF is clear). Characters received wait in a queue
 * for DR, and the receive interrupt (RXIM) and its timeout (RTIM) are
 * raised until the queue is read empty. As in QEMU's model, the
 * transmit interrupt (TXIM) is raised after each character. The line
 * is up while RIS and IMSC have a bit set in common. Baud rates and
 * formats are kept, but not used.
 *
 * It is the first device a kernel talks to, since two registers are
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
 * A kernel prints this way, by polling, from its first line of C, long
 * before it has interrupts or memory management. Later it reads by
 * interrupt, enabling RXIM and line 57 in Intc, so as not to wait in
 * a loop for a person to type. A real UART sends a character in about
 * a tenth of a millisecond at 115200 baud, so the first loop matters.
 * Here a character is out as soon as DR is written, and the loop
 * never turns.
 *
 * Where it stands: [output] comes from Main, and writes to the
 * terminal mini-qemu was started in (or to the page's text), and
 * [input] gets what is typed there. On the board's other side is the
 * kernel's console driver. The Pi 4 has the same device at another
 * address (Pi4). Miniuart is the board's second serial line.
 *
 * terminology:
 * A UART is a universal asynchronous receiver-transmitter. It sends a
 * byte one bit after the other on one wire, with a start and a stop
 * bit. There is no clock wire: each side counts time at an agreed
 * rate, the baud. It is the teletype's line, and it is why a kernel's
 * console is called a tty. PL011 is the number of ARM's design for a
 * UART, a "PrimeCell" that a chip maker puts in its chip. The PC's
 * UART was the 8250 and then the 16550, which the Pi's mini UART
 * resembles.
 *
 * Reference: ARM PrimeCell UART (PL011) Technical Reference Manual
 * (ARM DDI 0183); QEMU's hw/char/pl011.c. *)

type t

val create : output:(char -> unit) -> line:(bool -> unit) -> t

(* a character from the host (the console's input) *)
val input : t -> char -> unit

(* whether no received character is waiting *)
val empty : t -> bool

val device : t -> Memory.device
