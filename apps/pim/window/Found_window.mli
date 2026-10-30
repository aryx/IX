(* Found_window: what Detect finds in the message read, kept with a key
   (plan_pim.md, idea 4: Data Detectors over mail). x in Mail, reading
   a conversation, shows it over Mail; Mail underlines the same as it
   shows the text.

       Pim   Found
       Found in: lunch                     Enter: an event
      +----------------+---------------------------------------------+
      |#3 things found#| day      tuesday at 12:30   2026-11-03 12:30|
      |                |          Lunch on tuesday at 12:30? It's ...|
      |                | amount   24,50 €            24.50           |
      |                | address  dan@ix             Dan <dan@ix>    |

   Enter keeps the row, linked to its message by re: (as a task made
   of a mail, plan_pim.md's idea 2): a day an event, titled by the
   subject (less Re:), with the sender if People has them; an amount a
   bill, a task stamped money with its postings (Expenses:Bills, paid
   from Assets:Checking), due the message's first day found; an
   address a contact (one already in People is opened). A row kept is
   ticked; Enter on it opens what it made, where it lives. Esc back to
   the message. *)

type caps = Mail_window.caps

type model

val initial : caps -> Playground.flags -> model

(* [start keys m messages]: what the messages (Mail_window.opened)
 * say; [keys] those down now *)
val start : string Set_.t -> model -> (string * Mail.t) list -> model

val update : caps -> Playground.computer -> model -> model * Pim_look.go option

(* the view, under the menu bar and the menus, which the suite draws *)
val view : Playground.computer -> model -> Playground.shape list
