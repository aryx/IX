(* Model-View-Controller: the model is the truth, and the views watch
 * it (notes_gui.md section 4).
 *
 * Trygve Reenskaug, at Xerox PARC, December 1979, for Smalltalk-80 --
 * the oldest name in this whole area, and the one most argued about
 * since, because almost nothing called MVC today is what he wrote
 * down. His arrangement:
 *
 *        +---------+   changed!   +-------+
 *        |  model  | -----------> | view  |   the view asks the model
 *        +---------+              +-------+   what to draw, and redraws
 *             ^                       |       itself when told
 *             |  change it            | the mouse, the keys
 *             |                       v
 *        +--------------------------------+
 *        |          controller            |
 *        +--------------------------------+
 *
 * The one idea worth keeping, and the reason it beat callbacks: the
 * count is in *one* place. A view never holds the truth, it shows it;
 * when the model changes it says so, and every view that cares reads
 * it again. The bug of Retained.mli -- a label saying something the
 * program does not believe -- cannot be written, because the label is
 * not where the number lives.
 *
 * What it costs, and what MVU (the playground itself) answers:
 *
 *   - **the notification graph**. Who is observing what is invisible
 *     in the code and only exists at run time. A change that touches
 *     three models wakes every view of each, in an order nobody
 *     chose, and a view woken twice redraws twice;
 *   - **it must be unsubscribed**. An observer outlives the view that
 *     registered it unless somebody remembers to remove it -- the
 *     classic leak of every observer system;
 *   - **the controller is the vaguest box anybody has drawn**. Half
 *     the arguments about MVC since 1979 are about what belongs in
 *     it, which is a sign that it is not a real thing so much as
 *     "the rest".
 *
 * This module is only the model half -- a value, and who to tell when
 * it changes. The views here are Retained widgets that re-read it,
 * and the controller is the callbacks on them, which is exactly
 * Smalltalk's arrangement with OCaml's spelling.
 *
 * Worked example, a count watched by two labels:
 *
 *   let count = Mvc.create 0
 *   let show l () = Retained.set_text l (string_of_int (Mvc.get count))
 *   Mvc.on_change count (show big);
 *   Mvc.on_change count (show small);
 *   Mvc.change count (fun n -> n + 1)
 *
 * and both labels say 1, neither named by whoever counted; a third
 * view is one more [on_change], with no line of the counting touched.
 *
 * terminology:
 * The model's half has a name of its own, the *observer* pattern
 * (Gamma, Helm, Johnson, Vlissides, Design Patterns, 1994): a
 * *subject* keeps a list of *observers* and tells each when it
 * changes. Smalltalk-80 had it in every object, as its *dependents*
 * (changed: on one side, update: on the other). Publish and
 * subscribe, a signal's listeners, a spreadsheet's cells that
 * recompute when another does (Sheet): the same list of who to
 * tell.
 *
 * evolution:
 * The three letters were kept and the arrangement was not. In
 * Model-View-Presenter (Taligent, 1996; from memory) the view no
 * longer reads the model: a presenter stands between them. In
 * Model-View-ViewModel (John Gossman, Microsoft, 2005, for WPF) the
 * view is *bound* to a model made for it, and the toolkit does the
 * watching. And what web frameworks have called MVC since Rails
 * (2004) is another thing again: a request comes in, a controller
 * picks a model and renders a view, once, and nothing watches
 * anything -- there is no screen to keep up to date between two
 * requests.
 *
 * References: Trygve Reenskaug's notes of 1979 at Xerox PARC,
 * "Thing-Model-View-Editor" and "Models-Views-Controllers" (from
 * memory); Glenn Krasner and Stephen Pope, "A Cookbook
 * for Using the Model-View-Controller User Interface Paradigm in
 * Smalltalk-80" (1988), the first description most people read. *)

type 'model t

val create : 'model -> 'model t
val get : 'model t -> 'model

(* [change t f]: the new model, and then everybody who is watching is
 * told, in the order they signed up *)
val change : 'model t -> ('model -> 'model) -> unit

(* [on_change t f]: [f] is called after every change. There is no way
 * to stop watching, on purpose: a toolkit this size does not need it,
 * and its absence is the leak named above, in one line. *)
val on_change : 'model t -> (unit -> unit) -> unit

(* how many times the observers have been told, which is the number
 * worth looking at when comparing this with the other three *)
val notifications : 'model t -> int
