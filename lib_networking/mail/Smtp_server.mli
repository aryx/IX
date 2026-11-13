(* Smtp_server: the server's side of SMTP, the post office's counter,
   as a pure machine. A line from the client goes in, the lines of the
   reply come out, and so does the message when one has been taken.

       client                         Smtp_server               maildrop
       EHLO pim          ->  250-ix greets pim, 250 AUTH PLAIN
       AUTH PLAIN AGFs.. ->  235 (any password: a test's server)
       MAIL FROM:<a@ix>  ->  250
       RCPT TO:<bob@ix>  ->  250       (another domain: 550, no relay)
       DATA              ->  354
       ... the message
       .                 ->  250 queued   --- a delivery ------>  bob

   It takes mail for its own domain only ("bob@ix", or "bob"). It adds
   a Received: line on top that says from whom and when (every server
   that a message crosses adds one, and read bottom up they are its
   route). Mail for elsewhere is refused with 550. A server that passed
   it on was an *open relay*; every server was one in the 1980s, until
   the spam of the 1990s made them all close.

   mini-maild runs it over a socket; the tests run it against Smtp's
   client, one line at a time.

   (ix: this is the SMTP half of libs/networking/unix/Mail_server.ml in
   the author's playground, as a machine of its own, without its
   sockets and its POP3 half. AUTH PLAIN was added, because Gmail asks
   for it.)

   Reference: RFC 5321, 4.1 the commands, 4.4 the Received: line; RFC
   4954, AUTH. *)

type t

(* a message taken: who it is for (the users of the domain), and the
 * message with its Received: line *)
type delivery = { users : string list; mail : Mail.t }

(* [start ~domain] is a session, and its greeting *)
val start : domain:string -> t * string list

(* [step t ~now line] takes the client's [line]; [now], the seconds
 * since the epoch, is for the Received: line *)
val step : t -> now:float -> string -> t * string list * delivery option

(* has the client said QUIT? *)
val ended : t -> bool
