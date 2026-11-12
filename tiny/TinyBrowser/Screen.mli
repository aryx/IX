(* Screen: what www shows, and how it is drawn. The browsing logic in
 * TinyBrowser.ml (where to go, what came, the keys and the mouse)
 * changes the records below and calls the functions here to show the
 * result. These functions make the kernel's drawing messages
 * (TinyLibDraw), which are kept in [sc_msgs] and written all at once by
 * [send].
 *
 *     +--------------------------------------------------+
 *     | Page  Go  History    the page's title            |  the bar: menus
 *     | [Back] [https://en.wikipedia.org/wiki/OCaml] [Go] |  the toolbar
 *     |--------------------------------------------------|  area_top
 *     | the page's lines, scrolled by pixels (sc_y):     |
 *     | line i at area_top + 16 i - sc_y                 |  [area sc] high
 *     |--------------------------------------------------|
 *     | 360 KB, 862 lines   space -: page, b: back, ...  |  the status row
 *     +--------------------------------------------------+
 *
 * Three rules keep the drawing cheap and clean:
 * - a line that arrives is drawn only if it falls in the area;
 * - a scroll copies what stays on the screen onto itself, and draws
 *   only the strip that comes in;
 * - a line cut by the area's edge is first drawn in a strip image, then
 *   copied, so it never draws over the bar or the status row.
 *
 * twin:
 * mini-netscape lays out boxes and paints them into a framebuffer of
 * its own (the engine's display). Here a page is lines of runs, each
 * run a text at a column, drawn with the kernel's text and fill
 * operations; a slice of a picture is drawn by copying from its image.
 *)

val c_white : int
val c_black : int
val c_link : int
val c_code : int
val c_rule : int
val c_text : int
val colours : string

(* [nv_history] holds the pages seen before, each with the first line
 * that was shown. The nav is a record of its own because tiny-ml builds
 * a record's fields in its 11 registers. *)

(* The connection to the wire's other end; it is Wire_off once the page
 * and all its pictures have come. *)
type wire = Wire_off | Wire_page of int | Wire_picture of int * int

type nav = {
  mutable nv_address : string;       (* the page's full address, without its
                                      * #fragment *)
  mutable nv_wire : wire;
  mutable nv_history : (string * int) list;
  mutable nv_goal : int option;      (* a line to show once it has come
                                      * (when going back) *)
  mutable nv_goal_id : string option; (* the same for a #fragment *)
  mutable nv_pressed : bool;         (* the mouse's button is down *)
  mutable nv_hover : bool;           (* the mouse is over a link, so the
                                      * cursor is a hand *)
}

type tools = {
  mutable tb_field : string;          (* the address, as shown or being typed *)
  mutable tb_mouse : TinyLibGUI.mouse; (* the field gets the keys when it
                                        * was the last thing pressed *)
  tb_menu : TinyLibGUI.menu_state;
}

(* HTTP's answer. By the Content-Type, the body is read as HTML, shown as
 * text, or kept in a file for a program that can show it. *)
type doc = {
  mutable dc_got : int;              (* the bytes read so far *)
  mutable dc_head : string;          (* the head so far, until it ends *)
  mutable dc_type : string option;   (* None until the head has come *)
  mutable dc_status : int option;
  mutable dc_file : int option;      (* the file a helper's bytes go to *)
}

(* Page_none says why there is no page. *)
type state =
  | Page_reading
  | Page_done
  | Page_none of string

type screen = {
  mutable sc_page : Html.page;
  sc_nav : nav;
  sc_tools : tools;
  sc_cols : int;
  sc_rows : int;
  mutable sc_y : int;               (* the page's pixel at the top of the
                                     * area *)
  mutable sc_drawn : int;           (* the lines before this one that are in
                                     * the area are drawn *)
  sc_doc : doc;
  mutable sc_state : state;
  mutable sc_msgs : string list;    (* drawing messages not yet written, last
                                     * first *)
}


(* What a menu item or a toolbar button does. Typed carries the toolbar
 * field's text after a key. *)
type act =
  | Back | Top | Reload | Quit | Address | Search | Go_to of string
  | Go_typed
  | Typed of string


(* Keeps a drawing message for [send] to write. *)
val put : screen -> string -> unit

val menus : screen -> (string * (string * act) list) list
val send : screen -> unit
val fill_row : screen -> int -> int -> unit
val area_top : int
val area : screen -> int
val c_strip : int
val image_of : int -> int

val draw_bar : screen -> unit
val laid_tools :
  screen -> TinyLibPlayground.shape list * act TinyLibGUI.boxes
val draw_tools : screen -> unit
val draw_status : screen -> unit

val focused : screen -> bool
val focus : screen -> bool -> unit
val redraw : screen -> unit
val max_y : screen -> int
val scroll_by : screen -> int -> unit
val glide : screen -> int -> unit
val show_from : screen -> int -> unit
val show_new : screen -> unit
val hover : screen -> bool -> unit
