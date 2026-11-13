(* HTTP, or the part of it that www and the wire's other end speak: a
 * request for a page, and its answer, a head followed by the page's
 * bytes.
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
 * The request is the kind sent to a proxy: the whole address is on its
 * line, not only the path, since the other end fetches the page for
 * us. The answer is in HTTP/1.0's style: the page ends where the
 * connection ends. Its bytes are the page itself, with the site's
 * chunks and gzip already undone, so the head mentions neither; the
 * site's other headers are passed on. Content-Type says what the bytes
 * are. HTML is read, plain text is shown as it is, and what www cannot
 * show itself is given to a program that can (a WAV file to play), as
 * Mosaic did.
 *
 * dropped:
 * Every method but GET, the other request headers (cookies, ranges,
 * caching), keeping a connection open for the next request, and
 * continuation lines in a head.
 *
 * cs-history:
 * HTTP/0.9 (Tim Berners-Lee, 1991) was a line "GET /path" answered by
 * the page, with no head: the same shape as Gopher, which this wire
 * spoke before. HTTP/1.0 (RFC 1945, 1996, describing what NCSA's and
 * CERN's servers had done since 1993) added the status line and the
 * headers, taken from MIME in mail, Content-Type among them. CERN's
 * httpd was also the first proxy (1994), and it was asked with the
 * whole address on the request line, as here.
 *)

val request : Url.url -> string

(* the address a request asks for, if it is a GET *)
val asked : string -> Url.url option

(* [response status headers body] adds the Content-Length *)
val response : int -> (string * string) list -> string -> string

(* where the body's first byte is in the start of a response, if the
 * head has ended *)
val head_end : string -> int option

val status : string -> int option

(* [header] is "" if the head has none; names are compared ignoring
 * case *)
val header : string -> string -> string

(* a head's Content-Type, without its parameters, in lowercase
 * ("text/html"); "" if it has none *)
val media_type : string -> string
