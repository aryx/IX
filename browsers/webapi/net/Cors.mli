(* Cors: who may read what -- the same-origin policy, and the header
   by which a site lets others in.

   **The problem.** A browser sends the user's cookies with every
   request to a site (mini-chrome's Cookie_jar; mini-netscape keeps
   no cookie yet, and so has the rule before it has the danger),
   whichever page asked. So a request
   made by a script of evil.example to bank.example arrives as the
   user's own, logged in. If that script could read the answer, any
   page one visits could read one's mail, one's account, one's
   company's intranet, and send it home.

   **The same-origin policy** is the rule that stops it: a script reads
   only what comes from its own *origin* -- the scheme, the host and
   the port of its page, all three ([origin]):

     the page is https://example.com/shop/cart

     https://example.com/api/items     the same origin
     https://example.com:443/x         the same (443 is https's port)
     http://example.com/               another: the scheme
     https://api.example.com/          another: the host
     https://example.com:8443/         another: the port

   It is not a rule about what is *sent*. A page may show another
   site's picture, run its script, post a form to it: those requests
   leave, cookies and all. It is a rule about what a *script* is given
   back: the picture's pixels, the answer's text.

   **CORS**, Cross-Origin Resource Sharing, is the exception the other
   site can grant. Sharing is often wanted: a weather service, a font,
   a public API are there to be read by other sites' pages. The answer
   says so in a header, and the browser, not the server, enforces it:

     Access-Control-Allow-Origin: *                     anyone's page
     Access-Control-Allow-Origin: https://example.com   that origin's

   An answer of another origin without one of these is not given to
   the script ([readable]): it is told the request failed, as if the
   network were down, and the console says why ([blocked]). The
   request was sent all the same and the server did what it was
   asked: CORS protects what is read, not what is done. (What is done
   -- a transfer ordered by another site's form -- is the other
   attack, cross-site request forgery, and is stopped by other means:
   a secret token in the form, SameSite cookies.)

   So the two are one mechanism seen from two sides: the same-origin
   policy is the default (no), CORS the way to say yes; the origin is
   what both compare.

   What a real browser adds, and is not here: the *preflight* -- before
   a request that a plain form could not have made (a PUT, a POST of
   JSON, a custom header), an OPTIONS request asking the server
   whether it may be sent at all, since for those even the sending
   could do harm to a server written before scripts could send them;
   and *credentials* -- for a request with cookies, "*" is not enough,
   the answer must name the origin and add
   Access-Control-Allow-Credentials: true.

   A URL with no host (about:, data:, file:) has the origin "null".
   A real browser makes each such page an origin of its own, equal to
   nothing; here the built-in site's pages (about:...) share it, so
   that they can read each other's files.

   cs-history:
   Netscape Navigator 2 had the policy within months of the first
   JavaScript (1995-96): a script of one frame could not read the document of
   another site's frame. It was extended to each thing scripts learnt
   to read -- XMLHttpRequest (1999-2005) above all -- and never
   written down as one rule until RFC 6454 (2011).

   cs-history:
   Ten years of going around it. A <script> element may come from any
   site, so a server wrapped its data in a call to a function of the
   page -- "JSONP" (Bob Ippolito, 2005) -- which gave that server the
   run of the page; or the page's own server relayed the request.
   CORS began as a way for VoiceXML documents to say which sites
   could read them (a W3C note, 2005), became a draft for the web in
   2006, was in Firefox 3.5 and Safari 4 in 2009, a W3C Recommendation
   in 2014, and lives today in the Fetch Standard.

   others:
   The policy's other doors: postMessage (2008), by which two windows
   of different origins pass messages they both agreed to; and what a
   page allows itself to load at all, which is the reverse question --
   Content Security Policy.

   References: RFC 6454, The Web Origin Concept (A. Barth, 2011); the
   Fetch Standard (fetch.spec.whatwg.org), section 3.2, "CORS
   protocol"; M. Zalewski, The Tangled Web (2011), chapter 9, on the
   policy and its holes. *)
(* ix: the author's mini-chrome's src/webapi/net/Cors.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* a URL's origin, "https://example.com", "http://localhost:8000": its
 * scheme, host and port, lowercased, the port left out when it is the
 * scheme's own (80, 443); "null" for a URL with no host *)
val origin : string -> string

val same_origin : string -> string -> bool

(* [readable ~page ~url headers]: whether a script of [page] may read
 * the answer that came from [url] with those headers: the same origin,
 * or an Access-Control-Allow-Origin that is "*" or the page's origin *)
val readable : page:string -> url:string -> (string * string) list -> bool

(* what the console says of an answer that is not *)
val blocked : page:string -> url:string -> string

(* a header's value, whatever its name's case *)
val header : (string * string) list -> string -> string option
