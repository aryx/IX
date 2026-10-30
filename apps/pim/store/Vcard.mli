(* Vcard: the address book of another program read (RFC 6350's vCard,
   and 3.0's and 2.1's, which Google Contacts and Apple's write):
   plan_pim.md's "Contacts: a vCard file exported from Google once,
   imported", Google's contacts being read by a program only with
   OAuth (CardDAV), which waits.

       BEGIN:VCARD
       VERSION:3.0
       FN:Alice Martin                    -> name: Alice Martin
       EMAIL;TYPE=INTERNET:alice@ix       -> email: alice@ix
       item1.EMAIL:alice@home.example     -> email: (a group's, Apple's)
       TEL;TYPE=CELL:+33 6 12 34 56 78    -> phone:
       BDAY:1980-03-15                    -> birthday: (--03-15 no year)
       END:VCARD

   The lines are iCalendar's (Ics.unfold, Ics.content_line): the same
   folding and escapes, the format being its sibling (1996, the same
   Versit consortium). What the suite has no use for (photos,
   addresses on a map, URLs) is left. *)

type card = {
  name : string; (* FN, else N's given and family names *)
  emails : string list;
  phones : string list;
  birthday : string; (* "1980-03-15", "--03-15" without a year, "" *)
  org : string;
  note : string;
}

(* the file's cards, leniently: a line not understood skipped *)
val of_string : string -> card list

(* the card a contact (People's), its id its first address's; None
 * without an address, which mail could not name *)
val to_item : card -> Item.t option
