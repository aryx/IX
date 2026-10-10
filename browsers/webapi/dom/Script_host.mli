(* Script_host: the host objects -- what a script reaches the page
   through (Browser_script.mli's opening): [document], and an object per
   element it asks for, whose properties and methods are OCaml
   functions over the page's copy (Script_dom).

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
   and a variable holding an element stays good. What changes the tree
   says so ([touch]): the browser then lays the page out again, once,
   after the task.

   Events, timers and the page's globals (window, console, setTimeout)
   are Browser_script's, which gives these objects to the engine. *)
(* ix: the author's mini-chrome's src/webapi/dom/Script_host.mli (its 8af888e) (docs/plans/plan_browser.md) *)

open Js_value
open Script_types

(* a script has changed the tree: the page to be laid out again *)
val touch : t -> unit

(* an argument as a string; the [i]th argument, undefined past the last *)
val str : value -> string
val arg : value list -> int -> value

(* a host function of its arguments alone *)
val method_ : string -> (value list -> value) -> value

(* a node's host object, made once; the node a host object stands for
 * (a TypeError thrown for anything else) *)
(* ix: the debugging switches, a host's to set (they were the logs'
 * level with the environment's JS_MISSING, and JS_EVENTS): each name a
 * page asks for that is not here said once; the events ("click",
 * "mousedown") whose listeners on their way are said. What is said
 * goes to Js_value.say. *)
val says_missing : bool ref
val events_said : string list ref

(* what a page asked for that is not here, said once a page with -v
   ("missing: Window.indexedDB"); the names said so far, forgotten at
   each new page *)
val missed : string -> unit
val missed_names : unit -> (string, unit) Hashtbl.t

val wrap : t -> node -> value
val node_of : t -> value -> node

(* an object of a URL's parts (href, protocol, host, pathname, search,
 * hash, origin), with searchParams and toString; the page's own *)
val url_parts : string -> (string * string) list
val url_object : string -> value
(* location: its parts, and href =, assign, replace, reload, which note
 * where the script sends the page (the page's state's navigation) *)
val location : t -> value

(* the first element named so, at any depth *)
val find : node -> string -> node option

(* the properties that are an attribute (el.type, el.htmlFor: "for"),
 * and those that say whether one is there (el.disabled): each with
 * its attribute's name *)
val reflected : (string * string) list
val reflected_flags : (string * string) list

(* a node's host objects, as an array *)
val nodes_array : t -> node list -> value

(* [insert t parent child ~before]: child put in parent, before a
 * child of it or at the end, moved if it was elsewhere; a fragment's
 * children in its place. The child *)
val insert : t -> node -> value -> before:node option -> value

(* addEventListener's third argument read: { once: true } noted;
 * { signal }: [remove] called when it aborts *)
val listening_once : t -> value list -> remove:(unit -> unit) -> unit

(* backgroundColor, the property; background-color, the CSS (and an
 * attribute: dataset.userId is data-user-id) *)
val kebab : string -> string

(* what a script gives where a text is expected, as a text: an
 * object's by its own toString (a "trusted" HTML or address a page
 * wraps its strings in), anything else as the language says *)
val text : t -> value -> string
