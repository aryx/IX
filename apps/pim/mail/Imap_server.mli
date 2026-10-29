(* Imap_server: the server's side of IMAP, mini-maild's, as a machine:
   a line of the client's in, the response's lines out (a literal, a
   message's bytes, inside its line: "BODY[] {44}\r\n" and the bytes),
   the messages and their flags in a store the program gives it.

   The subset mini-pim speaks to Gmail, Gmail's extensions included, so
   that the tests talk to this and never to Gmail: CAPABILITY, LOGIN
   (any password), LIST, SELECT and EXAMINE, UID SEARCH (ALL, SEEN,
   UNSEEN, X-GM-RAW's words, from: and subject:), UID FETCH (UID,
   FLAGS, RFC822.SIZE, X-GM-LABELS, X-GM-THRID, X-GM-MSGID, BODY[],
   BODY.PEEK[], BODY[HEADER], BODY[HEADER.FIELDS (...)]), UID STORE
   (FLAGS and X-GM-LABELS, set, added, taken off, .SILENT), NOOP,
   LOGOUT. Two mailboxes, as Gmail's: INBOX, the messages labelled
   \Inbox, and All Mail, all of them, its name the store's (Gmail's is
   in the account's language), LIST saying it is \All. A conversation
   (X-GM-THRID) is the UID of its first message, by Mail_thread.

   Not here: a client's literals (a LOGIN's password is quoted), IDLE,
   sequence numbers outside UID commands, MOVE, APPEND, EXPUNGE.

   Reference: RFC 3501, 6 the commands, 7 the responses. *)

(* a message as kept: its text (LF), its flags and labels *)
type message = { uid : int; text : string; flags : string list;
                 labels : string list }

(* a user's messages, oldest first, and a message's flags and labels
 * changed; the name of the mailbox of all of them ([Gmail]/All Mail) *)
type store = {
  all_mail : string;
  messages : string -> message list;
  change : string -> int -> flags:string list -> labels:string list -> unit;
}

type t

(* a session, and its greeting *)
val start : unit -> t * string list

val step : store -> t -> string -> t * string list

(* has the client said LOGOUT? *)
val ended : t -> bool
