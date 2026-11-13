(* Urlencoded: a form's fields as one string. This is what a browser
   sends when a form is submitted, in the URL (GET) or as the body
   (POST), and what the server's program reads back.

     q = "café au lait", lang = "fr"
       -> q=caf%C3%A9+au+lait&lang=fr

   The fields come in order, each as name=value, joined by '&'. In a
   name or a value, the letters, the digits and "*-._" stay as they
   are, a space becomes '+', and every other byte becomes '%' and its
   two hexadecimal digits, in upper case. So "é" is its two UTF-8
   bytes, %C3%A9, and a '&' or a '=' in a value is %26 or %3D, so that
   those two characters only ever separate. It is the format of
   Mosaic's forms (1993) and of every form since. Its name is the
   Content-Type that a POST says: application/x-www-form-urlencoded.

   GET or POST is the page's choice (<form method=post>). With GET, the
   fields are the URL's query ("/search?q=caf%C3%A9+au+lait&lang=fr"),
   so they can be bookmarked, and they end up in the server's log. With
   POST, they are the request's body; this is for what should not be
   bookmarked (a password), or for what is not a question but an
   action (an order).

   [decode] goes the other way, and is lenient as servers are: a '+' is
   a space, a '%' not followed by two hexadecimal digits stands for
   itself, and a field with no '=' has the value "".

   Where it stands: it is used by the browser's forms (the engine's
   Browser_forms encodes what was typed, for the query or for the body
   of Http.post) and by a page's scripts (URLSearchParams in the web
   API's Script_url). mini-httpd answers GET only and has no use for
   [decode]; a server with a program behind a URL would start there.

   cs-history:
   Forms are what made the web more than pages to read. Dave Raggett
   proposed them in HTML+ (1993); Mosaic 2.0 (November 1993) drew
   them; and NCSA's server (Rob McCool) ran a program for the request
   and sent back what it printed. That was CGI, the Common Gateway
   Interface, and its input was this module's string. A search box, a
   guest book, a shop: every "web application" until XMLHttpRequest
   (1999) was a form sent, a program run, and a new page. The '%' and
   two hexadecimal digits is the URL's own escape (RFC 1738). The '+'
   for a space is older than that rule and belongs to forms alone,
   which is why a '+' in a path is a plus, and in a query a space.

   Reference: WHATWG URL Standard, section 5 ("application/x-www-form-
   urlencoded"); HTML 2.0 (RFC 1866), section 8.2.1, the form's
   submission. *)

(* the fields, encoded and joined: the query or the body *)
val encode : (string * string) list -> string

(* the fields of a query or a body, decoded *)
val decode : string -> (string * string) list

(* one name or value, encoded (a space as '+') *)
val escape : string -> string

(* one name or value, decoded *)
val unescape : string -> string
