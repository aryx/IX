(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-oberon's boot (plan_system_oberon.md). The modules before this
 * one have started, as Oberon's do, each by its own body: the disk
 * read (FileDir), the display black (Display) and cut in two tracks
 * (Oberon), the log and System.Tool opened (System). Here: on the
 * serial line, its name and the disk's files; a text in the user's
 * track; the devices; then Oberon's loop.
 *
 * mini-oberon as a whole: Wirth and Gutknecht's Oberon system as one
 * sees and uses it, on the bare Pi, in OCaml. The screen, 1024 by
 * 768, two colours:
 *
 *     +--------------------------------+--------------------+
 *     | Welcome.Text | System.Close .. | System.Log | Edi.. |  menus,
 *     |--------------------------------|--------------------|  in
 *     |#                               |#                   |  inverse
 *     |#  a text, with its scroll bar  |#  the log          |
 *     |#  at the left                  |--------------------|
 *     |#                               | System.Tool | Sy.. |
 *     |--------------------------------|--------------------|
 *     | another viewer's menu          |#  System.Open ^    |
 *     |--------------------------------|#  Edit.Open        |
 *     |#                               |#  Hilbert.Draw     |
 *     +--------------------------------+--------------------+
 *        the user track, 640 wide         the system track, 384
 *
 * No window is over another: a track is cut in viewers. No menu
 * pops up, there is no shell and no icon: a command is a name, M.P,
 * in any text, run by a click of the middle key on it, and what
 * follows it there is its parameter. System.Tool is a text of such
 * names, and whoever wants another menu types one.
 *
 * The modules, each with the name it has in the book, in the order
 * they start (the mkfile's OBERON); a module uses only those above:
 *
 *     FileDir, Files     the files by name; a rider, a place in one
 *     Modules            the commands' table
 *     Display            the frame's pixels: five operations; what a
 *                        frame and a message are
 *     Fonts, Input       the letters' patterns; the mouse, the keys
 *     Viewers            the tracks and the viewers' rectangles
 *     Texts              a text: pieces of files
 *     Oberon             the loop, the messages, the log, the tasks
 *     MenuViewers        a viewer of two frames, a menu and a main
 *     TextFrames         a text shown and edited by the hand
 *     System, Edit       the commands
 *     Hilbert, Stars...  programs of others
 *     Main               this file
 *
 * And the whole system is one loop in one address space
 * (Oberon.loop): ask the mouse and the keys, send a message to the
 * viewer concerned, which draws and returns; when nothing happens,
 * call the tasks. No process, no system call, no interrupt but the
 * tick here that asks the USB devices. A command that goes wrong
 * raises, is said in the log, and the loop goes on.
 *
 * cs-history:
 * Niklaus Wirth and Jurg Gutknecht began Oberon at ETH Zurich in
 * 1985, back from a year at Xerox PARC where they had used Cedar,
 * a system of that size and comfort that no two people could know
 * whole. Theirs was to be understood entirely, and to fit a book:
 * a language (Oberon, Modula-2 with things removed and one added,
 * the extension of record types), its compiler, and the system, for
 * the Ceres workstation they built too; in use at ETH from 1988,
 * told in "Project Oberon" (1992). The edition followed here is
 * Wirth's of 2013, the same system for a processor of his own
 * design (RISC5) on an FPGA board: 40 modules, under 12,000 lines,
 * compiler included.
 *
 * others:
 * The tiled viewers are Cedar's before Oberon's; a text's words
 * as commands are Oberon's own. Rob Pike took both for Plan 9's
 * help (1991) and acme (1994), which says what it owes to Oberon;
 * mini-rio, in this tree, is Plan 9's other window system, of
 * overlapping windows each a process's. The loop that asks the
 * devices and sends an event to a handler is also the first
 * Macintosh's (1984), and every window system's since; what the
 * others added under it is processes.
 *
 * road-not-taken:
 * One address space, protected by the language's types alone, with
 * modules loaded on demand and a collector for all: no kernel mode
 * to cross, and a command is a procedure call. The systems that won
 * put a process around each program and paid for the walls.
 * mini-singularity, beside this directory, is the same bet made
 * again twenty years later, with processes.
 *
 * wib:
 * A command cannot be interrupted, a task that loops stops the
 * system, and two things happen at once only if each gives the
 * loop back quickly. Wirth's answer was that a personal machine has
 * one user doing one thing; the book has no chapter on scheduling.
 *
 * What is ours: the look, the feel and the modules' layering are
 * kept; the language is not (no Oberon compiler: a module is an
 * OCaml module, a message an exception, a frame's own state a
 * closure: Display.mli), nor the disk's format (FileDir.mli), and
 * no pixel is compared with the original's.
 *
 * References: Niklaus Wirth and Jurg Gutknecht, "Project Oberon:
 * The Design of an Operating System and Compiler" (Addison-Wesley,
 * 1992; the edition of 2013, with its sources, is on Wirth's pages
 * at ETH): one chapter a module, to read with this directory, whose
 * files have the chapters' names. Wirth and Gutknecht, "The Oberon
 * System" (Software: Practice and Experience, 1989): the paper, 37
 * pages. Wirth, "A Plea for Lean Software" (IEEE Computer, 1995):
 * why, with Oberon as the evidence. Rob Pike, "Acme: A User
 * Interface for Programmers" (USENIX Winter 1994).
 * plan_system_oberon.md: its survey counts the original's lines. *)

(* a tick every 10 ms, at which the USB devices are asked; the serial
 * line's characters are typed ones too *)
let tick_us = 10000

let devices () =
  Machine.wait_interrupt ();
  if Machine.timer_pending () then begin Machine.timer_arm tick_us; Usbhost.poll () end;
  let rec uart () = let c = Machine.uart_getc () in if c >= 0 then begin Input.typed (Char.chr c); uart () end in
  uart ()

let () =
  Machine.print "mini-oberon\n";
  FileDir.enumerate (fun f -> Machine.print (Printf.sprintf "%6d %s\n" f.length f.name));
  ignore (MenuViewers.new_ (TextFrames.new_menu "Welcome.Text" System.standard_menu)
            (TextFrames.new_text (TextFrames.text "Welcome.Text") 0) TextFrames.menu_h Oberon.user_track Oberon.display_height);
  Usbhost.init (fun code -> Input.typed (Char.chr (code land 255))) Input.moved;
  Machine.uart_rx_enable ();
  Machine.timer_arm tick_us;
  Input.poll := devices;
  Machine.print "mini-oberon: drawn.\n";
  Oberon.loop ()
