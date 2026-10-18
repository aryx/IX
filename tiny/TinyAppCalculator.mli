(* A tiny calculator, a program for TinyKernel.ml built on
 * TinyLibGUI.ml: the four operations on whole numbers, with sixteen
 * buttons.
 *
 * It was written from scratch, in the subset of ML that both
 * tiny-ml and OCaml accept. Usage:
 *
 *     ./tiny-machine -window tiny-kernel
 *     $ windows                  then a window, and in it:
 *     $ calc
 *     the mouse on the buttons, or the keys: the digits, + - * /,
 *     = or the Enter, c clears; q quits
 *
 * The calculator is a value of TinyLibGUI's [gui] type: a model, its
 * view, an update function and the keys. There is no loop, no drawing
 * and no mouse handling in this file. So the arithmetic can be tested
 * on the host by sending messages to [update], and the buttons by
 * sending mouse events to TinyLibGUI (tests/TinyLibGUI_test.sh).
 *
 * The model is the state of a pocket calculator, not an expression: the
 * number shown, the number kept, and the operation waiting for its
 * second operand. Here is 12 * 3 = followed by + 6, one button per
 * column:
 *
 *     button pressed    1    2    *    3    =    +    6
 *  => number shown      1   12   12    3   36   36    6
 *   - number kept       0    0   12   12   36   36   36
 *   - pending op                  *    *         +    +
 *     what that means            12 * 12 *      36 + 36 +
 *
 * An operation is performed when the next one is requested, so
 * 2 + 3 * 4 = gives 20: there are no priorities, as on real
 * four-operation calculators.
 *
 * - {b A key is the same as its button}: [key] returns the message the
 *   button would send, so the keyboard and the mouse cannot behave
 *   differently.
 * - {b Overflow and division by zero show an error instead of
 *   trapping}: dividing by 0 or getting a number longer than nine
 *   digits shows "error" until c is pressed. A product is checked with
 *   a division before it is computed, because the machine's integers
 *   have only 31 bits; this way the answers are the same on the host,
 *   whose integers have 63 bits.
 *
 * What is dropped: fractions (tiny-ml has no floats), a sign key, a
 * memory, deleting the last digit, priorities and parentheses.
 *
 * Exercises:
 * - a key that deletes the last digit; one that changes the sign;
 * - a memory: M+, MR;
 * - drawing a button as pressed while its key is held down (this needs
 *   a message when the key goes down, and the kernel's keys have no
 *   "key up" event);
 * - priorities: make the model a stack of numbers and operations.
 *
 * cs-history:
 * This model comes from the four-operation pocket calculator
 * (Busicom's LE-120A and Bowmar's 901B, 1971): one register shown, one
 * kept, and a key that performs the pending operation. Such
 * calculators were one of the reasons microprocessors were made in the
 * first place (Intel's 4004 was designed for a Busicom calculator). A
 * calculator was among the first programs of every window system, for
 * instance a desk accessory on the first Macintosh (1984), because it
 * is the smallest program that is nothing but buttons.
 *)

(* the number shown, the number kept with the operation that awaits
 * (' ': none), whether the next digit begins a number, whether there
 * is no number to show *)
type model = { shown : int; kept : int; op : char; fresh : bool; wrong : bool }

(* what a button or a key says *)
type msg = Digit of int | Op of char | Equals | Clear

(* The calculator, for TinyLibGUI's run *)
val calculator : (model, msg) TinyLibGUI.gui
