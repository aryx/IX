(* Model-View-Update: one model, a view built from it every time, and
 * an update that answers a message with a new model (notes_gui.md
 * section 4).
 *
 *      msg                     +----------+
 *   ---------> update ------>  |  model   |
 *                  ^           +----------+
 *                  |                |
 *                  |                v
 *                  +------------- view  ----> what is on the screen
 *                    (messages)
 *
 * Elm (Evan Czaplicki, 2012), and after it Redux, SwiftUI, Jetpack
 * Compose and React-with-hooks: the idea that won. Two properties buy
 * everything else:
 *
 *   - **the view is a function of the model**, so it cannot go stale.
 *     There is no "refresh the label" to forget;
 *   - **the model changes in one place**, [update], so a recorded
 *     list of messages replays the whole session -- which is what
 *     makes time-travel debugging (plan_inspect_teaching.md) a
 *     property of the architecture rather than a feature.
 *
 * This playground is MVU already, with one difference worth being
 * precise about: [Playground.game]'s update is
 * [computer -> 'memory -> 'memory] and has **no message type**. The
 * events are the computer, and you read them yourself -- which is why
 * the playground's own [Gui] is immediate mode (Immediate.mli), and
 * why this module exists separately: to write the *textbook* MVU,
 * with messages, beside the other three and compare.
 *
 * And one honest thing this module makes visible. A view rebuilt from
 * the model cannot hold the caret or the focus -- they are not in the
 * model, and the tree is thrown away every frame. So something
 * underneath must keep them ([t] below). In Elm that something is the
 * browser, which keeps the focus and the selection in the real DOM;
 * it is also the reason a virtual DOM needs keys, and why React has
 * refs. The architecture is honest about where the truth is, and then
 * quietly leans on the platform for the truth it cannot hold.
 *
 * Worked example, the counter (Gui4Counter has it whole):
 *
 *   type msg = Bumped
 *   let update Bumped n = n + 1
 *   let view n = group [ label a (string_of_int n);
 *                        button ~enabled:true b "count" Bumped ]
 *
 *   frame   model   the person        messages    model after
 *     1       0     presses           []             0
 *     2       0     releases on it    [Bumped]       1
 *     3       1     nothing           []             1
 *
 * [view] never says "set the label": at frame 3 the label is made
 * again from 1, as it was made from 0.
 *
 * Where it stands: Playground.mli has this architecture under its
 * picture, animation and game (its [app]: an init, a view, an update,
 * the subscriptions of Sub and the commands of Cmd), and Bigbang.mli
 * tells how How to Design Programs had it before Elm.
 *
 * terminology:
 * One arrangement, many names. Elm calls it The Elm Architecture,
 * and model, view, update are the three things its programs define.
 * In Redux (Dan Abramov and Andrew Clark, 2015) the model is the
 * *store*, a message an *action*, update a *reducer* -- the word for
 * the function given to a fold, which is what update is: the model
 * is the fold of update over the messages. "Unidirectional data
 * flow" is the same picture as the one above, named by its arrows.
 *
 * evolution:
 * Elm did not start here. Czaplicki's thesis (Harvard, 2012) was
 * functional reactive programming: a program was a network of
 * *signals*, values that change over time (Conal Elliott and Paul
 * Hudak, "Functional Reactive Animation", 1997), and the mouse's
 * position was one. The programs people wrote in it kept taking one
 * shape -- fold the events into a model, map the model to a view --
 * which was named the architecture, and in 2016 Elm 0.17 took the
 * signals out of the language ("A Farewell to FRP") and kept the
 * shape.
 *
 * comeback:
 * The signals came back, elsewhere: SolidJS, Svelte and Vue update
 * only what reads a value that changed, with no tree rebuilt and
 * compared -- the observers of Mvc.mli, this time with the graph
 * found by the framework and not kept by hand.
 *
 * References: Evan Czaplicki, "Elm: Concurrent FRP for Functional
 * GUIs" (2012); the Elm guide's chapter "The Elm Architecture"
 * (guide.elm-lang.org). *)

(*****************************************************************************)
(* {1 The view: widgets carrying messages} *)
(*****************************************************************************)

(* what a view is made of: the widgets, each carrying the message it
 * sends *)
type 'msg element

val button : enabled:bool -> Widget.box -> string -> 'msg -> 'msg element
val label : Widget.box -> string -> 'msg element
val field : enabled:bool -> Widget.box -> string -> (string -> 'msg) -> 'msg element

(* [slider box ~from ~to_ value to_msg]: the value comes from the
 * model, and dragging sends the new one *)
val slider : Widget.box -> from:float -> to_:float -> float -> (float -> 'msg) -> 'msg element

val progress : Widget.box -> float -> 'msg element

(* [menu box items chosen to_msg]: which item is chosen is the model's;
 * whether the items are showing is not, and lives underneath with the
 * focus *)
val menu : Widget.box -> string list -> int -> (int -> 'msg) -> 'msg element

val group : 'msg element list -> 'msg element

(* [canvas box drawing to_msg]: the model's picture, drawn by the view
 * like everything else -- so nothing has to be told to redraw it -- and
 * what the mouse does there as messages, [None] for what the program
 * ignores *)
val canvas : Widget.box -> Widget.paint list -> (Widget.canvas_event -> 'msg option) -> 'msg element

(* [context_menu at items to_msg]: a menu at a point, in the view while
 * the model says it is open. It has the mouse, and the next click
 * sends [to_msg (Some i)] on an item or [to_msg None] elsewhere; the
 * model closes it by leaving it out of the next view. *)
val context_menu : float * float -> string list -> (int option -> 'msg) -> 'msg element

(*****************************************************************************)
(* {1 Running the loop} *)
(*****************************************************************************)

(* what the platform keeps between frames, because the model cannot:
 * who has the keys, and where the caret is *)
type t

val empty : t

(* [step theme input t ~view ~update model]: one turn of the loop
 * above, and the whole of it --
 *
 *   view the model  ->  the actions become messages  ->  update folds
 *   them into a new model  ->  view *that*, which is what is drawn
 *
 * so what the person sees is always the model after their click, not
 * before it. (The view function runs twice, which is what Elm does
 * too: a view is cheap, and being a function of the model is the
 * whole point.) *)
val step :
  Theme.t ->
  Widget.input ->
  t ->
  view:('model -> 'msg element) ->
  update:('msg -> 'model -> 'model) ->
  'model ->
  t * 'model * Widget.paint list
