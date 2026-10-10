(* Browser_page: a page, read and laid out -- the whole pipeline of
 * the web engine (the modules of html, css and this directory) in
 * one place, from the bytes a server sent to the shapes a browser
 * shows:
 *
 *   bytes -Charset-> text -Html_lexer-> tokens -Html_tree-> tree
 *         -Looks, Html_layout-> boxes -Browser_draw-> shapes
 *
 * That last line is Mosaic's way; with [boxes] in the settings it is
 * CSS's, the page's style sheets found and asked for on the way
 * ([sheets_wanted]: the browser fetches, the page is laid out again):
 *
 *         -Cascade, Computed-> styles -Box_layout-> boxes
 *         -Browser_boxes-> shapes
 *
 * and both give Html_layout's boxes, lines and fragments, so that
 * what comes after (Hit, Browser_forms, a script's view of where an
 * element is) does not know which was taken.
 *
 * keeping every stage (a browser's views show each), and what the
 * person did to it: its form controls' values, the browser's, not the
 * tree's.
 *
 * What the layout and the drawing need that the page does not say is
 * the browser's, given as [settings]: the page's width, how lines are
 * broken, which URLs were visited (a link purple), which pictures have
 * come -- a page is laid out again when any of them changes (a reflow).
 *
 * And the pages a browser writes itself, laid out like any: what is not
 * HTML made one (text in <pre>, as Mosaic showed it), an error, a
 * form's echo (what a server would read).
 *
 * In the system: this module does no input and no output. Tab, in
 * mini-netscape, fetches (Http_client, over ix's own TLS and TCP),
 * gives the bytes here, and fetches again what the page then wants:
 * its sheets, its pictures, its scripts (webapi's Browser_script,
 * which changes the tree and asks [with_tree] for the page again).
 *
 * design:
 * A pipeline of values. Each stage is a function from the one before
 * and is kept in the record, so a view of the source, of the tokens
 * or of the tree costs nothing, a test checks one stage alone, and a
 * reflow is the last stages run again on the same tree. A compiler
 * is written the same way (characters, tokens, a tree, code), and a
 * browser is one whose target is a picture. What it costs is the
 * work done again: a real engine marks what a change made dirty and
 * lays out only that. *)

type t = {
  url : string; (* where it came from, after the redirections *)
  status : int; (* 200; 0 for a page that could not be had *)
  charset : Charset.t;
  bytes : int;
  lines : string list; (* the text, UTF-8, tabs expanded: its source *)
  tokens : Html_lexer.token list;
  tree : Dom.element;
  line_mode : Line_mode.t;
  title : string; (* the text of its <title>, or "" *)
  layout : Html_layout.box;
  drawn : Browser_draw.drawn; (* all but its controls, drawn once a layout *)
  background : Looks.color option; (* <body bgcolor=>, Netscape's; or its style sheets' *)
  forms : Forms.form list;
  values : (Dom.element * Forms.value) list; (* the controls changed, by element (==) *)
  quirks : bool; (* no DOCTYPE: quirks mode (Computed.styles), by the box model *)
  backgrounds : string list; (* by the box model: the pictures of its boxes' background-image, absolute URLs *)
}

type settings = {
  extensions : bool; (* Netscape's extensions to HTML honoured (Dtd.origin) *)
  css : bool; (* the page's style sheets honoured (Css): <style>, style= *)
  boxes : bool; (* laid out by CSS 2.1's box model (Box_layout, Browser_boxes): TinyChrome's *)
  width : float;
  breaker : Html_layout.breaker;
  visited : string -> bool; (* an absolute URL, no #fragment *)
  picture : string -> Browser_picture.t option; (* an absolute URL *)
  sheet : string -> string option; (* a style sheet's text, once it has come (an absolute URL): with [boxes] *)
}

(* Knuth and Plass's lines (Linebreak.optimal), ragged right as a
 * browser's are -- the spaces may stretch (a line may end short), not
 * shrink (it may not end past the edge) -- with the paragraph's first
 * real space for all (Linebreak's model has one): CSS's text-wrap:
 * pretty *)
val pretty : Html_layout.breaker

(* [read settings url status content_type bytes]: the page, through the
 * whole pipeline *)
val read : settings -> string -> int -> string option -> string -> t

(* the same tree laid out and drawn again: a reflow *)
val laid_out : settings -> t -> t

(* the page with another tree, laid out and drawn (its title, forms and
 * line mode too; its source stays): what a script left
 * (Browser_script.tree) *)
val with_tree : settings -> t -> Dom.element -> t

(* by the box model, with its style sheets: the addresses of the
 * sheets the page asks for and does not have yet ([settings.sheet]) --
 * its <link rel=stylesheet>s whose media= holds, and the @imports of
 * those it has, to fetch; the page laid out again as each comes *)
val sheets_wanted : settings -> t -> string list

(* by the box model: an element's winning declarations (Cascade.explain)
 * as (property, value, where it came from: a rule's selector and its
 * sheet's name -- its address, <style> n, the browser's -- an
 * attribute, style=), a developer tools' Styles pane *)
val explain : settings -> t -> Dom.element -> (string * string * string) list

(* a control's value now: as typed and clicked, else as the page gave
 * it *)
val value_of : t -> Dom.element -> Forms.value

val with_value : t -> Dom.element -> Forms.value -> t

(* a response's media type: "text/html; charset=utf-8" is "text/html" *)
val media_type : string option -> string

(* a page that could not be had, laid out like any: its URL, why *)
val error_html : string -> string -> string

(* a form's fields, as a server would read them: the method ("GET",
 * "POST") and what was sent, encoded (the query or the body), decoded
 * too *)
val echo_html : string -> string -> string
