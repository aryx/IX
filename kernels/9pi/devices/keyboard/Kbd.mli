(* The keyboard's scan codes (principia's portkbd.c). This module turns
 * a PC keyboard's codes into runes for the console (Devcons.kbdputc);
 * usb/kb turns the USB keyboard's codes into these and writes them to
 * #Ι/kbin. It handles the 0xe0 and 0xe1 escapes, a key's release (bit
 * 7), shift, ctrl, alt, altgr and caps lock, with the tables kbtab,
 * kbtabshift, kbtabesc1, kbtabaltgr and kbtabctrl. Alt starts a compose
 * sequence (with Latin1's table; keys that make no character there are
 * given as they are).
 *
 *     the key          the codes       what the console gets
 *     Shift down       2a              nothing: shift is remembered
 *     A down           1e              the rune A (kbtabshift.(0x1e))
 *     A up             9e              nothing (1e with bit 7)
 *     Shift up         aa              nothing: shift is forgotten
 *     a down, up       1e 9e           the rune a (kbtab.(0x1e))
 *     left down        e0 4b           the rune 0xF011, a private one
 *
 * A code is a key's position, not its character. What the key means is
 * given by the tables, and another country's keyboard is another table
 * (9pi's kbmap device, which is not here: see Devstub). Keys with no
 * character (the arrows, the function keys) are runes of Unicode's
 * private area, for the programs that know them.
 *
 * Where it stands: [kbdputsc] is called with each code by Devkbin (when
 * a program, usbd, wrote it) or by Kusb (when the kernel read the USB
 * keyboard itself). Both first turned USB's numbers into these codes,
 * with lib_usb's Hid. The runes go on to Devcons.kbdputc.
 *
 * cs-history:
 * These are the IBM PC's codes of 1981: a byte for each key, given by
 * its place on that keyboard, and the same byte with its top bit set
 * when the key comes up. The keys added later (a second Ctrl and Alt,
 * the arrows apart from the keypad) had no numbers left that old
 * programs would not misread, so they were given an old key's number
 * after a prefix, e0. USB keyboards say something else entirely (a
 * table of the keys held: see Hid). The PC's codes are kept as the
 * common language, so that portkbd.c's tables, made for the PC's
 * keyboard, serve as they are. *)

(* The keys held: #c/kbd (docs/plans/done/plan_playground.md, stage 4).
 *
 * Why another file than /dev/cons? The console is a stream of
 * characters: what was typed. A key pressed is its character there, and
 * a key released is nothing. That is all an editor or a shell asks, and
 * all that Plan 9's console ever said. A game asks another question: is
 * left down now? It turns while left is down, and stops when it comes
 * up.
 *
 *     a key           /dev/cons (rawon)          #c/kbd
 *     -----------     ---------------------      ----------------------
 *     left down       the rune 0xF011            k and the keys down: left
 *     held            the same rune again, if    nothing (it is down
 *                     the keyboard repeats       already)
 *     up down too     the rune 0xF00E            k left up
 *     left up         nothing                    K up
 *     up up           nothing                    K
 *
 * What /dev/consctl's rawon changes, and what it does not. Without it,
 * the kernel keeps a line until Enter, echoes it, and does Backspace and
 * Ctl-U itself. With it, each read is what was typed since the last
 * read, with no echo and no editing. That changes when the characters
 * come, not what they say: raw or not, a release is not in the stream.
 * A program reading the raw console:
 * - can know that left was pressed (Tetris needs no more);
 * - can guess that it is still held from the repeats (which come from
 *   the USB driver, not the keyboard: lib_usb's Hid gives a key again
 *   every 32 ms once it has been held for 160 ms, and only the last key
 *   pressed, until any key comes up);
 * - cannot know that two keys are held together, nor that Shift alone
 *   is down (it has no character).
 * The playground's platform did without this file at first: a key
 * counted as down from its character to the next frame.
 *
 * What the file is. It is 9front's /dev/kbd, with two of its messages'
 * three letters. A read waits for a change, and returns one message:
 *     k  then the keys down now, when one went down
 *     K  then the keys still down, when one came up
 * Each key is given as its character in UTF-8, in the order the keys
 * went down, and the message ends with a zero byte. A key is what it is
 * alone, without Shift or Ctl (the a key is "a" whatever is held with
 * it, so that the key released is the key that was pressed), and Shift,
 * Ctl and Alt are keys too (0xF860, 0xF862, 0xF863). There is no c
 * message (in 9front, a character typed, with its repeats): the console
 * says that already, and still does while this file is read.
 *
 * Where it is made. In 9front the kernel only queues scan codes
 * (/dev/scancode), and a program, kbdfs, translates them and serves
 * cons, consctl and kbd. Here the kernel already does the translation
 * (in this module), and it sees every release anyway, for Shift's
 * state. So the file is the kernel's too, which was the smaller change
 * (the author, 2026-10-07: "I prefer small version (file in kernel)").
 * mini-rio reads it and gives each window a kbd of its own, sending the
 * messages to the window that has the keyboard.
 *
 * Its limits. The serial line has no releases: a session typed there is
 * characters only, and this file says nothing of it. A window that
 * loses the keyboard is told that no key is down (mini-rio's K),
 * whatever is down. The last 64 messages wait for a reader, and they
 * are dropped when the file is opened, because what was typed before
 * does not belong to the program. And a listing of #c does not show the
 * file (it is opened by its name), so the sessions recorded from the C
 * 9pi, which list that directory, still match the twin. *)

(* takes a scan code from outside the kernel (kbin: the external state) *)
val kbdputsc : int -> unit

(* the mouse buttons that the keyboard sets (Kmouse keys, none in the
 * default tables) are told to the mouse (Devmouse) *)
val kbdmouse : (int -> unit) ref
