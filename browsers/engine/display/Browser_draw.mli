(* Browser_draw: the words of a laid-out page (Html_layout's fragments)
 * drawn as the playground's shapes. The letters are drawn by Hershey's
 * pen, the pictures by their pixels, and the form controls in Motif's
 * look (Motif was the toolkit of Mosaic and Netscape on X). For an
 * inspector, the boxes can be outlined too. Browser_boxes draws CSS's
 * boxes around all this.
 *
 * The page's coordinates are the layout's: x goes right and y goes
 * down from the page's top. The shapes here are the same turned over
 * (y goes up, and a line below the top is negative), so that a browser
 * moves the whole page into its window, and scrolls it, with one move.
 * Each thing drawn comes with its top and bottom on the page ([drawn]),
 * so that a frame shows only what is in the window (culling).
 *
 * The browser gives what the drawing needs to know and the layout does
 * not: which links were visited (they are purple), which pictures have
 * come, the value of each control (which the browser keeps, never the
 * page's tree), and which field has the keys (it shows its caret).
 *
 * Motif's look is two colours on the edges of a grey rectangle, with
 * the light taken to come from the top left. Light edges above and on
 * the left and dark ones below and on the right make it stand out
 * ([raised]: a button, a table's frame); the other way round, they
 * sink it ([sunken]: a field, a table's cell).
 *
 *     raised                    sunken
 *     light light light dark    dark dark  dark  light
 *     light   grey      dark    dark   white     light
 *     light dark  dark  dark    dark light light light
 *
 * cs-history:
 * Mosaic and Netscape on Unix were Motif programs (Motif was the Open
 * Software Foundation's toolkit for X, 1989), and a page's buttons and
 * fields were Motif's own widgets set in the page. So a form looked
 * like the rest of the desktop, and looked different on Windows and on
 * the Macintosh, where the same page got those systems' controls. The
 * bevel itself was the look of the years around 1990 (NeXTSTEP, Motif,
 * then Windows 95): it made a screen of few colours look like pressed
 * plastic with two more greys.
 *
 * modern:
 * A browser no longer asks the system for a page's controls. It draws
 * them itself, so that a style sheet can restyle them and the same
 * page looks the same everywhere. That is what is done here too, for a
 * simpler reason: there is no toolkit under the page, only shapes. *)

(* a shape that is built when it is first asked for ([shape_of]), and
 * then kept.
 * opti: for a line of text. A letter is its pen's strokes, ten to
 * twenty shapes. Drawing a page used to build them for every letter of
 * every line, at each layout, though a window shows forty lines of the
 * page's thousand: for the Wikipedia article, this took 0.24 s of the
 * 0.4 s of a layout. A line's shapes are now built when a frame first
 * shows it (as in mini-chrome's Browser_draw.later, which uses a
 * Lazy.t; mini-ml has no Lazy). When [lazily] is false (draw=all), the
 * shapes are built at once, as before *)
type later

val later : (unit -> Playground.shape) -> later
val shape_of : later -> Playground.shape
val lazily : bool ref

(* things drawn, each with its top and bottom on the page *)
type drawn = (float * float * later) list

(* things whose shapes are built already *)
val ready : (float * float * Playground.shape) list -> drawn

(* a rectangle's outline, 1 thick (with frame_thick, [t] thick), with
 * its top left at (x, y) of the page, [w] by [h] *)
val frame : Playground.color -> float -> float -> float -> float -> Playground.shape
val frame_thick : float -> Playground.color -> float -> float -> float -> float -> Playground.shape

(* Motif's two bevels, at (x, top), w by h: a raised thing (a button)
 * is lit from the top left, and a sunken one (a field) the other way *)
val raised : float -> float -> float -> float -> Playground.shape list

val sunken : float -> float -> float -> float -> Playground.shape list

(* a fragment's shapes. A word gives its letters (a link's are blue, or
 * purple if [visited]). A picture is asked of [picture_of] by its src:
 * it is drawn if it has arrived, its room is kept while it waits, and
 * the broken image is drawn if it could not be had; a link's picture is
 * framed in the link's colour. A control's shapes are given by
 * [control_shapes] instead *)
val glyphs :
  visited:(string -> bool) -> picture_of:(string -> Browser_picture.t option) -> Html_layout.fragment -> Playground.shape list

(* ix: the same for a fragment that is no link and no picture (a list's
 * marker, a control's text). In mini-chrome this was glyphs called
 * without its two optional arguments *)
val plain_glyphs : Html_layout.fragment -> Playground.shape list

(* a control drawn with its [value], and with its caret if [focused].
 * For a text field or a password being edited, the part around the
 * caret is shown, with its selection ([editing] is the text, caret and
 * anchor of the field in focus) *)
val control_shapes :
  value:(Dom.element -> Forms.value) -> focused:bool ->
  editing:Text_field.t option -> Html_layout.fragment -> Html_layout.control -> Playground.shape list

(* every control of the page, drawn with its value. They are drawn at
 * every frame, because they change as one types, where the rest is
 * drawn once for each layout *)
val controls_drawn :
  value:(Dom.element -> Forms.value) -> focus:Dom.element option ->
  editing:Text_field.t option -> Html_layout.box -> drawn

(* the layout's boxes outlined, as a browser's inspector does: blocks
 * are blue, the anonymous boxes of inline content are green, and their
 * lines are grey *)
val outlines : Html_layout.box -> drawn
