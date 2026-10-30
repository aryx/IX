(* Pim_window: mini-pim's window, the suite (plan_pim.md, "The views"):
   a Home that launches the views, and the views, Mail, Calendar,
   People, Tasks, Notes, Money, over the one store. The terminal's
   commands (Pim) are the same suite without a window; this is the one
   to look around in.

       Pim                                                <- the menu bar
       mini-pim                          Thursday 29 October 2026
         +----------+     +----------+     +----------+
         |  [mail]  |     |  [days]  |     |  [face]  |  <- a tile a view:
         |   Mail   |     | Calendar |     |  People  |     a click, or
         | 2 unread |     | 1 today  |     | 4 people |     m c p t n b
         +----------+     +----------+     +----------+
         | [ticks]  |     |  [page]  |     |  [bill]  |
         |  Tasks   |     |  Notes   |     |  Money   |
         +----------+     +----------+     +----------+
       Today
       12:30 lunch with alice
       late: answer Carol                                 <- in red
       due today: pay the electricity
       back from snooze: the plan

   Home is the beginning of the plan's Today (idea 4): what is late,
   due, back from a snooze, the day's events first. The suite opens
   on it (view=mail, calendar, people, tasks, notes or money opens a
   view: the tests').

   In a view the first menu is the suite's, Pim (Home, Mail,
   Calendar, People, Tasks, Notes, Money, each with its key, Ctrl and
   its number, Outlook's Go menu and keys; Exit), then the view's own;
   the sidebar's foot is the switcher, Outlook 2003's buttons. A view
   asks the suite for another (Pim_look.go): an item opened where it
   lives (a message in Mail, an event in Calendar, a person in People,
   a task in Tasks, a note in Notes: a task's message, a person's mail,
   a note's links), "write to" a person a message in Mail. Each view is
   read again from the store as it is shown, so what one changed (a
   task made in Mail) the other shows.

   Not yet: a search over every view. *)

type caps = Mail_window.caps

type model

(* the flags: Mail_window's, view= the one opened first *)
val initial : caps -> Playground.flags -> model

val update : caps -> Playground.computer -> model -> model
val view : Playground.computer -> model -> Playground.shape list
