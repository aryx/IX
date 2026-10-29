(* Mail_sync: the mail between the server and mini-pim's store, what the
   command line (Pim.ml) and the window (Mail_window) both do: a session
   opened and logged in, the newest messages listed into the store's
   items (Mail_item), a message's bytes fetched into its cache, a
   message archived on the server and in its item.

   Each is one IMAP session, opened and closed, as a person asks:
   simple, and slow only by a TLS handshake. (IDLE, a session kept and
   told of new mail, is the window's later.) *)

type server = { host : string; port : int; plain : bool (* no TLS *) }

(* Gmail's: imap.gmail.com:993, TLS *)
val gmail : server

(* [session caps server ~user ~password ~mailbox f]: [f] with the
 * mailbox selected; logged out after *)
val session :
  < Cap.network ; Cap.open_in ; .. > -> server -> user:string ->
  password:string -> mailbox:string -> (Imap.t -> ('a, string) result) ->
  ('a, string) result

(* the summaries kept in the store, each message's item made or
 * updated *)
val keep :
  < Cap.open_in ; Cap.open_out ; .. > -> Items.t -> account:string ->
  mailbox:string -> Imap.summary list -> unit

(* [list caps store t ~account ~mailbox ~query n]: the [n] newest of a
 * search (Gmail's syntax; None: all), kept *)
val list :
  < Cap.open_in ; Cap.open_out ; .. > -> Items.t -> Imap.t ->
  account:string -> mailbox:string -> query:string option -> int ->
  (Imap.summary list, string) result

(* a message's text: the cache's, or the server's into the cache; marked
 * read on the server and in its item *)
val message :
  < Cap.open_in ; Cap.open_out ; .. > -> Items.t -> Imap.t ->
  account:string -> mailbox:string -> int -> (string, string) result

(* the \Inbox label taken off, on the server and in the items *)
val archive :
  < Cap.open_in ; Cap.open_out ; Cap.readdir ; .. > -> Items.t -> Imap.t ->
  account:string -> mailbox:string -> int list -> (unit, string) result

(* the [n] last of a list *)
val newest : int -> 'a list -> 'a list

(* the item of a mailbox's UID, as the last list kept it *)
val item_of :
  < Cap.open_in ; Cap.readdir ; .. > -> Items.t -> account:string ->
  mailbox:string -> int -> Item.t option
