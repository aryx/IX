(* A tiny calculator, a program of TinyKernel.ml's on TinyGUI.ml: four
 * operations on whole numbers, sixteen buttons. Written anew, in
 * tiny-ml's ML and OCaml's:
 *
 *     ./tiny-machine -window tiny-kernel
 *     $ windows                  then a window, and in it:
 *     $ calc
 *     the mouse on the buttons, or the keys: the digits, + - * /,
 *     = or the Enter, c clears; q quits
 *
 * It is a value of TinyGUI's [gui]: a model, its view, an update and
 * the keys, with no loop, no drawing and no mouse here. So its
 * arithmetic is tested on the host by messages given to [update], and
 * its buttons by a mouse given to TinyGUI (tests/TinyGUI_test.sh).
 *
 * The model is the calculator one holds, not an expression: the number
 * shown, the number kept, the operation that awaits its second number.
 * 12 * 3 = then + 6, a button a column:
 *
 *     the button    1    2    *    3    =    +    6
 *     shown         1   12   12    3   36   36    6
 *     kept          0    0   12   12   36   36   36
 *     awaits                  *    *         +    +
 *     over it                12 * 12 *      36 + 36 +
 *
 * An operation is done when the next one is asked, so 2 + 3 * 4 = is
 * 20: no priorities, as the calculators of four operations.
 *
 * - {b A key is its button}: [key] gives the message the button would
 *   send, so the keys and the mouse cannot differ.
 * - {b No number, no trap}: a division by 0 or a number past nine
 *   digits shows "error" until c. A product is checked by a division
 *   before it is made, the machine's integers having 31 bits: the same
 *   answers on the host, whose integers have 63.
 *
 * Dropped: fractions (tiny-ml has no floats), a sign's key, a
 * memory, the last digit taken back, priorities and parentheses.
 *
 * Exercises:
 * - a key that takes the last digit back; one that changes the sign;
 * - a memory: M+, MR;
 * - a button drawn held while its key is down (a message when the key
 *   goes down, and the kernel's keys have no "up");
 * - priorities: the model a stack of numbers and operations.
 *
 * cs-history:
 * The pocket calculator of four operations (Busicom's LE-120A and
 * Bowmar's 901B, 1971) is where this model comes from: one register
 * shown, one kept, and a key that does the awaited operation; its chip
 * was one of the first microprocessors' reasons (Intel's 4004 was
 * made for a Busicom calculator). A calculator was among the first
 * programs of every window system, a desk accessory of the first
 * Macintosh (1984), because it is the smallest program that is all
 * buttons. *)

(* the number shown, the number kept with the operation that awaits
 * (' ': none), whether the next digit begins a number, whether there
 * is no number to show *)
type model = { shown : int; kept : int; op : char; fresh : bool; wrong : bool }

(* what a button or a key says *)
type msg = Digit of int | Op of char | Equals | Clear

(* The calculator, for TinyGUI's run *)
val calculator : (model, msg) TinyGUI.gui
