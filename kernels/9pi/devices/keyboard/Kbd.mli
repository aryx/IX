(* The keyboard's scan codes (principia's portkbd.c): a PC keyboard's
 * codes (usb/kb turns the USB keyboard's into these, writing #Ι/kbin)
 * turned into runes for the console (Devcons.kbdputc): the 0xe0 and 0xe1
 * escapes, a key's release (bit 7), shift, ctrl, alt, altgr, caps lock,
 * the tables kbtab, kbtabshift, kbtabesc1, kbtabaltgr, kbtabctrl.
 * Alt starts a compose sequence (Latin1's table; keys that make no
 * character there are given as they are).
 *
 *     the key          the codes       what the console gets
 *     Shift down       2a              nothing: shift is remembered
 *     A down           1e              the rune A (kbtabshift.(0x1e))
 *     A up             9e              nothing (1e with bit 7)
 *     Shift up         aa              nothing: shift is forgotten
 *     a down, up       1e 9e           the rune a (kbtab.(0x1e))
 *     left down        e0 4b           the rune 0xF011, a private one
 *
 * A code is a key's position, not its character: what the key
 * means is the tables', and another country's keyboard is another
 * table (9pi's kbmap device, not here: Devstub). Keys with no
 * character (the arrows, the function keys) are runes of Unicode's
 * private area, for the programs that know them.
 *
 * Where it stands: [kbdputsc] is called with each code by Devkbin
 * (a program wrote it: usbd) or by Kusb (the kernel read the USB
 * keyboard itself); both first turned USB's numbers into these, by
 * lib_usb's Hid. Runes go on to Devcons.kbdputc.
 *
 * cs-history:
 * These are the IBM PC's codes of 1981: a byte a key by its place
 * on that keyboard, the same byte with its top bit set when the key
 * comes up. The keys added later (a second Ctrl and Alt, the
 * arrows apart from the keypad) had no numbers left that old
 * programs would not misread, and were given an old key's number
 * after a prefix, e0. USB keyboards say something else entirely
 * (a table of the keys held: Hid); the PC's codes are kept as the
 * common language, so that portkbd.c's tables, made for the PC's
 * keyboard, serve as they are. *)

(* The keys held: #c/kbd (docs/plans/plan_playground.md, stage 4).
 *
 * Why another file than /dev/cons. The console is a stream of
 * characters: what was typed. A key pressed is its character there; a
 * key released is nothing. That is all an editor or a shell asks, and
 * all Plan 9's console ever said. A game asks another question: is left
 * down now? It turns while it is, and stops when it comes up.
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
 * What /dev/consctl's rawon changes, and what it does not. Without it
 * the kernel keeps a line until Enter, echoes it, and does Backspace
 * and Ctl-U itself; with it each read is what was typed since the last,
 * no echo, no editing. That is when the characters come, not what they
 * say: raw or not, a release is not in the stream. A program reading
 * the raw console can know that left was pressed (Tetris needs no
 * more), can guess it is still held from the repeats (which are the
 * USB driver's, not the keyboard's: lib_usb's Hid gives a key again
 * every 32 ms once it has been held 160, and only the last key
 * pressed, until any key comes up), and cannot know two keys are held
 * together, nor that Shift alone is down (it has no character). The
 * playground's platform did without at first: a key was down from its
 * character to the next frame.
 *
 * What the file is. 9front's /dev/kbd, its messages' two letters of
 * three: a read waits for a change and is one message,
 *     k  then the keys down now, when one went down
 *     K  then the keys still down, when one came up
 * each key its character in UTF-8, in the order they went down, then a
 * zero byte. A key is what it is alone, without Shift or Ctl (the a
 * key is "a" whatever is held with it: the key released is the key
 * that was pressed), and Shift, Ctl and Alt are keys too (0xF860,
 * 0xF862, 0xF863). No c message (9front's: a character typed, with
 * its repeats): the console says that already, and still does while
 * this file is read.
 *
 * Where it is made. In 9front the kernel only queues scan codes
 * (/dev/scancode) and a program, kbdfs, translates them and serves
 * cons, consctl and kbd. Here the translation is the kernel's already
 * (this module), which sees every release and used to keep it for
 * Shift's state only; so the file is the kernel's too, the smaller
 * change (the author, 2026-10-07: "I prefer small version (file in
 * kernel)"). mini-rio reads it and gives each window a kbd of its own,
 * the messages to the window that has the keyboard.
 *
 * Its limits. The serial line has no releases: a session typed there
 * is characters only, and this file says nothing of it. A window that
 * loses the keyboard is told no key is down (mini-rio's K), whatever
 * is. The messages wait for a reader, the last 64, and are dropped when
 * the file is opened: what was typed before is not a program's. And a
 * listing of #c does not show it (it is opened by its name): the
 * sessions recorded from the C 9pi list that directory, and stay the
 * twin's. *)

(* a scan code, from outside the kernel (kbin: the external state) *)
val kbdputsc : int -> unit

(* the mouse buttons the keyboard sets (Kmouse keys: none in the
 * default tables), told to the mouse (Devmouse) *)
val kbdmouse : (int -> unit) ref
