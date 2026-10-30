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

(* All Mail, as mini-pim names it, in the store and to the session
 * below, which selects the server's own name of it: the mailbox LIST
 * says is \All ([Gmail]/Tous les messages in a French Gmail) *)
val all_mail : string

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

(* the app password the author keeps in the store's directory, the
 * file "password" (~/.ix-pim/password): its first line. mini-pim never
 * writes it; a person makes it, readable by them alone:
 *
 *     (umask 077; read -s P; echo "$P" > ~/.ix-pim/password)
 *
 * Ok None when there is none; an Error when others may read it (its
 * mode not 600 or 400: ssh's rule for a key), it is not used then *)
val saved_password :
  < Cap.env ; Cap.open_in ; .. > -> (string option, string) result

(* the [n] last of a list *)
val newest : int -> 'a list -> 'a list

(* the item of a mailbox's UID, as the last list kept it *)
val item_of :
  < Cap.open_in ; Cap.readdir ; .. > -> Items.t -> account:string ->
  mailbox:string -> int -> Item.t option

(*****************************************************************************)
(* {1 Snooze} *)
(*****************************************************************************)

(* Snooze (plan_pim.md, idea 5; plan_mail.md, z): a message put away
   until a day, archived on Gmail's side meanwhile, so the phone agrees;
   its item says until: 2026-11-02. That day, the next time the mail is
   got, it is labelled \Inbox again (found in All Mail by its
   X-GM-MSGID: its UID in INBOX is gone), and its item says woke:, so
   the list puts it on top. Gmail's own snooze is not IMAP's: the
   phone sees it archived, not snoozed. *)

(* "2026-11-02" *)
val day : Civil.date -> string

(* [snooze caps store t ~account ~mailbox uids ~until]: archived, and
 * each item's until: *)
val snooze : < Cap.open_in ; Cap.open_out ; Cap.readdir ; .. > -> Items.t ->
  Imap.t -> account:string -> mailbox:string -> int list ->
  until:Civil.date -> (unit, string) result

(* [wake caps store server ~user ~password ~today]: the messages whose
 * day has come back in the Inbox, on the server and in their items;
 * how many *)
val wake : < Cap.network ; Cap.open_in ; Cap.open_out ; Cap.readdir ; .. > ->
  Items.t -> server -> user:string -> password:string -> today:Civil.date ->
  (int, string) result

(*****************************************************************************)
(* {1 Sending} *)
(*****************************************************************************)

(* Gmail's: smtp.gmail.com:465, TLS from the first byte *)
val gmail_smtp : server

(* a connection to the server, TLS unless plain; the error says
 * host:port *)
val connect : < Cap.network ; Cap.open_in ; .. > -> server ->
  (Lines.t, string) result

(* [send caps server ~auth mail]: to whom its To:, Cc: and Bcc: say,
 * from its From: (else the user's); each message's outcome *)
val send : < Cap.network ; Cap.open_in ; .. > -> server ->
  auth:(string * string) option -> Mail.t ->
  (Smtp.outcome list, string) result

(* an outcome in words: "sent to 2, refused: ..." *)
val said : Smtp.outcome -> string

(* [send_draft caps store server ~user ~password draft]: the draft made
 * a message (Mail_compose.message: from [user], dated now in this
 * place's zone, its files read, a forward's attachments from the
 * cache) and sent; its item removed once every recipient took it. The
 * outcome in words. *)
val send_draft :
  < Cap.network ; Cap.open_in ; Cap.open_out ; Cap.env ; .. > ->
  Items.t -> server -> user:string -> password:string ->
  Mail_compose.draft -> (string, string) result
