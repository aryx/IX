(* Cookie_jar: the browser's cookies, kept while it runs -- Cookie's jar
   (a value) in a box that the requests share.

   A request reads the jar (the Cookie header it sends) and its answer
   writes it (each Set-Cookie), and so does each hop of a redirection:
   "POST /login, 302, Set-Cookie, GET /inbox with the cookie" is one
   fetch, three uses of the jar. (No lock: there are no threads here.)

     the page's request ----> [header]   Cookie: SID=31d4...
     its answer        ----> [received] Set-Cookie: SID=...; lang=...
     the page's script ----> [script_cookies], [set_from_script]
                              (document.cookie: not the HttpOnly ones)

   The time is the clock's (Unix.gettimeofday): a cookie past its date
   is not sent. [changes] counts what was written, for who saves the
   jar to know when to (Browser_cookies). *)

type t

(* a jar holding [cookies] *)
val create : Cookie.jar -> t

(* what it holds now, without what is past its date *)
val cookies : t -> Cookie.jar

(* the Cookie header's value for a request to that URL, if any *)
val header : t -> Url.t -> string option

(* the answer to a request to that URL: each of its Set-Cookie headers
 * kept *)
val received : t -> Url.t -> Http.header list -> unit

(* document.cookie, read ("a=1; b=2", "" if none) and assigned to (one
 * Set-Cookie's value), for the page at that URL *)
val script_cookies : t -> Url.t -> string

val set_from_script : t -> Url.t -> string -> unit

(* how many times it was written *)
val changes : t -> int

(* all forgotten *)
val clear : t -> unit
