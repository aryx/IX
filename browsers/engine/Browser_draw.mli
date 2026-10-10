(* Browser_draw: a laid-out page (Html_layout) as the playground's
 * shapes -- the letters by Hershey's pen, the pictures by their pixels,
 * the rules and the list markers, the form controls in Motif's look
 * (Mosaic's and Netscape's toolkit on X), and, for an inspector, the
 * boxes outlined.
 *
 * The page's coordinates are the layout's, x right and y down from the
 * page's top; the shapes here are the same turned over (y up, a line
 * below the top negative), so that a browser moves the whole page into
 * its window and scrolls it with one move. Each thing drawn comes with
 * its top and bottom on the page ([drawn]), so that a frame shows only
 * what is in the window (culling).
 *
 * What the drawing needs to know that the layout does not, the browser
 * gives: which links were visited (purple), which pictures have come,
 * each control's value (the browser's, never the page's tree), and
 * which field has the keys (its caret).
 *
 * Motif's look is two colours on the edges of a grey rectangle, the
 * light taken to come from the top left: light edges above and on
 * the left and dark ones below and on the right make it stand out
 * ([raised]: a button, a table's frame), the other way round sink it
 * ([sunken]: a field, a table's cell).
 *
 *     raised                    sunken
 *     light light light dark    dark dark  dark  light
 *     light   grey      dark    dark   white     light
 *     light dark  dark  dark    dark light light light
 *
 * cs-history:
 * Mosaic and Netscape on Unix were Motif programs (the Open Software
 * Foundation's toolkit for X, 1989), and a page's buttons and fields
 * were Motif's own widgets set in the page. So a form looked like
 * the rest of the desktop, and differently on Windows and on the
 * Macintosh, where the same page got those systems' controls. The
 * bevel itself was the look of the years around 1990 (NeXTSTEP,
 * Motif, then Windows 95): a screen of few colours made to look
 * like pressed plastic with two more greys.
 *
 * modern:
 * A browser no longer asks the system for a page's controls: it
 * draws them itself, so that a style sheet can restyle them, and
 * the same page looks the same everywhere. That is what is done
 * here, for a simpler reason: there is no toolkit under the page,
 * only shapes. *)

(* things drawn, each with its top and bottom on the page *)
type drawn = (float * float * Playground.shape) list

(* a rectangle's outline, 1 thick (frame_thick: [t] thick), its
 * top-left at (x, y) of the page, [w] by [h] *)
val frame : Playground.color -> float -> float -> float -> float -> Playground.shape
val frame_thick : float -> Playground.color -> float -> float -> float -> float -> Playground.shape

(* Motif's two bevels, at (x, top), w by h: a raised thing (a button)
 * lit from the top left, a sunken one (a field) the other way *)
val raised : float -> float -> float -> float -> Playground.shape list

val sunken : float -> float -> float -> float -> Playground.shape list

(* a fragment's shapes: a word's letters (a link's in blue, purple if
 * [visited]), a picture ([picture_of] its src: arrived, the room kept,
 * the broken image; a link's framed in its colour); a control's are
 * [control_shapes]' *)
val glyphs :
  visited:(string -> bool) -> picture_of:(string -> Browser_picture.t option) -> Html_layout.fragment -> Playground.shape list

(* ix: the same for a fragment that is no link and no picture (a list's
 * marker, a control's text): it was glyphs without its two optional
 * arguments *)
val plain_glyphs : Html_layout.fragment -> Playground.shape list

(* the whole page but its controls: every line, float, rule and marker;
 * with [extensions], Netscape's <hr noshade> a flat bar and a
 * <table border>'s bevelled frames, the table raised, its cells
 * sunken *)
val draw :
  extensions:bool -> visited:(string -> bool) -> picture_of:(string -> Browser_picture.t option) -> Html_layout.box -> drawn

(* a control with its [value], its caret if [focused] *)
val control_shapes :
  value:(Dom.element -> Forms.value) -> focused:bool -> Html_layout.fragment -> Html_layout.control -> Playground.shape list

(* every control of the page, drawn with its value (every frame: they
 * change as one types, where the rest is drawn once a layout) *)
val controls_drawn : value:(Dom.element -> Forms.value) -> focus:Dom.element option -> Html_layout.box -> drawn

(* the layout's boxes outlined, as a browser's inspector does: blocks
 * blue, the anonymous boxes of inline content green, their lines grey *)
val outlines : Html_layout.box -> drawn
