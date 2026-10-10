(* Http_client: getting a URL, the three layers put together.

     "http://elm-lang.org/images/turtle.gif"
        | Url.parse
        v
     scheme http, host elm-lang.org, port 80, target /images/turtle.gif
        | Http.get, Http.request_to_string
        v
     "GET /images/turtle.gif HTTP/1.1\r\nHost: elm-lang.org\r\n..."
        | Tcp.exchange (DNS, connect, send, read until closed)
        v
     "HTTP/1.1 301 Moved Permanently\r\nLocation: https://...\r\n..."
        | Http.parse_response
        v
     status 301: again, with Url.resolve of the Location, at most
     [max_redirects] times (5; Firefox and Chrome stop at 20)

   https:// is the same request inside TLS, our own TLS 1.3
   (Tls_client.mli, Tls13.mli): the server's certificate checked with
   the system's roots, then the same bytes, encrypted. A URL of
   another scheme is refused.
   This one blocks: the program waits, doing nothing else, until the
   answer is in -- the simple version, fine for a file loaded once
   (Download.mli). (ix: the playground's Http_request, the same request
   that doesn't block, is not here yet.)

   Where it stands: the top of the network's libraries, and the one
   function most programs want of them. mini-curl is [once] and
   [prepare] with flags around; mini-lynx and mini-netscape's tabs
   call [fetch] for a page, its style sheets, scripts and pictures,
   one after the other. Under it, by layers, each knowing only the
   one below:

       Url, Http          text: what to ask, what came back
       Tls_client, Tls13  https:// only: the same bytes, encrypted
       Tcp, Dns           a name to an address, a stream of bytes
       the kernel         segments, retransmissions, the network card

   others:
   A redirection followed blindly is a way to be sent anywhere, so
   every client counts them. And which method the second request
   uses is history's accident: after a POST answered 301 or 302 the
   browsers of the 1990s asked again with a GET, against the
   specification, which then gave in and added 307 and 308 for "the
   same method again". Here every redirection is followed with a
   GET, 307 and 308 included: simpler, and wrong for those two.

   cs-history:
   What this stands in for is curl, which the author's playground ran
   as a program for its https:// until it had a TLS of its own. Daniel
   Stenberg began it in 1996 to fetch currency rates for an IRC bot
   (httpget, then urlget; "curl" in 1998); its library is now in
   nearly every phone, car and television, the most widely installed
   HTTP client there is, and what "getting a URL" means when a program
   that is not a browser does it. mini-curl (Curl) is a small one made
   of this module. *)

val max_redirects : int

(* the final response (whatever its status, 404 included: the caller
 * decides), or why there is none: a URL we can't get, a network error,
 * a response that doesn't parse, too many redirections *)
val get : < Cap.network; Cap.open_in; .. > -> string -> (Http.response, string) result

(* the same, and the URL the redirections led to; with [post] (its
 * content type and body), the first request a POST *)
val fetch : < Cap.network; Cap.open_in; .. > -> post:(string * string) option -> string -> (string * Http.response, string) result

(* one request, no redirection followed (mini-curl without -L) *)
val once : < Cap.network; Cap.open_in; .. > -> post:(string * string) option -> Url.t -> (Http.response, string) result

(* what to connect to and what to send for [url]: the host for the
 * resolver, the port, the request's bytes (a GET; a POST of [post], its
 * content type and body); Error for a URL that isn't http:// or
 * https:// (the message says why) *)
val prepare : post:(string * string) option -> Url.t -> (string * int * string, string) result

(* the same with what a request says and does besides: [said], more
 * headers (a script's own, a page's cookies); [keep], an https://
 * connection kept open for the next request to its host (Keep_alive)
 * -- a browser's way, a page being a hundred requests to three hosts;
 * [jar]: each request says the cookies kept for its URL, and each
 * answer's Set-Cookie is kept, a redirection's before the next request
 * is made *)
type options = { said : Http.header list; keep : bool; jar : Cookie_jar.t option }

(* nothing more said, the connection closed after each answer, no jar *)
val defaults : options

val fetch_with : options -> < Cap.network; Cap.open_in; .. > -> post:(string * string) option -> string -> (string * Http.response, string) result
val once_with : options -> < Cap.network; Cap.open_in; .. > -> post:(string * string) option -> Url.t -> (Http.response, string) result
val prepare_with : options -> post:(string * string) option -> Url.t -> (string * int * string, string) result
