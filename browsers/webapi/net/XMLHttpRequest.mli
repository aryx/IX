(* XMLHttpRequest: a script asking its server, the first way -- "XHR",
   the object the web's applications were built on.

   cs-history:
   Where it came from. Until 1999 a page got something new from its
   server in one way: by being replaced. A link, a form: a whole new
   page. (The tricks around that -- a hidden frame reloaded, an image's
   address used as a message -- say how much it was wanted.) The team
   of Outlook Web Access, Exchange's mail in a browser, needed mail to
   arrive in a page that stayed; Alex Hopmann wrote for them a small
   component that made an HTTP request from a script, and to ship it
   in time with Internet Explorer 5 (March 1999) it went into the one
   library on its way out of the door, Microsoft's XML parser, as
   "XMLHTTP" -- hence the XML of the name, which was never needed: what
   goes through is any text. Mozilla made the same thing a native
   object, XMLHttpRequest (2000 to 2002); Safari (2004) and Opera
   (2005) followed.

   cs-history:
   For five years almost nobody used it. Then Gmail (April 2004),
   Google Suggest (December 2004) and Google Maps (February 2005)
   showed a page that
   talked to its server while one typed and dragged; Jesse James
   Garrett gave the technique the name it kept, Ajax ("Asynchronous
   JavaScript and XML", February 2005), and jQuery's $.ajax (2006) made
   it one line. The W3C wrote down what the browsers did (a first draft
   in 2006, by Anne van Kesteren); "level 2" (2008 to 2011) added
   requests to other origins (CORS: Script_fetch.mli) and progress.
   What came back stopped being XML within those years: JSON (Js_json.mli).

   modern:
   Where it stands. fetch (2015, Script_fetch) is the same request as a
   promise, and what new code writes. XMLHttpRequest is still what old
   code, jQuery and htmx use, and the one of the two that can say how
   far an upload is. Both go out through Script_fetch.ask, and the rule
   on who may read an answer is there.

   How it is used:

     const x = new XMLHttpRequest()
     x.open("GET", "/items.json")
     x.onload = () => { if (x.status === 200) show(JSON.parse(x.responseText)) }
     x.onerror = () => say("no answer")
     x.send()                            // and the script goes on

   It is an object with a state, readyState, that moves as the request
   does, each move said by a readystatechange event -- the one event
   the first version had, which is why old code tests "readyState == 4
   && status == 200" in it:

     0 UNSENT  --open()-->  1 OPENED  --send()-->  ... the network ...
                                                   -->  4 DONE
                                  then load (an answer, whatever its
                                  status) or error (none), then loadend

   (2 and 3, the headers then the body arriving, are not said here: an
   answer comes whole.) Once done: status, statusText, responseText,
   response (the text, or the parsed JSON with responseType "json"),
   responseURL, getResponseHeader(name), getAllResponseHeaders().

   Why "asynchronous" is the whole point: a script runs to its end
   before the page moves again (Js_eval.mli), so send() cannot wait for
   the answer; it returns at once, and the answer is another task,
   later (Script_fetch.mli's diagram). The original could also wait --
   open's third argument false, a "synchronous" request, the page
   frozen meanwhile -- which browsers now refuse to do on a page; it
   is not here.

   Not here either: the progress of an upload, timeout, the script's
   own request headers but Content-Type; overrideMimeType and
   withCredentials can be set and change nothing.

   Reference: the XMLHttpRequest Standard (xhr.spec.whatwg.org). Alex
   Hopmann, "The story of XMLHTTP" (his site). Jesse James Garrett, "Ajax:
   A New Approach to Web Applications" (Adaptive Path, 2005). *)
(* ix: the author's mini-chrome's src/webapi/net/XMLHttpRequest.mli (its 8af888e) (docs/plans/plan_browser.md) *)

open Js_value
open Script_types

(* XMLHttpRequest defined *)
val install : t -> (string -> value -> unit) -> unit
