(* Capture: one line typed, made an event (plan_pim.md, idea 4: the
   Agenda's and the Newton's "lunch with alice tue 12:30"), the
   recognizer's words for a day (When), a time, a repeat and people:

       lunch with alice tue 12:30
         -> title "lunch with alice", Tuesday, 12:30,
            with: contact:alice@ix         <- alice is in People
       standup every monday 9h30
         -> FREQ=WEEKLY;BYDAY=MO, the next Monday, 9:30
       dentist nov 5 at 4pm
         -> November 5, 16:00
       roma nov 3 to nov 7               <- to, au, -, until: its last
         -> November 3, ends: November 7    day
       déjeuner avec alice mardi 12h30     <- the author's French

   A time: 12:30, 12h30, 12h, 4pm, 11am, noon, midi (an "at" or "à"
   before it dropped). A repeat: every (chaque) day, week, month,
   year, or a weekday. A day: When's words, at the end of what is
   left; none, today (a repeat's first day: the next one). A person:
   the word after "with" ("avec") that is a contact's first name or the
   start of their address. The title is the line less the day, the
   time and the repeat. *)

type event = {
  title : string;
  day : Civil.date;
  time : int option; (* minutes after midnight *)
  ends : Civil.date option; (* its last day, "nov 3 to nov 7" *)
  repeat : string; (* RRULE's text, "" for none *)
  with_ : string list; (* the contacts' ids *)
}

(* "12:30", "12h30", "12h", "4pm", "11am", "noon", "midi": minutes
 * after midnight *)
val time_of : string -> int option

(* [event ~today ~people line] *)
val event : today:Civil.date -> people:Item.t list -> string -> event

(* the item, its id given *)
val to_item : id:string -> event -> Item.t
