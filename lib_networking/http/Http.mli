(* Http: the web's protocol, a request and its answer, as text.

   HTTP (Tim Berners-Lee, 1991; HTTP/1.1 since 1997, today RFC 9110 for
   the meaning and RFC 9112 for the bytes) is the simplest protocol in
   daily use, and the model of the ones after it. A client connects (a
   TCP connection, Tcp.mli) and sends a *request*, which is lines of
   text ending in an empty line. It then reads the *response*: a status
   line, header lines, an empty line, and the body, which holds the
   bytes of the file.

     client -> server                     server -> client
     GET /images/turtle.gif HTTP/1.1      HTTP/1.1 200 OK
     Host: elm-lang.org                   Content-Type: image/gif
     User-Agent: elm_playground           Content-Length: 1523
     Accept-Encoding: gzip                Connection: close
     Connection: close                    (empty line)
     (empty line)                         GIF89a... (1523 bytes)

   Every line ends with CR LF ("\r\n", the network's line end since
   Telnet; a lone LF is accepted when reading, as RFC 9112 section 2.2
   allows). A header is a name, a ':', and a value; names are
   case-insensitive ("content-length" is "Content-Length"). "Host:" is
   the one mandatory header of HTTP/1.1, because one address may serve
   many sites. "Connection: close" asks the server to close the
   connection after answering, so we can read until the end and parse
   everything at once: [parse_response] is a pure function of the bytes
   received.

   The one subtle part is the question that every protocol on a byte
   stream must answer: **where does the message end?** The headers end
   at the empty line. For the body, the answers of HTTP/1.1 are tried in
   this order (RFC 9112 section 6.3; [body] follows that list):

   1. there is no body at all, whatever the headers say, for the
      statuses that cannot have one (1xx, 204 No Content, 304 Not
      Modified);
   2. with "Transfer-Encoding: chunked", the body comes in pieces, each
      preceded by its size in hexadecimal, and a piece of size 0 ends
      it. This is for a server that does not know the size when it
      starts (a page generated as it is sent);
   3. with "Content-Length: n", the body is exactly n bytes;
   4. with neither, the body is everything until the server closes the
      connection. This was the only way in HTTP/1.0; a truncated file
      then cannot be told from a whole one, which is why 1.1 added the
      other two.

   Here is a worked example of chunks (the classic one from Wikipedia's
   article, checked by the tests):

       4\r\n              a chunk of 4 bytes
       Wiki\r\n
       5\r\n              a chunk of 5 bytes
       pedia\r\n
       E\r\n              14 bytes (hex E): the CR LFs inside are data
        in\r\n\r\nchunks.\r\n
       0\r\n              the last chunk, which is empty
       \r\n               (no trailer headers)

   It is the body "Wikipedia in\r\n\r\nchunks.". A chunk size may be
   followed by ";name=value" extensions, which are ignored.

   The status says what happened: 2xx means it worked, 3xx means look
   elsewhere (the new place is in "Location:", maybe relative to the
   old one: Url.resolve), 4xx means the client asked wrong (404 Not
   Found), and 5xx means the server failed. Following redirections is
   the client's job (Http_client.mli), not this module's.

   Compression: we say "Accept-Encoding: gzip", and a body that comes
   with "Content-Encoding: gzip" is uncompressed once its framing is
   undone (with Zlib.gunzip of lib_compression). A page of text is a
   fourth or a fifth of its size on the wire. Any other coding is
   refused.

   Keep-alive means several requests on one connection; it is the
   reason for the body framings of 1.1, because each message must end
   without the connection ending. It is done in Keep_alive; here,
   [extent] and [whole] say where a response ends from its bytes so
   far.

   Not done: Brotli and Zstandard, the codings after gzip; caching;
   HTTP/2 (2015: the same messages as binary frames, with many requests
   at once on one connection) and HTTP/3 (2022: the same over QUIC,
   over UDP). These are what the web moved to, for speed, and they keep
   this module's meaning.

   Where it stands: this is a pure module, from bytes to values and
   back, with no socket in it. The client's half is used by Http_client
   (and through it by mini-curl, mini-lynx and the tabs of
   mini-netscape). The server's half, further down, is used by
   mini-httpd, which reads and writes this module's two messages the
   other way round. The bytes travel by Tcp, or by Tls_client for
   https://, and HTTP does not know which.

   cs-history:
   How it grew. The first HTTP (1991) was one line, "GET /page"; the
   answer was the page's HTML, and then the connection closed. There
   was no version, no headers, and no other kind of file. It is a text
   protocol in the manner of the Internet's older ones (SMTP, FTP,
   NNTP): one can speak it by hand through a telnet, which is how it was
   debugged and how it spread. HTTP/1.0 (RFC 1945, 1996, written down
   after the fact from what Mosaic and the servers did) added the
   version, the status line and the headers. The headers were taken
   from mail, MIME's Content-Type among them, which is why the kind of
   a page is said the way the kind of an attachment is. HTTP/1.1 (RFC
   2068, January 1997; Roy Fielding, Jim Gettys, Jeffrey Mogul, Henrik
   Frystyk, Tim Berners-Lee) is the one still spoken. It added Host, so
   that one address serves many sites; connections kept open; chunks;
   and caching said precisely. Fielding's thesis (2000) then named the
   style that the protocol had been designed to follow: REST.

   design:
   A protocol without state. Each request says everything the server
   needs to answer it, and the server remembers nothing of the client
   between two requests. So a server can be restarted, or be ten
   machines behind one name, and a request can be repeated or cached
   by a machine in between. What needs memory (who is signed in, a
   basket) was put on top, in a header that the client sends back each
   time (the cookie, Netscape, 1994): the client carries the state.

   Reference: Roy Fielding, "Architectural Styles and the Design of
   Network-based Software Architectures" (thesis, Irvine, 2000),
   chapter 5: REST, and why HTTP is as it is; RFC 1945, "HTTP/1.0"
   (Berners-Lee, Fielding and Frystyk, 1996); RFC 9110 "HTTP
   Semantics" and RFC 9112 "HTTP/1.1", Roy
   Fielding, Mark Nottingham and Julian Reschke (2022), which replaced
   RFC 2616 (1999) and RFC 2068 (1997); Tim Berners-Lee, "The Original
   HTTP as defined in 1991" (HTTP/0.9: "GET /path", and the file, no
   headers at all). *)

