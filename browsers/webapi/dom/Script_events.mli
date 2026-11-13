(* Script_events: an event as a script makes one.

   The browser makes events (a click or a key, in Browser_script), and
   so do scripts, to talk to each other: a library announces what it
   did with an event of its own name, and the page listens for it.

   cs-history:
   Which way an event travels was the browser wars' last quarrel. The
   first handlers were attributes (onclick="...", Netscape 2, 1995),
   one per element. For "Dynamic HTML" (1997) both browsers let an
   event be heard by the elements around its target, in opposite
   orders: Netscape 4 sent it from the window down to the target
   ("capturing"), and Internet Explorer 4 from the target up to the
   window ("bubbling"). The W3C's answer (DOM Level 2 Events, 2000) was both:
   an event goes down, then up, and addEventListener's third argument
   says which leg a listener is on. Bubbling is what everybody uses,
   and what is here. Internet Explorer had only its own attachEvent
   until version 9 (2011); hiding that difference was the first job
   of jQuery.

     el.addEventListener("saved", e => console.log(e.detail.id))
     el.dispatchEvent(new CustomEvent("saved", { detail: { id: 7 }, bubbles: true }))

   An event is a plain object:

     type              "saved"
     bubbles           whether, after its target, it goes up to the
                       target's parents and the document
     cancelable, detail, and whatever the second argument has
     target, currentTarget     set as it is dispatched
     preventDefault()          sets defaultPrevented
     stopPropagation()         sets cancelBubble: the event goes no
                               further up
     stopImmediatePropagation()   and it does not go to the next
                               listener either

   and a dispatch looks only at those properties: an event has no state
   anywhere else.

   There are two ways to make one: the constructors (new Event(type,
   init), new CustomEvent, new MouseEvent..., all the same object
   here), and the older document.createEvent("CustomEvent") followed
   by initCustomEvent(type, bubbles, cancelable, detail), which htmx
   and jQuery still fall back on.

   Reference: Peter-Paul Koch, "Event order" (quirksmode.org), the two
   models side by side; DOM Living Standard, section 2 (events): 2.2
   Event, 2.4 CustomEvent, 2.9 dispatch. *)
(* ix: copied from src/webapi/dom/Script_events.mli in the author's
 * mini-chrome (its 8af888e) (docs/plans/plan_browser.md) *)

open Js_value

(* makes an event of a type, with these properties; it is not
 * dispatched yet *)
val make : bubbles:bool -> string -> (string * value) list -> value

(* defines Event, CustomEvent, MouseEvent, KeyboardEvent... (each one
 * instanceof Event) *)
val install : (string -> value -> unit) -> unit

(* document.createEvent(kind): it makes an event with no type yet, with
 * initEvent and initCustomEvent to give it one *)
val create : unit -> value

(* reads an event's property as a flag: bubbles, cancelBubble,
 * defaultPrevented *)
val flag : value -> string -> bool
