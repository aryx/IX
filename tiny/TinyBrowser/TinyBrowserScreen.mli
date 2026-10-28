(* TinyBrowserScreen: what www shows, and its drawing. TinyBrowser.ml's
 * browsing (where to go, what came, the keys and the mouse) changes the
 * records below and calls these to show it; the messages they make are
 * the kernel's drawing messages (TinyLibDraw), kept in [sc_msgs] and
 * written at once by [send].
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
 * A line that arrives is drawn if it falls in the area; a scroll copies
 * what stays on the screen onto itself and draws only the strip that
 * comes in; a line cut by the area's edge is drawn in a strip image
 * first, then copied, so it never draws over the bar or the status.
 *
 * What is ours, against the twins: mini-netscape lays out boxes and
 * paints them into a framebuffer of its own (the engine's display);
 * here a page is lines of runs, each run a text at a column, drawn by
 * the kernel's text and fills, a picture's slice by a copy of its
 * image.
 *)

(* the colours, images of a pixel on the connection to the screen, and
 * the messages that make them *)
val c_white : int
val c_black : int
val c_link : int
val c_code : int
val c_rule : int
val c_text : int
val colours : string

(* What the screen shows. At the top, TinyLibGUI's bar of menus, with the
 * page's title, and a toolbar: Back, the address, Go. The last row
 * says how the reading goes, and the rows between show the page's
 * lines, scrolled by pixels (sc_y). A line that arrives is drawn if it
 * falls in the page's area.
 * A page is read from [nv_wire], the connection to the wire's other end,
 * -1 when the page is all there; [nv_history] holds the pages seen
 * before, each with the first line that was shown. Where the browsing
 * is (the nav) is a record of its own, as tiny-ml builds a record's
 * fields on its 11 registers. *)
type nav = {
  mutable nv_address : string;       (* the page's full address, without its
                                      * #fragment *)
  mutable nv_wire : int;
  mutable nv_history : (string * int) list;
  mutable nv_goal : int;             (* a line to show first once it has come
                                      * (back), or -1 *)
  mutable nv_goal_id : string;       (* an anchor to show once it has come
                                      * (#fragment), or "" *)
  mutable nv_pressed : bool;         (* the mouse's button is down *)
  mutable nv_fetch : int;            (* the picture [nv_wire] brings, or -1 for
                                      * the page *)
  mutable nv_hover : bool;           (* the mouse is over a link: its look is
                                      * a hand *)
}

(* the menus and the toolbar's, below the model as TinyLibGUI has them *)
type tools = {
  mutable tb_field : string;          (* the address, as shown or being typed *)
  mutable tb_mouse : TinyLibGUI.mouse; (* the field has the keys when
                                        * pressed in last *)
  tb_menu : TinyLibGUI.menu_state;
}

(* The document being read: HTTP's answer, its head first, then its
 * body, which goes by the head's Content-Type ([dc_type], "" until the
 * head has come): read as HTML, shown as a text, or kept in a file
 * ([dc_file]) for a program that shows it. *)
type doc = {
  mutable dc_got : int;              (* the bytes read so far *)
  mutable dc_head : string;          (* the head so far, until it ends *)
  mutable dc_type : string;
  mutable dc_status : int;           (* 200, or 0 when no head said *)
  mutable dc_file : int;             (* the file a helper's bytes go to, or
                                      * -1 *)
}

type screen = {
  mutable sc_page : TinyBrowserHtml.page;
  sc_nav : nav;
  sc_tools : tools;
  sc_cols : int;
  sc_rows : int;
  mutable sc_y : int;               (* the page's pixel at the top of its area *)
  mutable sc_drawn : int;           (* the lines before this one that are in
                                     * the area are drawn *)
  sc_doc : doc;
  mutable sc_state : string;        (* "reading", "done", or why there is no page *)
  mutable sc_msgs : string list;    (* drawing messages not yet written, last
                                     * first *)
}


(* What a menu's item or a button of the toolbar does ([act] below):
 * Typed is the toolbar's field, its text after a key *)
type act =
  | Back | Top | Reload | Quit | Address | Search | Go_to of string
  | Go_typed
  | Typed of string


(* a drawing message kept, to be written by [send] *)
val put : screen -> string -> unit

(* the menus: the page's, a few articles to go to, the pages seen *)
val menus : screen -> (string * (string * act) list) list

(* the messages kept written (a menu open drawn again over them) *)
val send : screen -> unit

(* a row filled with a colour *)
val fill_row : screen -> int -> int -> unit

(* where the page's area starts, how high it is *)
val area_top : int
val area : screen -> int

(* the strip a cut line is drawn in; a picture's image *)
val c_strip : int
val image_of : int -> int

(* the bar and its menus, the toolbar (its widgets, laid out: their
 * shapes and boxes), the status row *)
val draw_bar : screen -> unit
val laid_tools :
  screen ->
  TinyLibPlayground.shape list
  * ((int * int * int * int) * act TinyLibGUI.action) list
val draw_tools : screen -> unit
val draw_status : screen -> unit

(* the toolbar's field has the keys; given them, or not *)
val focused : screen -> bool
val focus : screen -> bool -> unit

(* the area drawn again; the page's last scroll position *)
val redraw : screen -> unit
val max_y : screen -> int

(* scrolled by pixels; a screenful seen moving; from a line on *)
val scroll_by : screen -> int -> unit
val glide : screen -> int -> unit
val show_from : screen -> int -> unit

(* the lines that arrived drawn, and a place asked for shown once it
 * has come *)
val show_new : screen -> unit

(* the mouse's look: a hand over a link *)
val hover : screen -> bool -> unit
