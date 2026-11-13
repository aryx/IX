(* Script_host: the host objects, through which a script reaches the
   page (see the opening of Browser_script.mli). They are [document],
   and an object for each element that the script asks for, whose
   properties and methods are OCaml functions over the page's copy
   (Script_dom).

     document.getElementById("count")     the element whose id= is "count"
     document.querySelector("ul li.done") the first one Css.matches
     el.textContent = "3"                 its children replaced by the text "3"
     el.innerHTML = "<b>3</b>"            by Html_tree's parse of the string
     el.style.color = "red"               "color: red" in its style=
     el.className = "done"                its class=
     el.appendChild(document.createElement("li"))
     location.pathname, new URL(href).searchParams.get("q")

   An element keeps the same host object for as long as it lives
   ([wrap] makes it once), so getElementById("x") === getElementById("x")
   and a variable holding an element stays good. Whatever changes the
   tree says so ([touch]), and the browser then lays the page out
   again, once, after the task.

   Events, timers and the page's globals (window, console, setTimeout)
   are Browser_script's, which gives these objects to the engine. *)
(* ix: copied from src/webapi/dom/Script_host.mli in the author's
 * mini-chrome (its 8af888e) (docs/plans/plan_browser.md) *)

open Js_value
open Script_types

(* says that a script has changed the tree, so that the page is laid out
 * again *)
val touch : t -> unit

(* [str] gives an argument as a string; [arg args i] is the [i]th
 * argument, undefined past the last *)
val str : value -> string
val arg : value list -> int -> value

(* makes a host function that looks at its arguments alone *)
val method_ : string -> (value list -> value) -> value

(* [wrap] gives a node's host object, made once; [node_of] gives the
 * node that a host object stands for (and throws a TypeError for
 * anything else) *)
(* ix: the debugging switches, for the host to set (they were the logs'
 * level with the environment's JS_MISSING, and JS_EVENTS). With
 * [says_missing], each name that a page asks for and that is not here
 * is said once. For the events named in [events_said] ("click",
 * "mousedown"), each listener on the event's way is said. What is said
 * goes to Js_value.say. *)
val says_missing : bool ref
val events_said : string list ref

(* [missed] notes a name that a page asked for and that is not here;
   with -v it is said, once a page ("missing: Window.indexedDB").
   [missed_names] gives the names noted so far, which are forgotten at
   each new page *)
val missed : string -> unit
val missed_names : unit -> (string, unit) Hashtbl.t

val wrap : t -> node -> value
val node_of : t -> value -> node

(* a URL's parts (href, protocol, host, pathname, search, hash,
 * origin), as location and new URL give them; [url_object] makes them
 * an object, with searchParams and toString (new URL's) *)
val url_parts : string -> (string * string) list
val url_object : string -> value
(* location: its parts, and href =, assign, replace and reload, which
 * note where the script sends the page (in the navigation field of the
 * page's state) *)
val location : t -> value

(* the first element named so, at any depth *)
val find : node -> string -> node option

(* [reflected] lists the properties that stand for an attribute
 * (el.type, and el.htmlFor for "for"), and [reflected_flags] those
 * that say whether an attribute is there (el.disabled). Each comes
 * with its attribute's name *)
val reflected : (string * string) list
val reflected_flags : (string * string) list

(* the host objects of nodes, as an array *)
val nodes_array : t -> node list -> value

(* [insert t parent child ~before] puts child in parent, before a child
 * of parent or at the end, and moves it if it was elsewhere. A
 * fragment's children go in the fragment's place. It returns the
 * child *)
val insert : t -> node -> value -> before:node option -> value

(* reads addEventListener's third argument: { once: true } is noted,
 * and with { signal }, [remove] is called when the signal aborts *)
val listening_once : t -> value list -> remove:(unit -> unit) -> unit

(* turns a property's name, backgroundColor, into the CSS one,
 * background-color (and into an attribute's: dataset.userId is
 * data-user-id) *)
val kebab : string -> string

(* what a script gives where a text is expected, as a text. An object
 * becomes a text by its own toString (as for the "trusted" HTML or
 * address that a page wraps its strings in); anything else becomes one
 * as the language says *)
val text : t -> value -> string
