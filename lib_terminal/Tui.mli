(* Tui: a full-screen program of the terminal, Model-View-Update.

   Rogue, vi, top and Norton Commander don't ask a question and wait
   for a line, as the Teletype programs do (Talk.mli): they wait for
   a key, or for time to pass, then draw the whole screen again. That
   is an event loop, which is Model-View-Update as it stands: a model,
   an update from an event, a view -- the view a Curses screen rather
   than shapes, and curses sending the difference (Curses.mli).

       event (a key, time) --update--> model --view--> Curses.t
                                                          |
                                     refresh: the bytes that changed
                                                          v
                            the playground's Vt (Textmode.mli), or a real
                            terminal (Tty_unix.mli), the same program

   The same program runs on the playground, drawn by its Vt, and in the
   terminal it was written for, xterm or the macOS Terminal: a [program]
   knows nothing of either. Bubble Tea (Charm, Go, 2020) is exactly
   this, the Elm architecture for terminals, and says so; Brick
   (Haskell, 2015) before it.

   Keys come as the bytes the terminal sends ("a", "\r", "\x1b[A" for
   the up arrow: Vt.key), a key per event; time as the seconds since the
   last tick, some twenty times a second, at most a quarter of a second
   (a longer wait is a pause, not time played).

   ix: and the screen's size, its rows and columns, when the host's
   changes (a window made larger: more rows, not larger letters); a
   program that has one size takes no notice.

   In ix the programs are mini-turbopascal (Tui_turbo) and mini-emacs,
   and a host is one of three, the program the same under each:

       Tty_unix       a terminal on Linux: Curses.refresh's bytes out,
                      the keys' bytes in, the kernel's tty made raw
       Window_sdl     a window on Linux: the cells painted in a
                      Picture with Plan 9's font (Cells)
       Window_draw    a window of mini-rio's, or all of mini-9pi's
                      screen: the cells painted by the draw device

   A host is a loop: wait for a key or a twentieth of a second, call
   update, call view, show what changed. Everything a program is can
   be tested without one, by calling update with keys and reading the
   Curses.t that view returns (its text).

   cs-history:
   Model, update and view under those names are Elm's (Evan
   Czaplicki, 2012), a language for web pages in which a program is
   those three and nothing else may change anything. The shape is
   older: it is a state machine with a picture of each state, and
   what an event loop becomes when the state is one value passed
   along and not variables changed all over. ix has it elsewhere:
   the Playground's programs, and Office (Office_model,
   Office_update, Office_view); mini-turbopascal's modules are named
   by it (Turbo_model, Turbo_update, Turbo_view). *)

type event = Key of string | Tick of float | Resize of int * int

type 'model program = {
  init : 'model;
  update : event -> 'model -> 'model;
  view : 'model -> Curses.t;
  (* whether the program is over: a real terminal gets its shell back *)
  over : 'model -> bool;
}
