(* Cookie_jar: the browser's cookies, kept while it runs. It puts
   Cookie's jar (a value) in a box that the requests share.

   A request reads the jar (for the Cookie header it sends) and its
   answer writes it (each Set-Cookie), and so does each hop of a
   redirection. "POST /login, 302, Set-Cookie, GET /inbox with the
   cookie" is one fetch, and three uses of the jar. (There is no lock,
   because there are no threads here.)

     the page's request ----> [header]   Cookie: SID=31d4...
     its answer        ----> [received] Set-Cookie: SID=...; lang=...
     the page's script ----> [script_cookies], [set_from_script]
                              (document.cookie: not the HttpOnly ones)

   The time is what the [now] given to [create] returns, and a cookie
   past its date is not sent. [changes] counts what was written, so
   that the code that saves the jar knows when to do it (Netscape's,
   through Browser_profile.save_cookies). *)

type t

(* a jar holding [cookies], whose dates are compared with [now] (the
 * clock, given by the holder of Cap.clock: CapUnix.gettimeofday caps) *)
val create : now:(unit -> float) -> Cookie.jar -> t

(* what it holds now, without what is past its date *)
val cookies : t -> Cookie.jar

(* the value of the Cookie header for a request to that URL, if any *)
val header : t -> Url.t -> string option

(* takes the answer to a request to that URL, and keeps each of its
 * Set-Cookie headers *)
val received : t -> Url.t -> Http.header list -> unit

(* document.cookie, for the page at that URL: script_cookies reads it
 * ("a=1; b=2", or "" if there are none), and set_from_script assigns
 * to it (the value of one Set-Cookie) *)
val script_cookies : t -> Url.t -> string

val set_from_script : t -> Url.t -> string -> unit

(* how many times it was written *)
val changes : t -> int

(* forgets everything *)
val clear : t -> unit
