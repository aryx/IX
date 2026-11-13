(* Imap: reading mail kept on the server, with the Internet Message
   Access Protocol (Mark Crispin, 1986; IMAP4rev1, RFC 3501, 2003),
   which is Gmail's way in for a program.

   POP (1984) carried a mailbox home and emptied the server. IMAP
   leaves the mailbox there and looks at it from anywhere, which is why
   the phone and this program agree on what is read. It is harder to
   read than SMTP, and the difficulty is the lesson:

   - Commands are *tagged*, so that several can be in flight, and the
     server's answer to one ends with a line of the same tag:

       C: a3 UID SEARCH X-GM-RAW "from:alice"
       S: * SEARCH 4 9 12                    <- untagged: data
       S: a3 OK SEARCH completed             <- tagged: a3 is done

     Untagged lines also come unasked: "* 13 EXISTS" says that a
     message arrived while another command ran. A client takes them
     whenever they come.

   - *Literals*: "{1234}" at a line's end is followed by that many
     bytes, so that a message, which is any bytes, travels inside a
     line-based protocol:

       S: * 2 FETCH (UID 9 BODY[] {44}       <- the line, with its count
       S: Subject: lunch                        44 bytes, CR LF and all,
       S:                                        that are not lines of
       S: Noon at the usual place?               the protocol
       S: )                                  <- the line goes on

   - The data has a syntax of its own, read by [read] here: atoms
     (FLAGS, \Seen, BODY[HEADER]), quoted strings, NIL, and lists in
     parentheses, nested. "* 2 FETCH (UID 9 FLAGS (\Seen))" is
     [Atom "2"; Atom "FETCH"; List [Atom "UID"; Atom "9"; Atom "FLAGS";
     List [Atom "\Seen"]]]. (Numbers are atoms, because Gmail's thread
     ids are 64 bits, more than an int holds on a 32-bit arm.)

   - *UIDs*: a message's UID is its number in its mailbox, which does
     not change, while its sequence number (2 above) shifts when a
     message before it goes. A client asks by UID (UID SEARCH, UID
     FETCH). UIDVALIDITY, given at SELECT, says when the UIDs were
     renumbered, so that a cache must go.

   Gmail has its extensions (X-GM-EXT-1). X-GM-LABELS is a message's
   labels (Gmail has labels, not folders; "INBOX" is the label \Inbox,
   and archiving a message takes that label off). X-GM-THRID is the
   message's conversation. X-GM-RAW is a search in Gmail's own syntax,
   done by Gmail.

   The headers are asked for as BODY.PEEK[HEADER.FIELDS (...)], and read
   by Mail.parse, rather than as IMAP's ENVELOPE. ENVELOPE is a
   structure of its own, with no References: (which conversations need
   where there is no Gmail). PEEK means that looking is not reading:
   BODY[], the whole message, marks it read (\Seen).

   The tests check worked examples: the FETCH above is read, with its
   literal as the message; and the client runs against mini-maild's
   machine (Imap_server), with a login, INBOX selected, its messages
   searched, their headers, a body, and a label taken off.

   Reference: RFC 3501, "INTERNET MESSAGE ACCESS PROTOCOL - VERSION
   4rev1" (Mark Crispin, 2003): 6 the commands, 7 the responses, 9 the
   formal syntax; Google's "Gmail IMAP Extensions"
   (developers.google.com/gmail/imap/imap-extensions). *)

(*****************************************************************************)
(* {1 The responses} *)
(*****************************************************************************)

type value = Atom of string | String of string | List of value list | Nil

type response =
  (* a tagged status ("a3 OK ...", Some "a3"), or an untagged one
   * ("* OK [UIDVALIDITY 3] ...", None), with its word (OK, NO, BAD,
   * BYE, PREAUTH) and the text after it, as it is *)
  | Status of string option * string * string
  (* any other untagged response: "* SEARCH 4 9" *)
  | Data of value list
  (* "+ ...": go on (for IDLE, or a literal that the client sends) *)
  | Continue of string

(* [read ~line ~bytes] is the next response, with its literals read by
 * [bytes] (Lines.line and Lines.bytes); None when the connection
 * ended *)
val read : line:(unit -> string option) -> bytes:(int -> string option) ->
  response option

(* the values of a text with no literal, such as a command's
 * arguments *)
val values : string -> value list

(* a string as IMAP writes it: quoted, with its backslashes and double
 * quotes escaped *)
val quote : string -> string

(* [pairs l] gives the list of "(UID 9 FLAGS (\Seen))" as
 * [("UID", Atom "9"); ("FLAGS", List ...)], with the names in upper
 * case *)
val pairs : value list -> (string * value) list

(* the text of an atom or a string; "" for anything else *)
val text : value -> string

(* flags or labels as a list, "(\\Inbox \"my label\")", where a flag
 * with a space is quoted *)
val list : string list -> string

(* the texts of a list; [] for what is not a list *)
val texts : value -> string list

(* "1,3:5": a set of UIDs as IMAP writes it *)
val uid_set : int list -> string

(*****************************************************************************)
(* {1 The client} *)
(*****************************************************************************)

type t

val connect : Lines.t -> (t, string) result

(* [command t "UID SEARCH ALL"] sends the command with the next tag, and
 * reads the responses until the one with its own tag. It gives the
 * untagged ones, or the text of a tagged NO or BAD. *)
val command : t -> string -> (response list, string) result

val login : t -> user:string -> password:string -> (unit, string) result

(* the mailbox's UIDVALIDITY *)
val select : t -> string -> (string, string) result

(* LIST "" "*": the attributes and the name of each mailbox. Gmail's own
 * mailboxes are known by an attribute (RFC 6154), not by their names,
 * which are in the account's language: \All is [Gmail]/All Mail in
 * English, and [Gmail]/Tous les messages in French; the others are
 * \Sent, \Drafts and \Trash. *)
val mailboxes : t -> ((string list * string) list, string) result

(* the UIDs that a search gives, in order, for a search such as "ALL",
 * "UNSEEN" or "X-GM-RAW \"from:alice\"" *)
val search : t -> string -> (int list, string) result

(* what a list of messages shows *)
type summary = {
  uid : int;
  flags : string list; (* \Seen, \Answered, ... *)
  labels : string list; (* Gmail's: \Inbox, \Important, travel ... *)
  thread : string; (* Gmail's conversation, "" when there is none *)
  msgid : string; (* Gmail's id of the message, which is the same in
                     every mailbox, where a UID belongs to its mailbox;
                     "" when there is none *)
  headers : Mail.t; (* From, To, Cc, Subject, Date and the ids, no body *)
}

val summaries : t -> int list -> (summary list, string) result

(* the whole message, with LF; it is marked read *)
val message : t -> int -> (string, string) result

(* [messages t uids] is their whole texts, with LF, in one request, and
 * not marked read (BODY.PEEK[]): a mailbox fetched ahead, to be read
 * offline *)
val messages : t -> int list -> ((int * string) list, string) result

(* [store t uids change], where change is "+FLAGS (\\Seen)" or
 * "-X-GM-LABELS (\\Inbox)" *)
val store : t -> int list -> string -> (unit, string) result

val logout : t -> unit
