(* Script_types: what Browser_script's modules speak of -- the page's
   mutable copy, a node at a time, and the state of a page's scripts.
   Types alone.

     Script_dom      the copy: thawed from the page's tree, changed,
                     frozen back; its HTML; a selector's elements
     Script_host     the host objects a script sees: an element's,
                     document, location, a URL
     Browser_script  the tasks: the page's scripts run, an event
                     dispatched, the timers; what the browser asks

   Browser_script.mli tells the whole. *)
(* ix: the author's mini-chrome's src/webapi/Script_types.mli (its 8af888e) (docs/plans/plan_browser.md) *)

open Js_value

(* an element, or a text ([name] "#text", its [text]) *)
type node = {
  name : string;
  mutable text : string;
  mutable attributes : (string * string) list; (* all of them, core and Netscape's *)
  mutable children : node list;
  mutable parent : node option;
  mutable expando : (string * value) list; (* what a script set on it: el.done = true *)
  mutable wrapper : value option; (* its host object, made once *)
  mutable listeners : (string * value) list; (* addEventListener's, in order *)
  mutable compiled : (string * value) list; (* its onclick="..." attributes, compiled once *)
  mutable shadow : node option; (* its shadow tree's root, a fragment: drawn in its children's place (Shadow_tree) *)
}

(* a setTimeout's or a setInterval's *)
(* a request a script made (XMLHttpRequest, fetch), for the
 * browser to send: its number, by which its answer comes back; and an
 * answer, as the script is given it *)
type request = { rid : int; meth : string; (* "GET", "POST" *) url : string; post : (string * string) option (* a body's content type, and it *); said : (string * string) list; (* the script's headers; Origin, the page's, to another site *)
  ahead : (string -> unit) option; (* what to do with the answer's body where it is fetched (a module's text read) *) }
type answer = { status : int; headers : (string * string) list; body : string; final : string (* the URL, after the redirections *) }

type timer = { tid : int; mutable due : float; every : float option; fn : value; frame : bool (* requestAnimationFrame's: called with the time *) }

type t = {
  engine : Js_eval.t;
  root : node;
  mutable changed : bool;
  mutable console : string list; (* the newest first *)
  log : string -> unit;
  nodes : (int, node) Hashtbl.t; (* a host object's id to its node *)
  mutable document_listeners : (string * value) list;
  mutable frozen : (Dom.element * node) list; (* the last frozen tree's elements, and their nodes *)
  mutable now : float; (* the page's clock, in ms *)
  mutable timers : timer list;
  mutable next_timer : int;
  mutable alerts : string list; (* the newest first *)
  mutable base : string; (* the page's address: an a's href resolved, location, new URL; changed by history.pushState *)
  (* an address the page gave itself (history.pushState, replaceState:
   * whether it replaces the entry), for the browser to show *)
  mutable address : (string * bool) list; (* the last first *)
  mutable requests : request list; (* XMLHttpRequest's and fetch's, for the browser to send; the newest first *)
  (* those sent and not answered yet: what to do with each one's answer, or with why there is none *)
  mutable waiting : (int * ((answer, string) result -> unit)) list;
  mutable next_request : int;
  (* the page's modules (Script_modules): their texts by address as
   * they come, the engine's table of them, and what is ready to run *)
  mutable import_map : (string * string) list; (* <script type=importmap>: a name, or a prefix ending in /, to an address *)
  mutable module_sources : (string * string) list;
  mutable module_asked : (string * ((string, string) result -> unit) list ref) list; (* those on their way, and who waits for each *)
  mutable modules : Js_module.t option;
  mutable module_jobs : (unit -> unit) list;
  (* where a script sent the page (location.href = ..., location.replace):
   * the address, and whether it takes the page's place in the history *)
  mutable navigation : (string * bool) option;
  (* a form a script sent itself (form.submit()): where to, and a POST's
   * content type and body *)
  mutable submission : (string * (string * string) option) option;
  (* the <script> element whose script is running: document.currentScript,
   * how a loader finds where its own file came from *)
  mutable current_script : node option;
  (* document.cookie, read and assigned to: the browser's jar,
   * for the page's address, without its HttpOnly cookies *)
  cookies : (unit -> string) * (string -> unit);
  (* an element's members past the first DOM's (Script_element:
   * matches, closest, append, dataset...), asked when Script_host has
   * none of that name; and an event dispatched by a script
   * (el.dispatchEvent(ev), el.click(); None: at the document), whether
   * it was prevented. Both set by Browser_script, which is after them *)
  mutable more : node -> string -> value option;
  mutable dispatch : node option -> value -> bool;
  (* a node a script put in the page: a <script> among what was
   * inserted is loaded and run (Browser_script's) *)
  mutable inserted : node -> unit;
  (* where an element is, for a script that asks (offsetHeight,
   * getBoundingClientRect): x, y, width, height in the page, by a
   * layout of the tree as it is now -- [measure], the browser's, given
   * the frozen tree; its answers kept ([geometry]) until the tree
   * changes *)
  (* how far down the window has scrolled the page, in its pixels:
   * scrollY, and what a rectangle asked for is seen from *)
  mutable scroll_y : float;
  mutable where : node -> (float * float * float * float) option;
  mutable measure : (Dom.element -> Dom.element -> (float * float * float * float) option) option;
  mutable geometry : (node -> (float * float * float * float) option) option;
  (* the requests answered without the check of who may read them: a
   * classic script's, from anywhere *)
  mutable exempt : int list;
  (* addEventListener's { once: true }: the listeners to remove when called *)
  mutable once : (string * value) list;
  (* the prototypes of the host objects, by kind ("element", "text",
   * "comment", "fragment"): HTMLElement.prototype... (Script_window) *)
  mutable protos : (string * obj) list;
  (* document.readyState: "loading" while the page's scripts run,
   * "interactive" at DOMContentLoaded, "complete" at load *)
  mutable ready : string;
  (* the worlds of the documents its <iframe>s show, by what each shows
   * (its srcdoc's text, its src's address): Browser_script.adopt *)
  mutable frames : (string * t) list;
}
