(* XMLHttpRequest: a script asking its server, the first way -- "XHR",
   the object the web's applications were built on.

   cs-history:
   This is where it came from. Until 1999 a page got something new
   from its server in one way only: by being replaced. A link or a
   form brought a whole new page. (The tricks around that, such as a
   hidden frame reloaded or an image's address used as a message, show
   how much it was wanted.) The team of Outlook Web Access, Exchange's
   mail in a browser, needed mail to arrive in a page that stayed.
   Alex Hopmann wrote for them a small component that made an HTTP
   request from a script. To ship it in time with Internet Explorer 5
   (March 1999), it went into the one library that was on its way out
   of the door, Microsoft's XML parser, as "XMLHTTP". Hence the XML of
   the name, which was never needed: any text can go through. Mozilla
   made the same thing a native object, XMLHttpRequest (2000 to 2002);
   Safari (2004) and Opera (2005) followed.

   cs-history:
   For five years almost nobody used it. Then Gmail (April 2004),
   Google Suggest (December 2004) and Google Maps (February 2005)
   showed a page that talked to its server while one typed and
   dragged. Jesse James Garrett gave the technique the name it kept,
   Ajax ("Asynchronous JavaScript and XML", February 2005), and
   jQuery's $.ajax (2006) made it one line. The W3C wrote down what
   the browsers did (a first draft in 2006, by Anne van Kesteren);
   "level 2" (2008 to 2011) added requests to other origins (CORS:
   Script_fetch.mli) and progress. Within those years, what came back
   stopped being XML and became JSON (Js_json.mli).

   modern:
   Here is where it stands. fetch (2015, Script_fetch) is the same
   request as a promise, and it is what new code writes.
   XMLHttpRequest is still what old code, jQuery and htmx use, and it
   is the one of the two that can say how far an upload is. Both go
   out through Script_fetch.ask, where the rule on who may read an
   answer is.

   How it is used:

     const x = new XMLHttpRequest()
     x.open("GET", "/items.json")
     x.onload = () => { if (x.status === 200) show(JSON.parse(x.responseText)) }
     x.onerror = () => say("no answer")
     x.send()                            // and the script goes on

   It is an object with a state, readyState, that moves as the request
   does. A readystatechange event tells each move. It was the one event
   that the first version had, which is why old code tests
   "readyState == 4 && status == 200" in it:

     0 UNSENT  --open()-->  1 OPENED  --send()-->  ... the network ...
                                                   -->  4 DONE
                                  then load (an answer, whatever its
                                  status) or error (none), then loadend

   (The states 2 and 3, when the headers and then the body arrive, are
   not told here, because an answer comes whole.) Once the request is
   done, the script reads status, statusText, responseText, response
   (the text, or the parsed JSON with responseType "json"),
   responseURL, getResponseHeader(name) and getAllResponseHeaders().

   Being "asynchronous" is the whole point. A script runs to its end
   before the page moves again (Js_eval.mli), so send() cannot wait
   for the answer: it returns at once, and the answer comes later, as
   another task (see Script_fetch.mli's diagram). The original could
   also wait: with open's third argument false, a "synchronous"
   request froze the page meanwhile. Browsers now refuse to do that on
   a page, and it is not here.

   These are not here either: the progress of an upload, timeout, and
   the script's own request headers other than Content-Type.
   overrideMimeType and withCredentials can be set, and change
   nothing.

   Reference: the XMLHttpRequest Standard (xhr.spec.whatwg.org). Alex
   Hopmann, "The story of XMLHTTP" (his site). Jesse James Garrett, "Ajax:
   A New Approach to Web Applications" (Adaptive Path, 2005). *)
(* ix: copied from src/webapi/net/XMLHttpRequest.mli in the author's
 * mini-chrome (its 8af888e) (docs/plans/plan_browser.md) *)

open Js_value
open Script_types

(* defines XMLHttpRequest *)
val install : t -> (string -> value -> unit) -> unit