(* a header's name and value, the value without its surrounding spaces *)
type header = string * string

(* the value of the first header with this name (case-insensitive) *)
val header : string -> header list -> string option

(* every header of that name: a response says Set-Cookie once for each
 * cookie *)
val values : string -> header list -> string list

(*****************************************************************************)
(* The request *)
(*****************************************************************************)

type request = {
  meth : string; (* "GET" *)
  target : string; (* "/images/turtle.gif", from Url.request_target *)
  headers : header list;
}

(* a GET of [target] from [host] ("elm-lang.org", or "localhost:8001"
 * for a port that is not the default), with the headers shown above:
 * Host, User-Agent, Accept-Encoding, Connection: close *)
val get : host:string -> string -> request

(* the request with these headers added (its cookies, a script's own
 * headers), before Connection *)
val saying : header list -> request -> request

(* the request asking that the connection stay open after the answer:
 * it says "Connection: keep-alive" where it said close (for
 * Keep_alive) *)
val keeping : request -> request

(* a POST of [body] to [target]. It has the headers of get, plus the
 * body's Content-Type and Content-Length (for a form's fields, see
 * Urlencoded) *)
val post : host:string -> content_type:string -> body:string -> string -> request

(* the bytes to send: the request line, the headers, the empty line,
 * and the body if there is one (a POST's) *)
val request_to_string : body:string -> request -> string

(*****************************************************************************)
(* The response *)
(*****************************************************************************)

type response = {
  version : string; (* "HTTP/1.1" *)
  status : int; (* 200 *)
  reason : string; (* "OK", for people only *)
  headers : header list;
  body : string;
}

(* "HTTP/1.1 200 OK" -> ("HTTP/1.1", 200, "OK") *)
val parse_status_line : string -> (string * int * string, string) result

(* the body of a chunked transfer: the data of the chunks joined, from
 * the start of [s] (Error if [s] ends before the last chunk) *)
val dechunk : string -> (string, string) result

(* the body, from what follows the empty line, by the rules 1 to 4
 * above, for this status and these headers *)
val body : status:int -> header list -> string -> (string, string) result

(* everything the server sent until it closed the connection (or up
 * to the end of its response), parsed; a gzip body is uncompressed *)
val parse_response : string -> (response, string) result

(* where a response ends, as read in its head. It ends at so many bytes
 * from its start (with a Content-Length, or with no body at all),
 * after its last chunk (the body starting at that byte), or when the
 * connection closes. *)
type extent = Bytes of int | Chunks of int | To_the_end

(* [extent s] is the extent of the response that [s] starts with, and
 * whether the server will keep the connection open after it. It is
 * None while the response's head is not whole. *)
val extent : string -> (extent * bool) option

(* is the response of that extent all in [s]? *)
val whole : string -> extent -> bool

(* 301, 302, 303, 307, 308: the answer is elsewhere, in "Location:" *)
val is_redirect : int -> bool

(*****************************************************************************)
(* The server's side *)
(*****************************************************************************)

(* A server reads the other message: a request line ("GET /x
 * HTTP/1.1"), headers, the empty line, and a body when the request
 * says how long it is ("Content-Length: n", for a form that is POSTed,
 * phase 9 of plan_browser_teaching.md). The bytes come in pieces, so
 * reading a request also says whether it is whole yet:
 *
 *   "GET / HTTP/1.1\r\nHost: a\r\n"          Incomplete: no empty line yet
 *   "GET / HTTP/1.1\r\nHost: a\r\n\r\n"      Request, its body "", 27 bytes used
 *   "POST /f HTTP/1.1\r\nContent-Length: 3\r\n\r\nab"
 *                                            Incomplete: 1 byte of body to come
 *   "HELLO\r\n\r\n"                          Bad: not a request line *)
type parsed_request =
  | Incomplete
  | Bad of string
  | Request of request * string * int (* the request, its body, the bytes used *)

val parse_request : string -> parsed_request

(* the reason phrase of a status, for the people reading the bytes:
 * 200 is "OK", 404 is "Not Found" *)
val reason : int -> string

(* a response of [status], whose body has type [content_type] *)
val response : int -> content_type:string -> string -> response

(* the bytes to send: the status line, the headers (with a
 * Content-Length added if there is none, and "Connection: close"),
 * the empty line, and the body. This is what parse_response reads
 * back. *)
val response_to_string : response -> string
