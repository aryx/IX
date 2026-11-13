(* Cookie: what a server asks a browser to remember, and to say back.

   HTTP forgets: each request is answered on its own, and the server
   cannot tell that two of them came from the same person. Lou
   Montulli's cookies (Netscape, 1994, for a shopping cart) are the
   memory, and the browser keeps it. A response says "Set-Cookie: name=
   value", and every later request to that site says "Cookie: name=
   value" back. It is how a site knows who is signed in: the value is a
   number that names the session, which only the server understands.

   cs-history:
   The name is a programmer's: a "magic cookie" was Unix's word for a
   token that a program is handed and gives back without looking
   inside. Montulli wrote them in June 1994, for a customer's shopping
   cart (MCI's) that Netscape did not want to keep on its own servers.
   They shipped in the first Navigator that autumn, on by default and
   unannounced. The press found them in 1996, and with them what they
   had become. A picture on a page comes from another site, which can
   set its own cookie, and so recognize one reader across every page
   that carries its pictures. This is the "third-party" cookie, on
   which advertising on the web was then built. The IETF's first
   standards (RFC 2109, 1997, David Kristol and Montulli; RFC 2965,
   2000) tried to forbid that and to redesign the header; browsers
   implemented neither. RFC 6265 (2011) gave up prescribing and wrote
   down what browsers do, which is what is here.

     GET /login HTTP/1.1                 (the form posted)
                                HTTP/1.1 302 Found
                                Location: /inbox
                                Set-Cookie: SID=31d4d96e407aad42; Path=/; Secure; HttpOnly
                                Set-Cookie: lang=en-US; Path=/; Domain=example.com
     GET /inbox HTTP/1.1
     Cookie: SID=31d4d96e407aad42; lang=en-US

   (This is RFC 6265's own example, section 3.1.) After the name and
   the value come the **attributes**, which say where the cookie goes
   back, and until when:

     Domain=example.com  to that host and those under it
                         (www.example.com); without it, to the one host
                         that set it and no other (a "host-only" cookie)
     Path=/docs          to the paths under it (/docs, /docs/web, not
                         /docsweb); without it, to the directory of the
                         page that set it
     Expires=Wed, 09 Jun 2021 10:18:14 GMT
     Max-Age=3600        until then, or for so many seconds (Max-Age
                         wins); without either, until the browser is
                         closed (a session's cookie). A date in the
                         past is how a server deletes one.
     Secure              over https:// only
     HttpOnly            not shown to the page's scripts
                         (document.cookie), so a stolen script cannot
                         take the session with it

   A browser keeps the cookies in a **jar** ([jar], a value, which is
   the list). A new cookie replaces the one with the same name, domain
   and path. For a request, the cookies whose domain and path match its
   URL are sent, the longest paths first.

   What a server may not do is set a cookie for someone else. A Domain
   that the answering host is not under is refused, and so is one with
   no dot ("com"), which every site would share. (A browser has the
   Public Suffix List for that, with "co.uk" and thousands more; it is
   not here.)

   Not done: the Public Suffix List; SameSite (here a cookie is sent
   with every request to its site, whoever asks, a picture on another
   site's page too); the __Host- and __Secure- prefixes; partitioning.

   modern:
   Since then, browsers took on the third party themselves. SameSite
   (2016; the default in Chrome since 2020) keeps a cookie from going
   with a request that another site caused. Safari and Firefox keep a
   separate jar for each site that a third party is seen from
   ("partitioning"). And the Public Suffix List says which domains
   (co.uk, github.io) are shared by strangers.

   Reference: Adam Barth, RFC 6265, "HTTP State Management Mechanism"
   (2011), sections 4.1 (Set-Cookie), 5.1 (dates, domains, paths), 5.3
   (storing), 5.4 (the Cookie header); Netscape's "Persistent Client
   State: HTTP Cookies" (1994). *)

type cookie = {
  name : string;
  value : string;
  domain : string; (* lowercase, with no dot before it *)
  host_only : bool; (* no Domain was said: for that host alone *)
  path : string;
  expires : float option; (* seconds since 1970; None for a session's cookie *)
  secure : bool;
  http_only : bool;
  created : float;
}

(* the cookies kept, the newest first *)
type jar = cookie list

(* the date of an Expires, as seconds since 1970. It reads "Wed, 09 Jun
 * 2021 10:18:14 GMT", and what servers write instead (RFC 6265 section
 * 5.1.1: a time, a day, a month's name and a year, in any order). *)
val date : string -> float option

(* [parse ~now url value] is the cookie that a "Set-Cookie: [value]" in
 * the answer to [url] asks for. It is None if the cookie is refused (no
 * name, a Domain that is not the host of [url], Secure over
 * http://). *)
val parse : now:float -> Url.t -> string -> cookie option

(* the jar after that Set-Cookie. The cookie is kept, in the place of
 * the one with its name, domain and path; if the new one is already
 * past its date, that old one is only removed. [script] says that
 * the page's script set it, and a script may neither set an
 * HttpOnly cookie nor replace one. *)
val store : now:float -> script:bool -> Url.t -> string -> jar -> jar

(* the cookies that a request to [url] sends: those of its domain and
 * its path that are not past their date, with the Secure ones over
 * https:// only, and without the HttpOnly ones for [script].
 * The longest paths come first, then the oldest cookies. *)
val for_url : now:float -> script:bool -> Url.t -> jar -> cookie list

(* the value of the Cookie header for [url], such as
 * "SID=31d4d96e407aad42; lang=en-US"; None if there is none to send *)
val header : now:float -> script:bool -> Url.t -> jar -> string option

(* the jar without what is past its date *)
val alive : now:float -> jar -> jar
