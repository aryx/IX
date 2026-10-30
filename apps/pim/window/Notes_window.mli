(* Notes_window: the suite's notes (plan_pim.md, stage 7), a text with
   links to anything, and a page for each day:

       Pim   Note   List
       the plan                                       note:the-plan
      +-----------+---------------------------------------------------+
      |#Notes#####| +-----------------------------------------------+ |
      | Days      | | lunch with [[contact:carol@ix]] about it;     | |
      |           | | see [[day:2026-10-29]]                        | |
      |           | +-----------------------------------------------+ |
      |           | -> Carol   (contact)                              |<- what
      |           | -> 2026-10-29   (day)                             |  it names,
      |           | <- pay the electricity   (task)                   |  what names
      +-----------+---------------------------------------------------+  it

   A note is an item stamped note, its text the item's (Item: the file
   reads as the note); its id made of its title (note:the-plan), so a
   link to it can be typed. A link is an item's id between [[ ]]
   (Links: a wiki's, then Roam's and Obsidian's); under the text, what
   the note names and what names it, a click opening it where it lives
   (a person in People, a message in Mail). The text is written to the
   store at each change, the Palm's way: no Save.

   d opens today's page (day:2026-10-29, made when first asked: the
   daily note of Roam and Logseq, where what a day touched is written
   and linked); n a new note, its title typed; o opens; Escape back;
   Tab Notes or Days. *)

type caps = Mail_window.caps

type model

(* today= the tests' day, else the clock's *)
val initial : caps -> Playground.flags -> model

(* the store read again, as the suite comes back to the view; [keys]
 * those down now *)
val refresh : caps -> string Set_.t -> model -> model

(* [show caps m id]: the note [id] opened *)
val show : caps -> model -> string -> model

(* a frame; and what it asks of the suite: an item a link names opened *)
(* today's page, made if it was not *)
val day_note : caps -> model -> model

val update : caps -> Playground.computer -> model -> model * Pim_look.go option

(* the view, under the menu bar and the menus, which the suite draws *)
val view : Playground.computer -> model -> Playground.shape list
