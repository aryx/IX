(* Calendar_window: the suite's calendar (plan_pim.md, stage 3), the
   events (Events: items stamped event) by day, week or month, Google
   Calendar's keys:

       Pim   Event   View
       Week of 2 November 2026                                3 events
      +-----------+-------+-------+-------+-------+-------+----+----+
      | Day       |Mon 2  |Tue 3  |Wed 4  |Thu 5  |Fri 6  |Sat |Sun |
      |#Week######|9:30   |12:30  |9:30   |16:00  |       |    |    |
      | Month     |standup|lunch  |standup|dentist|       |    |    |
      +-----------+-------+-------+-------+-------+-------+----+----+

   c creates an event from one line (Capture: "lunch with alice tue
   12:30", "standup every monday 9h30"); j k the next and the previous
   period; t today; d w m a day, a week (Monday first), a month (six
   weeks); the arrows move the day selected; o or Enter that day's
   page, its events and the selected one's details (o again: an
   invitation's mail, in Mail); u back to the week; g Google's
   calendars fetched (Calendars: their secret addresses). A repeating event
   is computed for the days shown (Recur), never stored as a list. *)

type caps = Mail_window.caps

type model

(* today= the tests' day, else the clock's; the week opened on it *)
val initial : caps -> Playground.flags -> model

(* the store read again, as the suite comes back to the view; [keys]
 * those down now *)
val refresh : caps -> string Set_.t -> model -> model

(* [show caps m id]: the event [id]'s day, it selected *)
val show : caps -> model -> string -> model

(* a frame; and what it asks of the suite: an invitation's mail *)
val update : caps -> Playground.computer -> model -> model * Pim_look.go option

(* the view, under the menu bar and the menus, which the suite draws *)
val view : Playground.computer -> model -> Playground.shape list
