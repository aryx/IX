(* Url: the address of a thing on the network, and the relative ones.

   A URL (Tim Berners-Lee, 1994; the grammar as it stands is RFC 3986,
   2005, which calls them URIs) has five parts. Each is optional except
   the path, which may be empty:

       http://elm-lang.org:80/images/turtle.gif?size=96#top
       \__/   \_____________/\_________________/ \_____/ \_/
      scheme     authority          path          query  fragment
                 = host:port

   The scheme says which protocol to speak ("http": Http.mli). The
   authority says whom to speak it to: a name for DNS, or an address,
   and a port, or else the scheme's default port (80 for http, 443 for
   https). The path and the query say what to ask them for. The
   fragment is never sent: it is for the client, and names a place in
   the page.

   Splitting a string into the five parts is easy, because the RFC
   chose the separators so that it is: its appendix B even gives the
   regular expression that does it, for any URL, valid or not,

       {|^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?|}
             scheme        authority    path      query     fragment

   and [parse] is that regexp written out by hand: the scheme up to a
   ':' that comes before any of "/?#", the authority after "//" up to
   the next of "/?#", the path up to "?" or "#", and so on. (The tests
   check that the two agree, running the regexp with OCaml's Str.)

   The subtle part is the *relative* reference. A web page says
   <img src="../images/turtle.gif">, and a server answering "moved"
   says "Location: /new/place" (Http.mli). Both mean a URL relative to
   the one they came from, the *base*. [resolve] turns the pair into an
   absolute URL, with the algorithm of RFC 3986's section 5.2. A part
   present in the reference wins, and the parts before it come from the
   base. A relative path is *merged* with the base's path (the base's
   path up to its last '/', then the reference's), and then "." and
   ".." are removed as a file system would do (remove_dot_segments):

       base      http://a/b/c/d;p?q
       reference ../g
       merged    /b/c/../g        (the base's path up to "c/", then "../g")
       result    http://a/b/g     (".." removed "c/")

   The tests check worked examples: all of RFC 3986's own examples in
   its section 5.4, which are 23 normal ones and 19 abnormal ones from
   the same base. For example, "g" gives http://a/b/c/g, "//g" gives
   http://g, "?y" gives http://a/b/c/d;p?y, "../../../g" gives
   http://a/g (a ".." above the root stays at the root), and "g?y/../x"
   gives http://a/b/c/g?y/../x (dots in a query are not segments). The
   tests also check the two traces of remove_dot_segments in section
   5.2.4: "/a/b/c/./../../g" gives "/a/g" and "mid/content=5/../6"
   gives "mid/6".

   Where it stands: it is used by every program of ix that follows a
   link. Http_client parses what it is given and resolves each
   "Location:". The browsers resolve every href and src of a page
   against the page's own URL (the engine's Browser_url). mini-httpd
   uses [remove_dot_segments] the other way, to see what file a
   request's path names. On the file system's side, the same idea is a
   path cleaned as text: Plan 9's cleanname, and the kernel's dot-dot
   (mini-pwd, in Pwd, says why it is done on the name there too).

   cs-history:
   The web's three inventions were HTML, HTTP and this one, and Tim
   Berners-Lee has said this is the one that mattered: one string that
   names anything any protocol can fetch -- a file on an FTP server, a
   newsgroup, a Gopher menu, and a page of the web among them -- so
   that a link could point at what already existed. He wrote it down
   as "Universal Resource Identifiers" (RFC 1630, 1994); the IETF,
   wary of "universal", made it "Uniform Resource Locators" (RFC 1738,
   1994). The "//" after the scheme came from the Apollo Domain file
   system's network paths; he has since said the two slashes were not
   needed.

   terminology:
   URL, URI, URN. A URI (Identifier) is the general thing, any such
   string. A URL (Locator) is a URI that says where to get the thing
   and how ("https://..."). A URN (Name) is one that only names it, for
   ever, wherever it is ("urn:isbn:0262510871"). RFC 3986 speaks of
   URIs; browsers and the WHATWG's URL Standard say URL for all of
   them, as everybody does.

   others:
   Two specifications, and they disagree. RFC 3986 is a grammar: a
   string is a URI or it is not. The WHATWG's URL Standard (the
   browsers', since 2012 or so) is an algorithm that takes whatever
   was typed or found in a page and repairs it: backslashes become
   slashes, spaces are escaped, a missing slash is added, tabs and
   newlines inside are dropped. Here it is the RFC's, which is short
   and has its own test cases; a browser for today's pages ends up
   needing the other's leniency.

   Not done: percent-encoding ("%20" for a space) is kept as it is,
   neither decoded nor checked; a URL is sent as it was written, which
   is what an HTTP client needs. There is also no normalization (the
   case of the percent escapes, the default ports removed: section 6).

   Reference: RFC 3986, "Uniform Resource Identifier (URI): Generic
   Syntax", Tim Berners-Lee, Roy Fielding and Larry Masinter (2005),
   sections 3 (the parts), 5 (resolving) and appendix B (the regexp);
   RFC 1738 (1994), the first URL specification. *)

(* userinfo@host:port. The host is as written, lowercased if it is a
 * name ("elm-lang.org", "127.0.0.1", "[::1]"); the port is as written,
 * if there is one. *)
type authority = { userinfo : string option; host : string; port : int option }

(* a URL, or a reference relative to one (which then has no scheme, and
 * maybe no authority), with the five parts of the diagram above. An
 * absent part (None) is not the same as an empty part (Some ""): "?"
 * has an empty query, and resolves differently from "" (section
 * 5.2.2). *)
type t = {
  scheme : string option; (* lowercased: "http" *)
  authority : authority option;
  path : string; (* "/images/turtle.gif", "../g", or "" *)
  query : string option; (* without its '?' *)
  fragment : string option; (* without its '#' *)
}

(* the five parts of a string, as appendix B's regexp finds them. It is
 * Error only for an authority's port that is not a number. *)
val parse : string -> (t, string) result

(* back to a string, as in section 5.3. to_string (parse s) = s, except
 * for the case of the scheme and the host, and an empty port that is
 * dropped. *)
val to_string : t -> string

(* [resolve base reference] is the absolute URL that [reference] means,
 * seen from [base] (which must have a scheme), as in section 5.2.2.
 * It is strict: "http:g" is not relative, even with the base's
 * scheme. *)
val resolve : t -> t -> t

(* removes the "." and ".." segments from a path (section 5.2.4) *)
val remove_dot_segments : string -> string

(* the port to connect to: the one written, or else the scheme's (80
 * for http, 443 for https); None if there is neither *)
val port : t -> int option

(* what an HTTP request asks for (the target of its request line): the
 * path and the query, with "/" for an empty path, and no fragment
 * (it is never sent) *)
val request_target : t -> string
