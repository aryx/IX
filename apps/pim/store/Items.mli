(* Items: mini-pim's store, a directory of plain text a person can
   read (plan_pim.md, idea 3):

       $PIM_STORE, or ~/.ix-pim on Linux, $home/lib/pim on mini-9pi
         items/mail:1784        an item a file (Item.mli), its id its name
         items/contact:alice
         cache/1784             a message's bytes, as the server gave them

   An item is written as soon as it changes (the Palm's: no Save), so
   the store is always what was last done; ed reads and fixes it, grep
   searches it, mini-git keeps its history. A file an item, not a file
   a month or a kind: two programs (the window and `pim remind`) write
   different files, and mini-git's history is an item's.

   The cache is the one part that can be thrown away: the mail's
   bodies, fetched when a message is opened, kept so that it can be
   read again without the network (plan_mail.md: "reading offline").
   The items keep what lists and searches need; a message's item is
   its headers.

   Worked example (checked by the tests): an item saved, found by its
   id, among all; saved again changed, the file is the new one; a
   message's bytes in the cache and back. *)

type t

(* $PIM_STORE, else ~/.ix-pim, else $home/lib/pim *)
val place : < Cap.env; .. > -> string

(* the store in that directory; made when an item is first saved *)
val at : string -> t

val find : < Cap.open_in; .. > -> t -> string -> Item.t option

(* written now, under its id *)
val save : < Cap.open_out; .. > -> t -> Item.t -> unit

(* gone: a draft once sent *)
val remove : < Cap.open_out; .. > -> t -> string -> unit

(* every item, in the order of their ids *)
val all : < Cap.open_in; Cap.readdir; .. > -> t -> Item.t list

val cached : < Cap.open_in; .. > -> t -> string -> string option
val cache : < Cap.open_out; .. > -> t -> string -> string -> unit
