(* Pim_store: mini-pim's commands over the store, from a terminal, those
   that need no mail server (Pim has the mail's, and reads the command
   line): every item, the calendar and the day, the money.

       mini-pim search from:alice is:task      a line an item:
       contact:alice@ix         contact          Alice Martin
       mini-pim show contact:alice@ix          its file, its links
       mini-pim add task:pay-rent due=friday   an item; set its fields
       mini-pim event lunch with alice tue 12:30
       mini-pim import file.ics, file.qif      events; a bank's lines
       mini-pim today                          the day (Home's Today)
       mini-pim register -a Assets:Checking    Quicken's columns
       mini-pim balance                        every account's

   Each command reads the store again (Items.all) and writes an item
   at once; what they print is what the tests (session.sh) compare. *)

type caps =
  < Cap.open_in ; Cap.open_out ; Cap.readdir ; Cap.env ; Cap.stdout
  ; Cap.stderr >

(* the reason on standard error, and the exit's *)
val fail : < Cap.stderr ; .. > -> string -> Exit.t

(* an item's line: [prefix], its id, its stamps, its title *)
val line : < Cap.stdout ; .. > -> string -> Item.t -> unit

(* the items a query matches (Search) *)
val search : < caps ; .. > -> string -> Exit.t

(* the item's file, then its links both ways; a person's mail first *)
val show : < caps ; .. > -> string -> Exit.t

(* the address book *)
val people : < caps ; .. > -> Exit.t

(* "due=2026-11-05" ...: the names and values, None if one is not *)
val assignments : string list -> (string * string) list option

(* [days today fields]: due= and until= given as words made days *)
val days :
  Civil.date -> (string * string) list -> ((string * string) list, string) result

(* add: an item made, stamped its id's kind unless stamp= says; set: its
 * fields given, an empty value taking one away *)
val add : < caps ; .. > -> string -> (string * string) list -> Exit.t
val set : < caps ; .. > -> string -> (string * string) list -> Exit.t

(* [event caps today words]: a line made an event (Capture) *)
val event : < caps ; .. > -> Civil.date -> string -> Exit.t

(* [import caps account file]: an iCalendar file's events (Events.of_ics),
 * an event already there replaced; a .qif file's lines in the account's
 * register (Books), those already there left out *)
val import : < caps ; .. > -> string -> string -> Exit.t

(* [today caps ~account day]: the day (Today): its events, the tasks
 * late and due, what is back from a snooze, the unread mail of
 * [account] from people; then the day's page *)
val today : < caps ; .. > -> account:string -> Civil.date -> Exit.t

(* register: an account's lines, the balance after each; balance: every
 * account's *)
val register : < caps ; .. > -> string -> Exit.t
val balance : < caps ; .. > -> Exit.t
