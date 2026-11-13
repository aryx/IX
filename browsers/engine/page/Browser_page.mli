(* Browser_page: a page, read and laid out. This is the whole pipeline
 * of the web engine (the modules of html, css and this directory) in
 * one place, from the bytes a server sent to the shapes a browser
 * shows:
 *
 *   bytes -Charset-> text -Html_lexer-> tokens -Html_tree-> tree
 *         -Cascade, Computed-> styles -Box_layout-> boxes
 *         -Browser_boxes-> shapes
 *
 * The page's style sheets are found and asked for on the way
 * ([sheets_wanted]: the browser fetches them, and the page is laid out
 * again). The boxes are also given as Html_layout's lines and
 * fragments, which is what comes after (Hit, Browser_forms, a script's
 * view of where an element is) reads.
 *
 * history: mini-chrome's first version had Mosaic's way beside it,
 * where each element's look came from the browser's own table (Looks)
 * and was laid out in one pass (Html_layout), with Knuth and Plass's
 * lines as an option. No page that mini-netscape reads used it, and it
 * went (2026-10-19, docs/plans/plan_browser.md, "Smaller"). It is
 * still in mini-chrome.
 *
 * A page keeps every stage (a browser's views show each one), and what
 * the person did to it: the values of its form controls, which are the
 * browser's, not the tree's.
 *
 * What the layout and the drawing need, and the page does not say, is
 * the browser's, given as [settings]: the page's width, which URLs were
 * visited (a link is then purple), and which pictures have come. A page
 * is laid out again when any of them changes (a reflow).
 *
 * The pages a browser writes itself are laid out like any other: a page
 * made for what is not HTML (text in <pre>, as Mosaic showed it), an
 * error, and a form's echo (what a server would read).
 *
 * In the system: this module does no input and no output. Tab, in
 * mini-netscape, fetches (with Http_client, over ix's own TLS and TCP),
 * gives the bytes here, and then fetches what the page wants: its
 * sheets, its pictures, its scripts (webapi's Browser_script, which
 * changes the tree and asks [with_tree] for the page again).
 *
 * design:
 * A pipeline of values. Each stage is a function from the one before,
 * and is kept in the record, so a view of the source, of the tokens or
 * of the tree costs nothing, a test checks one stage alone, and a
 * reflow is the last stages run again on the same tree. A compiler is
 * written the same way (characters, tokens, a tree, code), and a
 * browser is one whose target is a picture. What it costs is the work
 * done again: a real engine marks what a change made dirty and lays
 * out only that. *)

type t = {
  url : string; (* where it came from, after the redirections *)
  status : int; (* 200; 0 for a page that could not be had *)
  charset : Charset.t;
  bytes : int;
  lines : string list; (* the text, in UTF-8 with tabs expanded: its source *)
  tokens : Html_lexer.token list;
  tree : Dom.element;
  line_mode : Line_mode.t;
  title : string; (* the text of its <title>, or "" *)
  layout : Html_layout.box;
  drawn : Browser_draw.drawn; (* all but its controls, drawn once per layout *)
  background : Looks.color option; (* its canvas's: its root's or its body's background (CSS 2.1, 14.2) *)
  forms : Forms.form list;
  values : (Dom.element * Forms.value) list; (* the controls changed, by element (==) *)
  quirks : bool; (* no DOCTYPE: quirks mode (Computed.styles), by the box model *)
  backgrounds : string list; (* for the box model: the pictures of its boxes' background-image, as absolute URLs *)
}

type settings = {
  css : bool; (* honour the page's style sheets: <style>, <link>, style= *)
  width : float;
  visited : string -> bool; (* an absolute URL, with no #fragment *)
  picture : string -> Browser_picture.t option; (* an absolute URL *)
  sheet : string -> string option; (* a style sheet's text, once it has come (an absolute URL) *)
}

(* [read settings url status content_type bytes]: the page, through the
 * whole pipeline *)
val read : settings -> string -> int -> string option -> string -> t

(* the same tree laid out and drawn again: a reflow *)
val laid_out : settings -> t -> t

(* the page with another tree, laid out and drawn (its title, forms and
 * line mode too, but its source stays): what a script left
 * (Browser_script.tree) *)
val with_tree : settings -> t -> Dom.element -> t

(* for the box model, with its style sheets: the addresses of the sheets
 * that the page asks for and does not have yet ([settings.sheet]), to
 * fetch. They are its <link rel=stylesheet>s whose media= holds, and
 * the @imports of the sheets it has. The page is laid out again as
 * each one comes *)
val sheets_wanted : settings -> t -> string list

(* for the box model: an element's winning declarations
 * (Cascade.explain), as a developer tools' Styles pane shows them. Each
 * is (property, value, where it came from): where it came from is a
 * rule's selector and its sheet's name (its address, <style> n, or the
 * browser's), or an attribute, or style= *)
val explain : settings -> t -> Dom.element -> (string * string * string) list

(* a control's value now: as typed and clicked, or else as the page
 * gave it *)
val value_of : t -> Dom.element -> Forms.value

val with_value : t -> Dom.element -> Forms.value -> t

(* a response's media type: "text/html; charset=utf-8" is "text/html" *)
val media_type : string option -> string

(* a page that could not be had, laid out like any other, from its URL
 * and the reason *)
val error_html : string -> string -> string

(* a form's fields, as a server would read them: the method ("GET",
 * "POST") and what was sent, encoded (the query or the body), and
 * decoded too *)
val echo_html : string -> string -> string
