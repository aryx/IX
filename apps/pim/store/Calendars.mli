(* Calendars: Google's calendars, read (plan_pim.md, "Google's side"):
   each calendar's secret address in iCalendar format (Google Calendar's
   settings, "Integrate calendar", "Secret address in iCal format"),
   fetched by HTTPS (Http_client: ix's own TLS), its events made items
   (Events.of_ics). Read only: writing back is CalDAV, which Google lets
   a program do only with OAuth, which waits.

       ~/.ix-pim/calendars              (mode 600: the address is a
       # name  its address                 secret, a key to read the
       me      https://calendar.google.com/calendar/ical/.../basic.ics
       family  https://calendar.google.com/calendar/ical/.../basic.ics

   A person writes that file, mini-pim never does (Items.secret), as
   the password's. Each event fetched says its calendar (calendar:
   me); a fetch is the calendar's mirror: events new or changed saved,
   those gone from it (deleted on Google's side) removed, the rest not
   written again. An event of the suite's own (calendar: none) is never
   touched. *)

type source = { name : string; url : string }

(* the store's file calendars: a line a calendar, its name then its
 * address; # a comment; Ok [] without the file *)
val sources : < Cap.env ; Cap.open_in ; .. > -> (source list, string) result

(* [merge items name fetched]: the fetched events, stamped [name]'s,
 * that are new or changed, and the ids of [name]'s events no longer
 * there *)
val merge : Item.t list -> string -> Item.t list -> Item.t list * string list

(* the calendar fetched and merged into the store: how many saved, how
 * many removed *)
val fetch :
  < Cap.network ; Cap.env ; Cap.open_in ; Cap.open_out ; Cap.readdir ; .. > ->
  source -> (int * int, string) result
