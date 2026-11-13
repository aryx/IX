(* Script_url: URLSearchParams, the object through which a script reads
   and writes a query's fields.

   A URL's query is a form's fields in one string (Urlencoded.mli:
   "q=caf%C3%A9+au+lait&lang=fr"). Scripts took it apart by hand for
   twenty years, with split("&") and a decodeURIComponent that does not
   know a '+' is a space. URLSearchParams (the URL Standard, in
   Firefox from 2014, Chrome 2016, Safari 2017) is the same list as
   an object:

     const p = new URLSearchParams("q=caf%C3%A9+au+lait&lang=fr")
     p.get("q")                 // "café au lait"
     p.set("lang", "en"); p.append("page", 2)
     p.toString()               // "q=caf%C3%A9+au+lait&lang=en&page=2"
     new URLSearchParams({ a: 1, b: "x y" }).toString()   // "a=1&b=x+y"

   It is a list, not a table: a name may come several times (append
   adds one, set replaces them all by one, getAll gives them), in the
   order written. It can be made from a string (with or without its
   "?"), from an object's properties, from pairs, or from another
   URLSearchParams, and for-of goes through it as pairs. Given to fetch
   as a body, it is sent as its string, but as text/plain unless the
   script gives a Content-Type.

   The other half of the standard, the URL object itself (new URL(href,
   base) and its parts), is Script_host's url_object, which is older
   here.

   Reference: WHATWG URL Standard, section 6.2 (URLSearchParams) and 5
   (application/x-www-form-urlencoded). *)
(* ix: copied from src/webapi/window/Script_url.mli in the author's
 * mini-chrome (its 8af888e) (docs/plans/plan_browser.md) *)

open Js_value
open Script_types

(* defines URLSearchParams *)
val install : t -> (string -> value -> unit) -> unit
