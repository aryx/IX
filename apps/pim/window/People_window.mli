(* People_window: the suite's address book (plan_pim.md, stage 4), the
   contacts by name, and a person's page, the suite's most useful
   (idea 2):

       Pim   Person
       Carol                                             2 messages
      +-----------+---------------------------------------------------+
      |#People####| carol@ix                                          |
      |           |                                                   |
      |           | Mail                                              |
      |           |#2026-10-29   Carol   Re: the plan#################|
      |           | 2026-10-28   Erin    the plan                     |
      +-----------+---------------------------------------------------+

   o opens a person's page: their addresses, then the mail with them
   by any of them (People.with_), j k among it, o a message opened in
   Mail; c writes to them (Mail, its To: filled); n adds a person
   typed as an address ("Dan <dan@ix>"), p in Mail a conversation's
   sender. *)

type caps = Mail_window.caps

type model

val initial : caps -> Playground.flags -> model

(* the store read again, as the suite comes back to the view; [keys]
 * those down now *)
val refresh : caps -> string Set_.t -> model -> model

(* [show caps m id]: the person [id]'s page *)
val show : caps -> model -> string -> model

(* a frame; and what it asks of the suite: a message opened in Mail, a
 * message written *)
val update : caps -> Playground.computer -> model -> model * Pim_look.go option

(* the view, under the menu bar and the menus, which the suite draws *)
val view : Playground.computer -> model -> Playground.shape list
