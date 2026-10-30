(* Lines: a connection that carries lines, over TCP or over TLS, for the
   mail's protocols (SMTP here, IMAP next).

   SMTP and IMAP are dialogues of lines ending in CR LF, and their
   machines are pure (Smtp.step: a line of the server's in, the lines
   to send back out). What is left is the socket: the bytes that come
   cut into lines, whatever pieces they came in, and the lines sent
   with their CR LF; and for IMAP's literals, a count of bytes read as
   they are. Over TLS (Tls_client) for Gmail, whose ports
   speak TLS from the first byte (465 for SMTP, 993 for IMAP: "implicit
   TLS", RFC 8314); over plain TCP for mini-maild, on this machine.

       Smtp.step   "250 OK"  ->  ["MAIL FROM:<a@ix>"]
            ^ line                  | send_line
            |                       v
       [line]: the bytes cut     "MAIL FROM:<a@ix>\r\n"
       at "\n", "\r" taken off      |
            ^                       v
       Tls_client.receive or     Tls_client.send or
       Tcp.arrived                Tcp.send_all

   (ix: the playground's Transport.t was this, a record of lines over
   TCP, TLS or a WebSocket; lib_networking's README says it was left out
   when TLS was copied. Here only the two a mail program needs.)

   A line is waited for Tcp.timeout seconds at most; a server that says
   nothing for that long, or closes, ends the dialogue.

   Worked example (checked by the tests, against mini-maild's machine
   on the other side of a pair of sockets): [talk] with Smtp's client
   sends a message, and its outcome is Sent to one. *)

type t

(* [plain caps ~host ~port]: TCP, nothing over it *)
val plain :
  < Cap.network; Cap.open_in; .. > -> host:string -> port:int ->
  (t, string) result

(* [tls caps ~trust ~host ~port]: TLS from the first byte *)
val tls :
  < Cap.network; Cap.open_in; .. > -> trust:X509.roots -> host:string ->
  port:int -> (t, string) result

(* a connection already made (a test's end of a socketpair) *)
val of_fd : Unix.file_descr -> t

(* a line sent, its CR LF added *)
val send_line : t -> string -> unit

(* the next line, its CR LF taken off; None when the other side has
 * closed or said nothing for Tcp.timeout seconds *)
val line : t -> string option

(* [bytes t n]: the next [n] bytes, as they are (an IMAP literal: a
 * message inside a line, "{1234}" then that many bytes) *)
val bytes : t -> int -> string option

(* [talk conn step machine finished]: each line that comes given to
 * [step], what it answers sent, until [finished machine] or the
 * connection ends; the machine as it was then *)
val talk : t -> ('m -> string -> 'm * string list) -> 'm -> ('m -> bool) -> 'm

(* why the connection ended, when it was not closed: the TLS
 * handshake failed, the certificate refused *)
val why : t -> string option

val close : t -> unit
