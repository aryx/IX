(* Script_types: the types that Browser_script's modules speak of. They
   are the page's mutable copy, a node at a time, and the state of a
   page's scripts. This file has types alone.

     Script_dom      the copy: it is thawed from the page's tree,
                     changed, and frozen back; its HTML; the elements
                     that a selector picks
     Script_host     the host objects that a script sees: an element's,
                     the document's, location, a URL
     Browser_script  the tasks (the page's scripts run, an event
                     dispatched, the timers) and what the browser asks

   Browser_script.mli tells the whole story.

   There are two trees and a mailbox. The browser's tree (Dom.element)
   is a value: an element has children and no parent, and none of it
   can be changed. A script asks for el.parentNode and assigns
   el.textContent, so [node] is the same tree with what a value cannot
   have: a parent, fields that change, and what scripts hang on an
   element (its host object, its listeners, the properties they
   invent).

     Dom.element  { name; attributes; extensions; origin; children }
     node         { name; attributes; children; parent; text;     mutable
                    wrapper; listeners; expando; compiled }

   The state of a page's scripts, [t], holds the engine, the root of
   that copy, the page's clock and timers, and the mailbox. The mailbox
   is what a script asked of the browser during a task: it is left in
   a field, and the browser takes it when the task is over.

     the script does                 the field       the browser's take
     alert("hi")                     alerts          take_alerts
     fetch("/n"), x.send()           requests        take_requests
     location.href = "/next"         navigation      take_navigation
     form.submit()                   submission      take_submission
     history.pushState(..., "/p")    address         take_address
     el.textContent = "3"            changed         changed, tree

   (the take_ functions are Browser_script's). The scripts never call
   out: the modules of this directory take no capability and see no
   network.

   design:
   Why a file of types alone, and why here. Each module over it could
   define its own part (a node in Script_dom, a request in
   Script_fetch), but not the state. The state is one record that
   every module reads or adds to. It holds the nodes, the timers, the
   requests, and two functions, more and dispatch, which the module
   that comes last sets; they are how an earlier module calls a later
   one. Because the record is defined before all the modules, the code
   can be in layers, each module using only those before it. This file
   is not a place to put types for convenience: it is one structure,
   the page as its scripts see it. *)
(* ix: copied from src/webapi/Script_types.mli in the author's
 * mini-chrome (its 8af888e) (docs/plans/plan_browser.md) *)

open Js_value

(* an element, or a text (whose [name] is "#text" and whose content is
 * its [text]) *)
type node = {
  name : string;
  mutable text : string;
  mutable attributes : (string * string) list; (* all of them, the core ones and Netscape's *)
  mutable children : node list;
  mutable parent : node option;
  mutable expando : (string * value) list; (* what a script set on it, as in el.done = true *)
  mutable wrapper : value option; (* its host object, made once *)
  mutable listeners : (string * value) list; (* those added by addEventListener, in order *)
  mutable compiled : (string * value) list; (* its onclick="..." attributes, compiled once *)
}

(* a request that a script made (with XMLHttpRequest or fetch), for the
 * browser to send, with its number, by which its answer comes back;
 * and an answer, as the script is given it *)
type request = { rid : int; meth : string; (* "GET", "POST" *) url : string; post : (string * string) option (* the body's content type, and the body *); said : (string * string) list; (* the script's headers, and Origin (the page's origin) for a request to another site or a POST *) }
type answer = { status : int; headers : (string * string) list; body : string; final : string (* the URL, after the redirections *) }

(* a timer that setTimeout or setInterval made *)
type timer = { tid : int; mutable due : float; every : float option; fn : value; frame : bool (* a timer of requestAnimationFrame, whose function is called with the time *) }

type t = {
  engine : Js_eval.t;
  root : node;
  mutable changed : bool;
  mutable console : string list; (* the newest first *)
  log : string -> unit;
  nodes : (int, node) Hashtbl.t; (* maps a host object's id to its node *)
  mutable document_listeners : (string * value) list;
  mutable frozen : (Dom.element * node) list; (* the elements of the last frozen tree, and their nodes *)
  mutable now : float; (* the page's clock, in ms *)
  mutable timers : timer list;
  mutable next_timer : int;
  mutable alerts : string list; (* the newest first *)
  mutable base : string; (* the page's address, against which an a's href, location and new URL are resolved; history.pushState changes it *)
  (* the addresses the page gave itself, for the browser to show, each
   * with whether it replaces the entry (true for replaceState, false
   * for history.pushState) *)
  mutable address : (string * bool) list; (* the last first *)
  mutable requests : request list; (* the requests of XMLHttpRequest and fetch, for the browser to send; the newest first *)
  (* the requests sent and not answered yet, each with what to do with
   * its answer, or with the reason there is none *)
  mutable waiting : (int * ((answer, string) result -> unit)) list;
  mutable next_request : int;
  (* where a script sent the page (with location.href = ... or
   * location.replace): the address, and whether the new page takes this
   * page's place in the history *)
  mutable navigation : (string * bool) option;
  (* a form that a script sent itself (form.submit()): where it goes,
   * and a POST's content type and body *)
  mutable submission : (string * (string * string) option) option;
  (* the <script> element whose script is running. It is
   * document.currentScript, which is how a loader finds where its own
   * file came from *)
  mutable current_script : node option;
  (* document.cookie, read and assigned to. It is the browser's jar for
   * the page's address, without its HttpOnly cookies *)
  cookies : (unit -> string) * (string -> unit);
  (* [more] gives an element's members that came after the first DOM
   * (Script_element's matches, closest, append, dataset...); it is
   * asked when Script_host has no member of that name. [dispatch]
   * dispatches an event from a script (el.dispatchEvent(ev),
   * el.click(); None means at the document) and says whether it was
   * prevented. Browser_script sets both, because it comes after the
   * modules that call them *)
  mutable more : node -> string -> value option;
  mutable dispatch : node option -> value -> bool;
  (* called on a node that a script put in the page: a <script> among
   * what was inserted is loaded and run (by Browser_script) *)
  mutable inserted : node -> unit;
  (* how far down the window has scrolled the page, in the page's
   * pixels. It is scrollY, and the rectangles that a script asks for
   * are measured from it *)
  mutable scroll_y : float;
  (* [where] says where an element is, for a script that asks
   * (offsetHeight, getBoundingClientRect): its x, y, width and height
   * in the page, from a layout of the tree as it is now. [measure] is
   * the browser's function, and is given the frozen tree; its answers
   * are kept in [geometry] until the tree changes *)
  mutable where : node -> (float * float * float * float) option;
  mutable measure : (Dom.element -> Dom.element -> (float * float * float * float) option) option;
  mutable geometry : (node -> (float * float * float * float) option) option;
  (* the requests whose answers skip the check of who may read them:
   * those of a classic script, which may come from anywhere *)
  mutable exempt : int list;
  (* the listeners added with addEventListener's { once: true }, to
   * remove when they are called *)
  mutable once : (string * value) list;
  (* the prototypes of the host objects, by kind ("tag:<name>" for an
   * element of that tag, "element" for the others, "text", "comment",
   * "fragment", "document", "window"), such as HTMLElement.prototype;
   * Script_window makes them *)
  mutable protos : (string * obj) list;
  (* document.readyState: "loading" while the page's scripts run,
   * "interactive" at DOMContentLoaded, "complete" at load *)
  mutable ready : string;
}
