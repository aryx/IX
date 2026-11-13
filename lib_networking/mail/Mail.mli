(* Mail: a message, as RFC 822 wrote it (David Crocker, 1982) and RFC
   5322 still does: header fields, an empty line, and a body.

       From: Alice <alice@tiny>                 <- a field: a name, a colon,
       To: bob@tiny                                a value
       Subject: lunch
       Date: Fri, 25 Sep 2026 12:00:00 +0200
       Message-ID: <1@tiny>
       Received: from eudora by tiny;           <- a long value folded: a line
         Fri, 25 Sep 2026 12:00:01 +0200           starting with a space goes
                                                   on with the one before
                                                <- the empty line: headers end
       Noon at the usual place?                 <- the body, lines of text

   That is all a message is, and it has not changed since 1982: what
   came later (MIME, Mime.mli) put everything else *inside* this shape
   rather than change it. A field can appear twice (every server that
   the message passed through adds a Received: at the top), so the
   fields are a list, in order, not a table. Their names are looked up
   without regard to case ("message-id" finds Message-ID).

   A field keeps its value as written, folding and all ([raw]), so that
   a message read and written again is the same bytes: a mailbox that
   is rewritten after marking one message read must not change the
   others. [get] unfolds the value: it removes the line breaks, and
   keeps the space that followed each one (RFC 5322, 2.2.3). This is
   unlike the folding of iCalendar (RFC 5545), where the space is
   removed too, which is why the two do not share code.

   Lines end in CR LF on the wire and in LF in a file. [parse] takes
   either and keeps LF, and the protocols (Smtp, Pop3) put the CRs back.
   (ix: here they are Smtp and Imap; there is no Pop3, see
   plan_mail.md.)

   The tests check a worked example. The message above parses to six
   fields. [get m "subject"] is "lunch", and [get m "received"] is
   "from eudora by tiny; Fri, 25 Sep 2026 12:00:01 +0200". The From: is
   the address { display = "Alice"; mailbox = "alice@tiny" }. The date
   is 2026-09-25 at 12:00:00, 120 minutes east of Greenwich, which is
   10:00 in Greenwich. And [to_string] gives back the same bytes.

   References: RFC 822, "Standard for the format of ARPA Internet text
   messages" (1982); RFC 5322, "Internet Message Format" (2008), with
   the addresses in its section 3.4 and the dates in 3.3. *)

(*****************************************************************************)
(* {1 A message} *)
(*****************************************************************************)

(* a header field: its name as written, and everything after the colon
 * as written, with the folding kept: [{ name = "To"; raw = " bob@tiny" }] *)
type field = { name : string; raw : string }

type t = { fields : field list; body : string }

(* parses the text of a message, with CR LF or LF line ends. The headers
 * end at the first empty line, or at a line that is neither a field
 * nor a continuation (that line is then the body's first line). *)
val parse : string -> t

(* the message written back, with lines ending in LF *)
val to_string : t -> string

(* [get m name] is the first field of that name, in any case, with its
 * value unfolded and trimmed *)
val get : t -> string -> string option

(* every field of that name, in order *)
val get_all : t -> string -> string list

(* [set name value m] gives [value] to the first field of that name
 * (and removes the others), or adds a new field at the end *)
val set : string -> string -> t -> t

(* [remove name m] removes every field of that name *)
val remove : string -> t -> t

(* [make fields body] is a message made from names and values *)
val make : (string * string) list -> string -> t

(* removes a value's line breaks: "a\n  b" becomes "a  b" *)
val unfold : string -> string

(* turns the wire's CR LF line ends into a file's LF *)
val lf : string -> string

(*****************************************************************************)
(* {1 Addresses} *)
(*****************************************************************************)

(* "Alice <alice@tiny>" has a display name and a mailbox. "alice@tiny"
 * alone has an empty display name. The old form "alice@tiny (Alice)"
 * reads the same as the first. *)
type address = { display : string; mailbox : string }

val address : string -> address option

(* a list of addresses, separated by commas, but not by the commas
 * inside quotes, angle brackets or parentheses:
 * "\"Smith, J\" <j@tiny>, bob@tiny" is two addresses *)
val addresses : string -> address list

(* the display name is quoted when it has to be *)
val address_to_string : address -> string

(* the name to show: the display name, or else the mailbox *)
val who : address -> string

(* "\"Smith, J\"" becomes "Smith, J" (trimmed); anything else stays as
 * it is *)
val unquote : string -> string

(*****************************************************************************)
(* {1 Dates} *)
(*****************************************************************************)

(* "Fri, 25 Sep 2026 12:00:00 +0200": the day and the time where it was
 * written, and that place's offset, in minutes east of Greenwich *)
type date = { day : Civil.date; time : Clock.time_of_day; offset : int }

(* The weekday and the seconds are optional. It reads two-digit years
 * (49 is 2049, 50 is 1950), and the old zone names (GMT, EST,
 * PDT...). *)
val date : string -> date option

val date_to_string : date -> string

(* seconds since the epoch, to sort by *)
val seconds : date -> float

(*****************************************************************************)
(* {1 Message-IDs} *)
(*****************************************************************************)

(* the ids in a Message-ID, In-Reply-To or References value:
 * "<1@tiny> <2@tiny>" is ["1@tiny"; "2@tiny"] *)
val message_ids : string -> string list
