(* Events: what the calendar shows, items stamped event (plan_pim.md,
   idea 1 and stage 3):

       id: event:1730193600.1
       stamp: event
       title: lunch with alice
       when: 2026-11-03 12:30             <- a day, and its time if it has
       end: 13:30                            one (a day's event has none)
       repeat: FREQ=WEEKLY;BYDAY=TU       <- iCalendar's RRULE (Recur, Ics)
       where: the canteen
       with: contact:alice@ix             <- a link (Links)

   A repeating event is one item, its rule; its days are computed for
   the days a calendar shows (Recur.occurrences), never stored. Times
   are the author's clock's, no zone (Ics's floating time): the zone's
   rules wait for a second place to be in.

   An invitation (iMIP, RFC 6047: a mail with a text/calendar part,
   Ics) becomes such an item, linked to its message by re:. *)

(* "12:30" as minutes after midnight, and back *)
val minutes : string -> int option
val clock : int -> string

(* an event's first day and its time, from when: *)
val start : Item.t -> (Civil.date * int option) option

(* how many days it lasts: from its start to its ends: (its last day,
 * an event of several days: Rome, a trip), 1 without *)
val length : Item.t -> int

(* [spans items ~from ~upto]: the occurrences of the events of several
 * days that cover a day of those, each its first day (perhaps before
 * [from]) and its length: what a week's and a month's bars show *)
val spans :
  Item.t list -> from:Civil.date -> upto:Civil.date ->
  (Civil.date * int * Item.t) list

(* [between items ~from ~upto]: the events' occurrences on those days
 * (both included), an event of several days on each of its days (its
 * time on its first), by day, the day's events (no time) first, then
 * by time *)
val between :
  Item.t list -> from:Civil.date -> upto:Civil.date ->
  (Civil.date * int option * Item.t) list

(* [of_ics zone ~message text]: an invitation's or a calendar's events
 * as items, [message] the id of the mail they came in ("" for a file);
 * one of several days its ends: (a date's DTEND the day after its
 * last, RFC 5545's);
 * UTC times at [zone]'s clock, a TZID's as written (floating); a
 * cancelled event left out; an occurrence moved its own item
 * (event:uid@its date), the series skipping that date and its
 * EXDATEs (except: the days, which [between] leaves out) *)
val of_ics : Zone.t -> message:string -> string -> Item.t list
