(* People: the address book (plan_pim.md, stage 4), filled from the
   mail, BBDB's way (Jamie Zawinski's Big Brother Database for Emacs,
   1991): a sender made a contact by a key, not every address seen,
   so the book holds the people the author chose.

       id: contact:alice@ix        <- the address, which mail names
       stamp: contact
       name: Alice
       email: alice@ix             <- one email: line an address; a
       email: alice@home.example      person has several

   A person's page is the suite's most useful (plan_pim.md, idea 2):
   their addresses, then the mail with them -- from them or to them,
   by any of their addresses -- then what names them (Links). The mail
   is found by its addresses, not by links: a message names an
   address, and the contact is what says whose it is. *)

(* "contact:alice@ix": a contact's id, of its first address *)
val id : Mail.address -> string

(* [of_sender message]: a contact of the item's From: *)
val of_sender : Item.t -> Item.t option

(* its email: lines, in lower case *)
val emails : Item.t -> string list

(* the contacts, by name *)
val contacts : Item.t list -> Item.t list

(* [with_ items contact]: the messages from or to it, newest first *)
val with_ : Item.t list -> Item.t -> Item.t list

(* [who items address]: the contact of an address, if there is one *)
val who : Item.t list -> string -> Item.t option
