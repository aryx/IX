(* TinyTurboPascal: Turbo Pascal's integrated development environment,
   in text mode.

   Anders Hejlsberg's Turbo Pascal (Borland, 1983, $49.95) put the
   editor, the compiler and the program in under 40 KB: type, press
   a key, and the program runs a second later -- or the cursor lands on
   the error, the message above it. Where programmers had edited,
   left the editor, compiled, linked and run, each a program of its own
   loaded from floppies, it was one keystroke, and it is where the
   "integrated development environment" began.

   This is its later look, Turbo Pascal 7's (1992), drawn in characters
   on the IBM PC's text screen: a grey menu bar with red hot letters, a
   blue window framed by the PC's double-line box characters (╔═╗),
   the text yellow and the reserved words white, a grey status line of
   function keys, and dialogs with a shadow. The colours are the CGA's
   sixteen, the same on every PC (Teletype.draw_screen's [pc]).

       F9 (Make), Alt-F9 (Compile)   the text compiled by
                                     Pascal_compile: a box with the
                                     lines and the code's size, or the
                                     first error in a red bar at the
                                     top of the window, the cursor on it
       Ctrl-F9 (Run)                 compiled, then run on the user
                                     screen, black, by Pmachine: its
                                     writeln and readln there; a key
                                     afterwards comes back, to the
                                     line of a run-time error if there
                                     was one; Alt-F5 shows it again
       Compile / P-code              ours, not Borland's: the program's
                                     P-code (Pcode.mli), the
                                     instructions of the cursor's line
                                     highlighted

   And its debugger, Turbo Pascal 5's (1988) and 7's, over Pdebug.mli
   and a P-machine that pauses (Pmachine.resume):

       F7, F8        trace into, step over: a line at a time, the
                     execution bar on the line to run next; F7 goes
                     into the procedures a line calls, F8 runs them
       F4            go to the cursor's line
       Ctrl-F8       a breakpoint on the cursor's line, red; Ctrl-F9
                     runs to the next one
       Ctrl-F7       a watch: an expression (x, a[i], p.x) whose value
                     the Watches window shows at each pause
       Ctrl-F3       the call stack, each frame's static and dynamic
                     links beside its call (ours: the P-machine's view)
       Ctrl-F2       reset; Ctrl-C breaks a running program where it is

   The program's screen is shown only while it writes or reads, as
   Turbo's "smart" screen swapping did: a step that prints nothing
   doesn't flash it. Editing the text resets the program.

   The editor has Turbo's keys, which were WordStar's: the arrows or
   Ctrl-E, Ctrl-X, Ctrl-S, Ctrl-D; Ctrl-A and Ctrl-F a word; Home End
   PgUp PgDn; Ctrl-Y deletes a line; Insert toggles overwriting; Enter
   keeps the indentation (autoindent). The files are the floppy of
   Pascal_disk.mli, QUEENS.PAS open to begin with. F2 saves, F3 opens,
   F10 or Alt and a letter opens a menu, Alt-X quits. A desktop often
   keeps some function keys for itself (Alt-F5, Alt-F9, Ctrl-F2): every
   command is in the menus too.

   The modules, a key's way. The IDE is a Tui program (Tui.mli): a
   model, an update from an event, a view; it has no loop, no keyboard
   and no screen of its own.

       a host                         Tty_unix (a terminal), Window_sdl,
          |                           Window_draw (a window on Linux, on
          |                           mini-9pi); Keys (none: the tests)
       Tui.Key bytes, Tui.Tick
          | Turbo_update.update       by what is on the screen:
          |-- Turbo_edit.edit_key     a character, an arrow: the text
          |-- Turbo_menus.act         F9, a menu's item: a command
          |     '-- Turbo_debug       compile, go, a step:
          |          |-- Pascal_compile     the text to P-code, or an
          |          |                      error and its place
          |          '-- Pmachine, Pdebug   the P-code started, paused
          '-- Turbo_debug.advance     a tick while a program runs: its
          |                           machine a slice further
       Turbo_model.model              another value
          | Turbo_view.view
       Curses.t                       the screen, a value
          | the host                  what differs from the one before

   What is ours. The compiler is languages/pascal's, one pass to P-code
   as Wirth's Pascal-P did it (Pascal_compile.mli), and the program
   runs on its P-machine (Pmachine.mli), where the real one compiled
   to the 8086's own code. The debugger stands on what the compiler
   leaves for it (Pcode.mli: where each statement begins, each
   procedure's code and variables) and on a machine that pauses
   (Pdebug.mli): stepping stops at a statement's start, a watch is a
   name looked up along the static links, and the call stack shows
   them beside the dynamic ones. The menus and dialogs are drawn cell
   by cell, with no library of windows under them. Left undone:
   changing a variable while paused (Turbo's Evaluate and modify), a
   breakpoint with a condition, several edit windows, blocks (Ctrl-K
   B, Ctrl-K K), undo, the mouse.

   why-win:
   Compilers of 1983 for a microcomputer cost hundreds of dollars, came
   on several floppies, and went through passes and a linker, each
   reading and writing the disk. Turbo Pascal compiled in one pass
   from the editor's text in memory to machine code in memory: nothing
   was read or written between the key and the program running. The
   speed came from what it left out, and the environment from the
   speed: an error found in a second can be shown in the editor, with
   the cursor on it.

   cs-history:
   The editor's keys are older than the PC. WordStar (MicroPro, 1978)
   was the word processor of the CP/M machines, whose keyboards had no
   arrow keys: Ctrl-E, S, D and X are a diamond under the left hand,
   up, left, right and down. Turbo Pascal first ran on those machines
   too, and Borland's editors kept the diamond after every keyboard
   had arrows.

   evolution:
   After it. Turbo Pascal 6 (1990) rebuilt this screen on Turbo Vision,
   a library of windows, menus and dialogs in characters, given to its
   users for their own programs: the look here is its. Hejlsberg's
   next, Delphi (1995), was the same one key from the text to the
   program with forms drawn by the mouse; he then designed C# and
   TypeScript at Microsoft. An IDE of today asks the compiler about
   the text at each key and not at F9, but the three things in one
   place are the same.

   others:
   The other ways of ix to the same end. A Unix or Plan 9 programmer
   keeps the tools apart, an editor, a compiler, mk, and a shell to
   join them (mini-ed, mini-rc): any editor, any language. An Emacs
   runs the compiler from inside and reads its messages (not
   mini-emacs: Config_pad.mli). DrScheme (mini-drscheme) puts a prompt
   under the text, where one talks to the program just run. Smalltalk
   (mini-squeak) has no text to compile: the program is changed while
   it runs. *)

type model

val program : model Tui.program

(* for the tests: the text, the cursor (line and column from 0), the
   error bar, the screen's name ("edit", "menu", "dialog", "run",
   "user", "p-code"), the disk, and the execution bar's line (from 0)
   while a program is paused *)
val lines : model -> string list
val cursor : model -> int * int
val error : model -> string option
val screen : model -> string
val file : model -> string -> string option
val execution_line : model -> int option
