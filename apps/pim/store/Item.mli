(* Item: what mini-pim keeps, a message, an event, a person, a task, a
   note or money, and every one of them the same thing (plan_pim.md,
   ideas 1 and 3): lines of "name: value", the syntax of a mail's
   headers and read by the same parser (Mail), then, after an empty
   line, a text if it has one.

       id: mail:1784                      <- the item's name, its file's
       stamp: message task                <- what it is: the views it is in
       subject: answer Alice              <- the rest: each kind's fields,
       due: 2026-11-05                       any other a person adds
                                          <- the empty line
       about the plan, before Friday      <- its text (a note's)

   An item's *stamps* say what it is, and an item can be several things
   at once (Chandler's idea): a message stamped task is still the
   message, now in the task list too, with a due date; nothing is
   copied. The calendar shows what has a time, the tasks what has a due
   date, whatever else the item is.

   An id is a kind and a name, "mail:1784", "contact:alice": the kind
   says where it came from (a message's id is Gmail's X-GM-MSGID), and
   the name is unique in that kind. A link to an item is its id as a
   field's value ("with: contact:alice"), so the file says it in words. *)

type t = Mail.t

(* [make ~id ~stamps fields text] *)
val make : id:string -> stamps:string list -> (string * string) list ->
  string -> t

(* its "id:" field; "" when none *)
val id : t -> string

(* the words of its "stamp:" fields *)
val stamps : t -> string list

val has_stamp : t -> string -> bool

(* [field t name]: the field's value, "" when none *)
val field : t -> string -> string

(* an item read from its file's text *)
val parse : string -> t

val to_string : t -> string
