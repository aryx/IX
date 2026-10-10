(* Connections kept: a request sent on the connection the last one
   used, instead of a new one each time.

   HTTP/1.0 closed the connection after each answer: the end of the
   body was the end of the connection, nothing to count. A page of
   forty pictures was then forty connections, each paying its three
   packets of TCP's opening and its slow start -- and, since the web
   is encrypted, a TLS handshake: here some 0.2 s of arithmetic each
   (a key agreed, a chain of certificates checked), on top of two
   round trips.

     without                         with
     ------------------------------  ------------------------------
     connect, handshake              connect, handshake
     GET /a.png   -> 200, closed     GET /a.png   -> 200
     connect, handshake              GET /b.png   -> 200
     GET /b.png   -> 200, closed     GET /c.png   -> 200
     connect, handshake              ... (left open a while)
     GET /c.png   -> 200, closed

   For the connection to stay open the answer must say where it ends
   by itself: Content-Length, or a body in chunks (Http.extent). An
   answer that says neither ends when the connection does, and that
   connection is not kept.

   The pool is a list of connections at rest, each with its host and
   port and when it was put there. [exchange] takes one for its host if
   there is one (the most recent), else connects; when the answer is
   whole and the server did not say "Connection: close", the connection
   goes back. One at rest for more than [patience] seconds is closed,
   not used: servers close theirs after some seconds of silence
   (nginx: 75 by default; many less).

   The one subtlety: a connection taken from the pool may be dead, the
   server having closed it since -- which is seen only when nothing
   comes back. Then, and only if not one byte of an answer came, the
   request is sent again on a new connection: nothing says the server
   read it (RFC 9112, section 9.3.1; for a POST a browser asks less,
   and so do we: the same rule).

   The pool is the program's; there are no threads here, so no mutex
   round it.

   What it bought in mini-chrome, discuss.ocaml.org's front page (31 style sheets, 60
   avatars each behind a redirection: 150 requests to three hosts),
   2026-10-04:

                                          closed each    kept
     the pictures (60, two requests each)      15 s          7 s
     the program's CPU for the whole load      18 s          9 s

   (then six threads where four were: the pictures in 4.5 s. The same
   day the page's 31 sheets stopped costing a layout each, which was
   12 s more: docs/dev/notes_debugging_techniques.txt, session 5.)

   cs-history:
   "Connection: Keep-Alive" was an extension of 1995's servers and
   browsers (Netscape's among them) to HTTP/1.0; HTTP/1.1 (RFC 2068,
   January 1997) made it the default and gave the body its framings
   for it, the chunks among them. Jeffrey Mogul's "The Case for
   Persistent-Connection HTTP" (SIGCOMM 1995) and Venkata Padmanabhan
   and Mogul's "Improving HTTP Latency" (1994) are the measurements
   that argued it.

   modern:
   A browser keeps six connections a host and sends one request at a
   time on each; HTTP/2 (2015) sends them all at once on one, as
   numbered streams, and TLS 1.3 can resume a session without the
   whole handshake (a ticket: not done here, Tls13.mli).

   Reference: RFC 9112 (HTTP/1.1), section 9: Connection Management. *)

(* [exchange caps ~trust ~host ~port request]: the answer's bytes, whole
 * (its head and its body as framed), over TLS; Tcp.timeout seconds of
 * silence are an error. As Tls_client.exchange, which closes after each *)
val exchange : < Cap.network; Cap.open_in; .. > -> trust:X509.t list -> host:string -> port:int -> string -> (string, string) result

(* how long a connection at rest is still used, in seconds *)
val patience : float

(* the connections at rest closed (a test's end) *)
val clear : unit -> unit

(* how many requests went on a connection already open, since the start *)
val reused : unit -> int
