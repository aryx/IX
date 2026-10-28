(* HTTP, the part of it www and the wire's other end speak: a request
 * for a page, and its answer, a head then the page's bytes.
 *
 *     www                                    the wire's other end
 *      | GET https://en.wikipedia.org/wiki/OCaml HTTP/1.0
 *      | User-Agent: www
 *      | (an empty line)            ------>  fetches it (TLS, gzip,
 *      |                                     chunks: tiny-machine-fetch)
 *      |                            <------  HTTP/1.0 200 OK
 *      |                                     Content-Type: text/html; ...
 *      |                                     Content-Length: 104277
 *      |                                     (an empty line)
 *      | read as HTML, or kept in a file      the page's bytes, then the
 *      | for a helper (TinyBrowser)           connection closed
 *
 * The request is a proxy's: the whole address on its line, not only
 * its path, since the other end fetches it for us. The answer is
 * HTTP/1.0's: the page ends where the connection does, and its bytes
 * are the page's own, the site's chunks and gzip undone, so a head
 * says neither; the site's other headers are passed on. Its
 * Content-Type says what the bytes are: HTML is read, a text shown as
 * it is, and what www does not show itself is given to a program
 * that does (a WAV file to play), as Mosaic did.
 *
 * What is dropped: every method but GET, a request's other headers
 * (cookies, a range, a cache's), keeping a connection for the next
 * request, and a head's continued lines.
 *
 * cs-history:
 * HTTP/0.9 (Tim Berners-Lee, 1991) was a line "GET /path" and the
 * page, no head: Gopher's shape, which this wire spoke before. HTTP/1.0
 * (RFC 1945, 1996, what NCSA's and CERN's servers did from 1993) added
 * the status line and the headers, MIME's from mail, Content-Type among
 * them; CERN's httpd was also the first proxy (1994), asked by a
 * request with the whole address on its line, as here.
 *)

(* [request url]: www's request for [url], to the wire's other end *)
val request : string -> string

(* the address a request asks for, if it is a GET *)
val asked : string -> string option

(* [response status headers body]: an answer, with its Content-Length *)
val response : int -> (string * string) list -> string -> string

(* where the head of a response that begins [s] ends (the body's first
 * byte), -1 if it has not yet *)
val head_end : string -> int

(* a head's status (200), 0 if its first line is not HTTP's *)
val status : string -> int

(* [header head name]: the header's value, "" if it has none; a name
 * is the same in any case *)
val header : string -> string -> string

(* a head's Content-Type, without its parameters, in lowercase
 * ("text/html"); "" if it has none *)
val media_type : string -> string
