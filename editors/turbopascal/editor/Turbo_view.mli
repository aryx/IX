(* Turbo_view: the IDE's screen, 80 by 25 characters, Turbo Pascal 7's
   look (1992) drawn with Curses on the IBM PC's text screen:

       File  Search  Run  Compile  Debug  Help          <- grey bar, red
     ╔════════════════ QUEENS.PAS ═════════════════╗       hot letters
     ║ program Queens;                             ║    <- blue window,
     ║ var ...                                     ║       yellow text,
     ║                                             ║       white reserved
     ╚══ 3:1 ══════════════════════════════════════╝       words
     ┌───────────────── Watches ───────────────────┐
     │ i: 3                                        │    <- when there are
     └─────────────────────────────────────────────┘       watches
      F1 Help  F2 Save  F3 Open  F9 Make  F10 Menu      <- grey status

   The colours are the CGA's sixteen, the frames code page 437's box
   characters (double lines for the edit window), the dialogs and the
   open menu drawn with a shadow. The text is coloured a line at a
   time: reserved words, comments (which may run over lines), strings
   and numbers. A paused program's line is the execution bar; a
   breakpoint's line is red. The status line's keys are the debugger's
   while a program is started.

   Over the editor, by the model's mode: a menu dropped from the bar, a
   dialog, a box, the call stack, the P-code listing (the cursor's
   line's instructions highlighted); or instead of it all, the user
   screen, the program's own.

   The whole screen is made from the model at each event, back to
   front: the edit window, the watches, the status line, the bar, then
   what is over them; nothing remembers what was drawn before. What
   keeps it cheap is after it: Curses' difference with the screen
   shown (and [cache], below). mini-emacs's Frame is the same way.

   cs-history:
   Why DOS programs looked like this. The PC's text screen was 80 by
   25 cells of memory the program wrote into directly, two bytes a
   cell: the character, and an attribute byte, four bits for one of
   sixteen colours of the letter and the rest for the ground's. No
   terminal, no escape sequences, no line to wait for: a screen was
   changed whole in an instant, so windows, menus and shadows in
   characters cost nothing. And the PC's character set (code page
   437) had, above ASCII, the corners and lines to draw frames with,
   single and double. Here those cells are Curses', sent to a terminal
   that draws them or painted by a window (Cells). *)

open Turbo_model

val view : model -> Curses.t

(* ix: false: a view keeps nothing of the one before (the playground's
   way; true: the rows that are the same are not made again) *)
val cache : bool ref
