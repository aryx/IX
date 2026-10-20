(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-netscape: Netscape Navigator's window (Mosaic Communications,
 * 1994) over an engine of today's kind: a page fetched (ix's own TLS),
 * read, its style sheets cascaded, its boxes laid out and drawn
 * (browsers/html, css, engine). Written for ix after the author's
 * mini-chrome's first window; the look is Netscape's: a grey toolbar
 * with its buttons, the Location field, the N, the status bar.
 *
 *   +--------------------------------------------------------------+
 *   | [Back] [Forward] [Reload] [Bookmarks] Location: [http:] [N]  |
 *   +--------------------------------------------------------------+
 *   | [a tab] [another], when there are two or more                |
 *   +--------------------------------------------------------------+
 *   |                                                              |
 *   |   the page                                                   |
 *   |                                                              |
 *   +--------------------------------------------------------------+
 *   | the link under the mouse, or what the last load said         |
 *   +--------------------------------------------------------------+
 *
 * A browser is two things: its chrome, here this file (the toolbar,
 * the field, the bar: each browser's own), and what turns an address
 * into a picture of a page, which is every module of browsers/ and
 * the network's under them. A page's way, from the address to the
 * window, and who does each step:
 *
 *   an address         typed in the Location field, a link's, a form's
 *      | Browser_url   made whole against the page's own
 *      | Http_client   its bytes asked for: HTTP on Tcp, https the
 *      |               same inside Tls_client's TLS 1.3; or a file,
 *      |               data:, about: (Tab's fetch)
 *   bytes
 *      | Charset       to UTF-8, by what the server and the page say
 *      | Html_lexer    tags and text
 *      | Html_tree     the tree, the page's mistakes repaired
 *   Dom.element <--.
 *      |           |   Browser_script: the page's scripts, run by
 *      |           '-- Js_eval on a copy of the tree, which they
 *      |               change; the tree taken back when they did
 *      | Css_syntax    the style sheets read: the browser's own
 *      |               (Ua_sheet), then the page's, each a fetch more
 *      | Cascade       for each element and property, the
 *      |               declaration that wins (Selectors)
 *      | Computed      a record of values an element, the inherited
 *      |               ones come down from its parent
 *   styles
 *      | Box_layout    CSS's boxes, each with its place and size
 *      |               (Flex_layout, Table_layout; a word's width is
 *      |               Browser_text's, a picture's Browser_picture's:
 *      |               Png, Jpeg, Gif, Svg)
 *   boxes ------------ Hit: the way back, from a point clicked to
 *      |               the link or the element there
 *      | Browser_boxes backgrounds, borders, words, pictures
 *   Playground's shapes
 *      | view, below   moved up by the scroll, scaled by the zoom,
 *      |               put under the toolbar
 *      | Playground_platform   SDL's window, or a file (the tests')
 *   pixels
 *
 * Browser_page is the middle of it in one call (read: from the bytes
 * to the shapes, every stage kept); Tab is a page and what is still
 * to fetch for it, and the pages before; this file is the window, a
 * program of the playground's kind: a model, an update a frame (the
 * keys and the mouse, a piece of the page fetched, the scripts'
 * timers), a view from the model to shapes. mini-lynx is the same
 * way cut short: from the tree straight to lines of text (Line_mode).
 *
 * The mouse: a click on a link follows it, on a field gives it the
 * keys, on a button sends its form; the wheel scrolls. The keys: the
 * arrows, Page Up and Down, Space, Home and End scroll; Backspace goes
 * back; in the Location field, an address or words typed and Enter, or
 * one of the pages it offers as one types (the history's, the
 * bookmarks': Places), taken by the arrows or a click. Ctrl and D keeps
 * the page in the bookmarks, which the Bookmarks button shows; Ctrl
 * and T opens a tab, Ctrl and W closes it, Ctrl and Tab goes to the
 * next, Ctrl and a click opens a link in one behind. Ctrl and +
 * (or =), Ctrl and -, Ctrl and the wheel zoom the page, Ctrl and 0
 * back to 100% (Browser_zoom: Chrome's steps, each site its own): the
 * page is laid out narrower and drawn scaled.
 *
 * The page is as wide as the window: the program asks the platform
 * for a screen that is the window's (Session's flag window; without a
 * window, the playground's 1000 units square), and the size is kept in
 * the profile. Nothing is fetched while the window draws
 * (plan_browser.md, decision 6): a page on its way is fetched a piece
 * between two frames (the page and its sheets, then a picture each),
 * the status bar saying which and the N turned white meanwhile. The
 * cursor is a hand over a link or a button, an I-beam over a field.
 * A page's scripts run (browsers/webapi over browsers/javascript:
 * mini-chrome's engine and DOM of today), their timers on the frame's
 * clock. What it does not show, a PDF file or a film of YouTube's, it
 * gives to a program beside it, Mosaic's helper applications
 * (Browser_helpers): ~/.mailcap's, the profile's, mini-page and mpv.
 *
 * What is ours: the name says the window's period, not the engine's
 * (plan_browser.md, decision 1). Netscape 1 had no style sheets and
 * no scripts; a Netscape faithful to it, over Mosaic's kind of layout
 * (Html_layout, which the engine still has), would not show a page
 * of today. Tabs are Mozilla's (2002) and the field's offers Netscape
 * 4's and Chrome's, not Navigator 1's; a page's work on a worker beside
 * the window, Back to a page kept whole (Tab), as browsers of today;
 * no cache, a page's requests one after the other, a tab not shown
 * waiting.
 *
 * cs-history:
 * Netscape was Mosaic's authors' second browser. Marc Andreessen and
 * Eric Bina wrote Mosaic at the NCSA, University of Illinois (1993):
 * the browser with pictures in the page that made the web known. In
 * 1994 Andreessen and Jim Clark, the founder of Silicon Graphics,
 * started Mosaic Communications, hired several of Mosaic's
 * programmers, and wrote a new browser from nothing; the university
 * objected to the name, and company and browser became Netscape
 * (Navigator 1.0, December 1994). Within two years it brought most
 * of what a page still relies on: a page shown while it arrives,
 * several connections at once, SSL (https), cookies, tables, frames,
 * and JavaScript (Navigator 2).
 *
 * evolution:
 * The engines, from Netscape's to today's. Microsoft's Internet
 * Explorer (1995), given with Windows, took Netscape's users: the
 * browser wars. Netscape published its source in 1998 (Mozilla, its
 * old code name) and was bought by AOL; its engine was written
 * again as Gecko, which is Firefox's (2004). The KDE project's
 * KHTML (begun in 1998) became Apple's WebKit for Safari (2003), and Google's
 * Chrome (2008) was built on WebKit, forked as Blink in 2013. The
 * pipeline drawn above, a tree, a cascade, boxes, then painting, is
 * the one those engines share; what they add is doing it again for
 * the part of a page that changed only, on several threads and
 * processes, with the graphics processor.
 *
 * why-study:
 * A browser is today's largest program most people run, tens of
 * millions of lines, and a second operating system on top of the
 * first: it loads programs from the network, isolates them from one
 * another (Cors), schedules them (Event_loop), gives them storage
 * and a screen. Small, it can be read whole, and it is where the
 * rest of ix meets: the network's stack and its cryptography, the
 * pictures' decoders, a parser and an interpreter, a layout and a
 * window.
 *
 * References: plan_browser.md (the stages, what was copied and what
 * was cut). Pavel Panchekha and Chris Harrelson, "Web Browser
 * Engineering" (browser.engineering): a browser built chapter by
 * chapter, the same pipeline. Tali Garsiel and Paul Irish, "How
 * Browsers Work" (2011): WebKit's and Gecko's seen from above.
 *
 * usage: mini-netscape [-v] [url=address] [worker=wait|off] [scripts=off] [console=on] [strict=on] [helpers=off] [keep=off] [settle=off] [draw=all] [view=each] [profile=dir|off] [window=WxH]
 *   (a file's path is an address; worker: the window waits for each
 *   piece of a page the worker does (the tests'), or does them itself,
 *   where they are done beside it (The worker, below); console=on: what the page's scripts
 *   print, and their errors, on the standard error; strict=on: a
 *   script that does not parse refused whole, a DOM method missing a
 *   TypeError, where they are passed over with a warning; helpers=off:
 *   no program run for what the browser does not show; keep=off: a
 *   connection a request; profile: where the cookies and the zooms are
 *   kept, the history and the bookmarks too, ~/.config/mini-netscape if
 *   not said, off for nowhere; window:
 *   the window's size at first, the one it had last if not said; -v:
 *   the files read and written, the addresses fetched and what came,
 *   the programs run, on the standard error) *)

module P = Playground

type caps = < Cap.network; Cap.open_in; Cap.open_out; Cap.env; Cap.stderr; Cap.fork; Cap.exec; Cap.wait >

(* the browser's own first page *)
let home =
  "<!doctype html><title>mini-netscape</title>
<h1>mini-netscape</h1>
<p>A small browser of <b>ix</b>: HTML, style sheets, and the network over ix's own TLS 1.3.
<p>Click in the Location field, type an address, press Enter. Some to try:
<ul>
<li><a href=\"https://en.wikipedia.org/wiki/OCaml\">en.wikipedia.org/wiki/OCaml</a>
<li><a href=\"https://news.ycombinator.com/\">news.ycombinator.com</a>
<li><a href=\"http://example.com/\">example.com</a>
</ul>
<p>The arrows, Page Up and Down, Space and the wheel scroll; Backspace goes back.
<p>Ctrl+D keeps the page in the Bookmarks; Ctrl+T opens a tab, Ctrl+W closes it, Ctrl+Tab goes to the next, Ctrl and a click opens a link in one."

(* the history and the bookmarks as the window has them now, for their
 * pages (a tab asks for an about: page by its name alone) *)
let places_now : Places.t ref = ref Places.empty

let about (name : string) : string option =
  match name with
  | "home" -> Some home
  | "blank" -> Some ""
  | "history" -> Some (Places.history_page !places_now)
  | "bookmarks" -> Some (Places.bookmarks_to_html !places_now)
  | _ -> None

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

type model = {
  tab : Tab.t; (* the tab shown *)
  left : Tab.t list; (* the tabs before it, the nearest first *)
  right : Tab.t list; (* and after it *)
  blank : Tab.t; (* a tab with no page, the browser's settings: a new one *)
  places : Places.t; (* the history and the bookmarks *)
  choice : int; (* the Location field's offer chosen by the arrows, -1 none *)
  piece : int option; (* the tab's piece on the worker that the window waits for (Worker) *)
  later : (Tab.t -> Tab.t) list; (* what was done to the page meanwhile, to do when it is back, the last first *)
  location : string; (* the field's text *)
  editing : bool; (* the Location field has the keys *)
  fresh : bool; (* just clicked: the first character typed replaces the address *)
  before : string list; (* the keys held at the frame before, of those below *)
  cursor : P.cursor; (* the one last asked of the platform *)
  zooms : Browser_zoom.t; (* the sites zoomed (Ctrl and +, -, 0) *)
  console : int option; (* console=on: how many of the scripts' lines were said *)
  jar : Cookie_jar.t; (* the cookies, the tab's too *)
  profile : string option; (* the directory they and the zooms are kept in, if any *)
  window : (int * int) option; (* the window's size, once it is not the playground's square *)
  kept : Browser_profile.t * int * Places.t; (* what its files have: the preferences, the jar as it was written (its changes), the places *)
}

(* the keys that do something once, when they go down *)
let once = [ "ArrowDown"; "ArrowUp"; "PageDown"; "PageUp"; "Home"; "End"; "Enter"; "Backspace"; "Escape"; "space"; "="; "+"; "-"; "0"; "t"; "w"; "d"; "Tab" ]

(*****************************************************************************)
(* The window's places, x right and y down from its top left *)
(*****************************************************************************)

let toolbar_height = 44.
let status_height = 22.
(* (Stop: only while something is on its way, greyed otherwise, as Netscape's) *)
let buttons = [ ("Back", 8., 60.); ("Forward", 74., 84.); ("Reload", 164., 72.); ("Stop", 242., 56.); ("Bookmarks", 304., 96.) ]
let location_x = 408.
let field_x = 490.
let field_width (width : float) : float = width -. field_x -. 60.
let inside (x, y) (bx, by, bw, bh) = x >= bx && x <= bx +. bw && y >= by && y <= by +. bh
let grey = P.rgb 192 192 192
let look : Looks.t = { Browser_text.root_look with size = 13. }

(* the tabs' strip under the toolbar, when there are two or more
 * (Mozilla's way), and the page under it *)
let strip_height = 24.
let tabs (m : model) : Tab.t list = List.rev_append m.left (m.tab :: m.right)
let top (m : model) : float = if m.left = [] && m.right = [] then toolbar_height else toolbar_height +. strip_height
let tab_width (width : float) (m : model) : float = Float.min 200. (width /. float_of_int (List.length (tabs m)))
let title (t : Tab.t) : string = match Tab.page t with Some p when p.title <> "" -> p.title | _ -> Tab.url t

(* what the Location field offers under it as one types (Places), a row each *)
let offer_height = 22.
let offers (m : model) : Places.place list = if m.editing && not m.fresh then Places.matches m.places m.location else []

(* a rectangle and a text, by their top left and their baseline *)
let box (color : P.color) (x : float) (y : float) (w : float) (h : float) : P.shape =
  P.move (x +. (w /. 2.)) (-.(y +. (h /. 2.))) (P.rectangle color w h)

let text_in (look : Looks.t) (s : string) (x : float) (baseline : float) : P.shape list =
  Browser_draw.plain_glyphs { text = s; look; x; width = Browser_text.metrics look s; baseline; picture = None; control = None; element = Dom.element "span" [] }

let text (s : string) (x : float) (baseline : float) : P.shape list = text_in look s x baseline
let greyed : Looks.t = { look with color = (140, 140, 140) }

(* a text cut to what fits in [room], its end kept (an address typed) or its start *)
let fitted ~(keep_end : bool) (s : string) (room : float) : string =
  let rec cut s = if s = "" || Browser_text.metrics look s <= room then s else cut (if keep_end then String.sub s 1 (String.length s - 1) else String.sub s 0 (String.length s - 1)) in
  cut s

(*****************************************************************************)
(* Update *)
(*****************************************************************************)

(* the address of the page shown, or, before one came, of the one asked
 * for: while a link's page is on its way, Tab.url is already its *)
let shown_url (m : model) : string = match Tab.page m.tab with Some p -> p.url | None -> Tab.url m.tab

(* the site the page is of, for its zoom; "file" for what is not from
 * the network (a file's first directory would be read as a host). The
 * page shown's: the one asked for's, the page zoomed in was drawn at
 * the other site's zoom (100%) between a click and the next page *)
let host (m : model) : string = match Url.parse (shown_url m) with Ok { scheme = Some ("http" | "https"); authority = Some a; _ } -> a.host | _ -> "file"
let zoom (m : model) : float = Browser_zoom.of_host m.zooms (host m)

(* the page laid out at the window's width divided by its zoom *)
let fitted_tab (width : float) (m : model) : model = { m with tab = Tab.resized (width /. zoom m) m.tab }

let zoomed (width : float) (change : Browser_zoom.change) (m : model) : model =
  fitted_tab width { m with zooms = Browser_zoom.with_host m.zooms (host m) (Browser_zoom.apply change (zoom m)) }

(* (the piece on the worker, if one is, given up: the tab is another, or
 * asked for another page) *)
let shown (m : model) : model = { m with location = Tab.url m.tab; editing = false; fresh = false; choice = -1; piece = None; later = [] }

(* the tab at [i] shown, the others around it *)
let select (i : int) (m : model) : model =
  let all = tabs m in
  if i < 0 || i >= List.length all then m
  else shown { m with tab = List.nth all i; left = List.rev (List.filteri (fun j _ -> j < i) all); right = List.filteri (fun j _ -> j > i) all }

(* the one after it shown, or before if it was the last; the last tab stays *)
let closed (m : model) : model =
  match (m.right, m.left) with
  | t :: right, _ -> shown { m with tab = t; right }
  | [], t :: left -> shown { m with tab = t; left }
  | [], [] -> m

(* a page come is in the history (not the browser's own, nor data:) *)
let remembered (m : model) : model =
  let url = Tab.url m.tab in
  match Tab.page m.tab with
  | Some p when (not (Tab.busy m.tab)) && not (Browser_url.starts_with "about:" url || Browser_url.starts_with "data:" url) -> (
      match m.places.history with q :: _ when q.url = url -> m | _ -> { m with places = Places.visited m.places { url; title = p.title } })
  | _ -> m

(*****************************************************************************)
(* The worker *)
(*****************************************************************************)

(* the tab's pieces done by a worker beside the window (Tab_worker),
 * the window keeping its copy: what comes back merged with it *)
let give (caps : < caps; .. >) (m : model) : model = { m with piece = Some (Tab_worker.give caps m.tab) }

(* the tab a piece made, the window's (a page come of another site laid
 * out at its zoom before it is drawn) *)
let came (width : float) (m : model) (tab : Tab.t) : model =
  fitted_tab width (remembered { m with tab; location = (if m.editing then m.location else Tab.url tab) })

(* the worker's piece, if it is done: the window's if it waits for it,
 * merged with its copy and what was kept for later done; else dropped *)
let collected (width : float) (m : model) : model =
  match Tab_worker.take () with
  | None -> m
  | Some (n, r) -> (
      match r with
      | _ when m.piece <> Some n -> m
      | Error e -> raise e
      | Ok tab -> came width { m with piece = None; later = [] } (List.fold_right (fun f t -> f t) m.later (Tab.merged ~window:m.tab tab)))

(* the piece of the tab shown, waited for: before another tab is shown
 * (given up, a piece running the page's scripts would be run again
 * when the tab is back) *)
let finished (width : float) (m : model) : model =
  if m.piece = None then m
  else
    let was = !Tab_worker.working in
    Tab_worker.working := Tab_worker.Waited;
    let m = collected width m in
    Tab_worker.working := was;
    m

(* the page's own (its scripts, its fields): now, or when the piece out is done *)
let on_page (m : model) (f : Tab.t -> Tab.t) : model = if Tab_worker.out () then { m with later = f :: m.later } else shown { m with tab = f m.tab }

(* was the window drawn (the view taken) since the last piece fetched?
 * A piece is a second sometimes, and a platform then owes several
 * updates before it draws again: without this they would each fetch
 * one, the window still and what it says old all the while *)
let seen = ref true

(* the cursor for a place of the window: a hand over what a click
 * follows or presses, the I-beam over what is typed in *)
let cursor_at (width : float) (height : float) (m : model) ((x, y) : float * float) : P.cursor =
  let z = zoom m in
  if y < toolbar_height then
    if List.exists (fun (_, bx, w) -> inside (x, y) (bx, 8., w, 28.)) buttons then P.Hand
    else if inside (x, y) (field_x, 8., field_width width, 28.) then P.Text
    else P.Arrow
  else if y < top m || inside (x, y) (field_x, toolbar_height -. 8., field_width width, offer_height *. float_of_int (List.length (offers m))) then P.Hand
  else if y < height -. status_height then
    match Tab.under m.tab ~x:(x /. z) ~y:(((y -. top m) /. z) +. Tab.scroll m.tab) with
    | Tab.Link _ | Tab.Button -> P.Hand
    | Tab.Field -> P.Text
    | Tab.Nothing -> P.Arrow
  else P.Arrow

(* the profile's files written, if what they hold has changed: the
 * zooms at once, the cookies when the page has come (a page sets them
 * at each of its files) *)
let saved (caps : < caps; .. >) (m : model) : model =
  match m.profile with
  | None -> m
  | Some dir -> (
      let preferences, cookies, places = m.kept in
      let now : Browser_profile.t = { preferences with zooms = m.zooms; window = m.window } in
      let changes = Cookie_jar.changes m.jar in
      let wrote =
        if now <> preferences then Some (Browser_profile.save caps ~dir now, (now, cookies, places))
        else if changes <> cookies && not (Tab.busy m.tab) then Some (Browser_profile.save_cookies caps ~dir (Cookie_jar.cookies m.jar), (preferences, changes, places))
        else if m.places != places then Some (Browser_profile.save_places caps ~dir ~was:places m.places, (preferences, cookies, m.places))
        else None
      in
      match wrote with
      | None -> m
      | Some (Ok (), kept) -> { m with kept }
      | Some (Error why, _) ->
          Console.eprint caps (Printf.sprintf "mini-netscape: the profile is not kept: %s\n" why);
          { m with profile = None })

let update_window (caps : < caps; .. >) (computer : P.computer) (m : model) : model =
  let screen = computer.screen and mouse = computer.mouse and keys = computer.keyboard in
  places_now := m.places;
  let visible = screen.height -. top m -. status_height in
  (* the window's size, for the profile: once it is its own (the screen
   * follows the window, the flag window; a picture's square is not kept) *)
  let m =
    let size = (int_of_float screen.width, int_of_float screen.height) in
    if m.window = None && size = (int_of_float P.default_width, int_of_float P.default_height) then m else { m with window = Some size }
  in
  let held = List.filter (fun k -> Set_.mem k keys.keys) once in
  let pressed k = List.mem k held && not (List.mem k m.before) in
  let m = { m with before = held } in
  (* a piece of the page on its way, fetched: the frame before said so *)
  let control = Set_.mem "Control" keys.keys in
  (* (a page of another site has its site's zoom: its width, before it is read) *)
  let m = fitted_tab screen.width m in
  let m =
    if !Tab_worker.working = Tab_worker.Inline then
      if Tab.busy m.tab && !seen then (seen := false; came screen.width m (Tab.step caps m.tab)) else m
    else
      let m = collected screen.width m in
      if Tab.busy m.tab && not (Tab_worker.out ()) && (!Tab_worker.working = Tab_worker.Beside || !seen) then (seen := false; collected screen.width (give caps m)) else m
  in
  (* the page's timers, on the frame's clock (not while its scripts are
   * the worker's); its Date, from the time it is *)
  let (P.Time now) = computer.time in
  let m = { m with tab = (if Tab_worker.out () then Tab.at (Float.round (now *. 1000.)) m.tab else Tab.advance (1000. /. 60.) (Tab.at (Float.round (now *. 1000.)) m.tab)) } in
  let m =
    match m.console with
    | None -> m
    | Some said ->
        let lines = Tab.console m.tab in
        List.iteri (fun i line -> if i >= said then Console.eprint caps (line ^ "\n")) lines;
        { m with console = Some (List.length lines) }
  in
  (* the mouse, in the window's coordinates *)
  let at = (mouse.mx -. screen.left, screen.top -. mouse.my) in
  let m =
    let wanted = cursor_at screen.width screen.height m at in
    if wanted = m.cursor then m
    else begin
      Playground_platform.set_cursor wanted;
      { m with cursor = wanted }
    end
  in
  let m =
    if mouse.mwheel = 0. then m
    else if control then zoomed screen.width (if mouse.mwheel > 0. then Browser_zoom.Up else Browser_zoom.Down) m
    else { m with tab = Tab.scrolled (-.mouse.mwheel *. 60. /. zoom m) ~visible:(visible /. zoom m) m.tab }
  in
  let m =
    if not mouse.mclick then m
    else if snd at < toolbar_height then
      match List.find_opt (fun (_, x, w) -> inside at (x, 8., w, 28.)) buttons with
      | Some ("Back", _, _) -> shown { m with tab = Tab.back m.tab }
      | Some ("Forward", _, _) -> shown { m with tab = Tab.forward m.tab }
      | Some ("Reload", _, _) -> shown { m with tab = Tab.reload m.tab }
      | Some ("Stop", _, _) -> if Tab.busy m.tab then shown { m with tab = Tab.stop m.tab } else m
      | Some (_, _, _) -> shown { m with tab = Tab.visit m.tab "about:bookmarks" }
      | None -> if inside at (field_x, 8., field_width screen.width, 28.) then { m with editing = true; fresh = true } else { m with editing = false }
    else
      (* an offer of the Location field, under it; a tab of the strip; the page *)
      let row = int_of_float ((snd at -. (toolbar_height -. 8.)) /. offer_height) in
      match List.nth_opt (offers m) (max 0 row) with
      | Some p when inside at (field_x, toolbar_height -. 8., field_width screen.width, offer_height *. float_of_int (List.length (offers m))) -> shown { m with tab = Tab.visit m.tab p.url }
      | _ ->
          if snd at < top m then select (int_of_float (fst at /. tab_width screen.width m)) (finished screen.width m)
          else if snd at < screen.height -. status_height then
            let x = fst at /. zoom m and y = ((snd at -. top m) /. zoom m) +. Tab.scroll m.tab in
            (* Ctrl and a click: the link in a tab of its own, behind *)
            match Tab.link_at m.tab ~x ~y with
            | Some url when control -> { m with right = Tab.visit m.blank url :: m.right }
            | _ -> on_page m (fun t -> Tab.click t ~x ~y)
          else m
  in
  let change = if control then List.find_map (fun k -> if pressed k then Browser_zoom.key k else None) [ "="; "+"; "-"; "0" ] else None in
  let command = if control then List.find_opt pressed [ "t"; "w"; "d"; "Tab" ] else None in
  if change <> None then match change with Some c -> zoomed screen.width c m | None -> m
  else if command <> None then
    let m = if command = Some "d" then m else finished screen.width m in
    match command with
    | Some "t" -> { m with left = m.tab :: m.left; tab = Tab.visit m.blank "about:blank"; location = ""; editing = true; fresh = false; choice = -1; piece = None; later = [] }
    | Some "w" -> closed m
    | Some "Tab" -> select ((List.length m.left + 1) mod List.length (tabs m)) m
    | _ -> (
        match Tab.page m.tab with
        | Some p when not (Browser_url.starts_with "about:" p.url) -> { m with places = Places.bookmarked m.places { url = p.url; title = p.title } }
        | _ -> m)
  else if m.editing then
    let m = if keys.typed <> "" && not control then { m with location = (if m.fresh then "" else m.location) ^ keys.typed; fresh = false; choice = -1 } else m in
    let offered = offers m in
    if pressed "Enter" then
      let chosen = if m.choice >= 0 then List.nth_opt offered m.choice else None in
      shown { m with tab = Tab.visit m.tab (match chosen with Some p -> p.url | None -> Places.destination m.location) }
    else if pressed "ArrowDown" then { m with choice = min (m.choice + 1) (List.length offered - 1) }
    else if pressed "ArrowUp" then { m with choice = max (m.choice - 1) (-1) }
    else if pressed "Backspace" then { m with location = (if m.fresh || m.location = "" then "" else String.sub m.location 0 (String.length m.location - 1)); fresh = false; choice = -1 }
    else if pressed "Escape" then { m with location = Tab.url m.tab; editing = false; fresh = false; choice = -1 }
    else m
  else if Tab.focus m.tab <> None then
    let typed = keys.typed in
    let m = if typed <> "" then { (on_page m (fun t -> Tab.typed t typed)) with location = m.location } else m in
    if pressed "Enter" then on_page m (fun t -> Tab.key t "enter")
    else if pressed "Backspace" then { (on_page m (fun t -> Tab.key t "backspace")) with location = m.location }
    else m
  else
    let by d = { m with tab = Tab.scrolled (d /. zoom m) ~visible:(visible /. zoom m) m.tab } in
    if pressed "ArrowDown" then by 40.
    else if pressed "ArrowUp" then by (-40.)
    else if pressed "PageDown" || pressed "space" then by (visible -. 40.)
    else if pressed "PageUp" then by (-.(visible -. 40.))
    else if pressed "Home" then by (-1e9)
    else if pressed "End" then by 1e9
    else if pressed "Backspace" then shown { m with tab = Tab.back m.tab }
    else if pressed "Escape" && Tab.busy m.tab then shown { m with tab = Tab.stop m.tab }
    else m

(*****************************************************************************)
(* View *)
(*****************************************************************************)

(* Netscape's N: white on the dark blue of its night sky; while a page
 * is on its way, meteors falling across it (Navigator's throbber,
 * 1994 on), at [phase], a twelfth of a second each.
 * old: inverted, dark on white, while busy: not seen as busy *)
let meteors = 18

let logo ~(phase : int option) (x : float) (y : float) : P.shape list =
  let style : Style.t = { bold = true; italic = false; underline = false; strike = false; size = 26. } in
  let sky = P.rgb 0 0 96 and white = P.rgb 255 255 255 in
  (* three on parallel paths, from the top right to the bottom left,
   * a third of the way apart, a streak along its way *)
  let falling (k : int) : P.shape list =
    List.map
      (fun i ->
        let t = float_of_int ((k + (i * meteors / 3)) mod meteors) /. float_of_int meteors in
        let along = (t *. 24.) -. 12. and aside = float_of_int ((i - 1) * 10) in
        let cx = x +. 18. +. ((aside -. along) *. 0.7) and cy = y +. 18. +. ((aside +. along) *. 0.7) in
        P.rectangle (P.rgb 255 255 200) 7. 1.5 |> P.rotate 45. |> P.move cx (-.cy))
      [ 0; 1; 2 ]
  in
  (box sky x y 36. 36. :: Stroke_text.glyph white style "N" ~x:(x +. 9.) ~baseline:(-.(y +. 27.)))
  @ match phase with Some k -> falling k | None -> []

(* the status bar's progress: the pieces done of those known, Netscape's
 * thermometer *)
let progress_bar (x : float) (y : float) ((done_, known) : int * int) : P.shape list =
  let w = 100. and h = 10. in
  let filled = if known = 0 then 0. else w *. float_of_int done_ /. float_of_int known in
  Browser_draw.sunken x y w h @ if filled > 2. then [ box (P.rgb 0 0 128) (x +. 1.) (y +. 1.) (filled -. 2.) (h -. 2.) ] else []

(* the throbber's place in its fall, by the frame's clock, while busy *)
let phase (computer : P.computer) (m : model) : int option =
  let (P.Time now) = computer.time in
  if Tab.busy m.tab then Some (int_of_float (now *. 12.) mod meteors) else None

(* the window's shapes, from all that they are made of *)
let view_simple (computer : P.computer) (m : model) (over : string option) : P.shape list =
  let screen = computer.screen in
  let width = screen.width and height = screen.height in
  let top = top m in
  let visible = height -. top -. status_height in
  let scroll = Tab.scroll m.tab and z = zoom m in
  (* the page: what of it is in the window, its top left under the toolbar *)
  let page =
    match Tab.page m.tab with
    | None -> []
    | Some p ->
        let controls = Browser_draw.controls_drawn ~value:(Browser_page.value_of p) ~focus:(Tab.focus m.tab) p.layout in
        let seen = List.filter_map (fun (top, bottom, shape) -> if bottom > scroll && top < scroll +. (visible /. z) then Some (Browser_draw.shape_of shape) else None) (p.drawn @ controls) in
        let r, g, b = match p.background with Some c -> c | None -> (255, 255, 255) in
        [ box (P.rgb r g b) 0. top width visible; P.move 0. (-.top) (P.scale z (P.move 0. scroll (P.group seen))) ]
  in
  let toolbar =
    box grey 0. 0. width toolbar_height
    :: box (P.rgb 96 96 96) 0. (toolbar_height -. 1.) width 1.
    :: List.concat_map
         (fun (name, x, w) ->
           let l = if name = "Stop" && not (Tab.busy m.tab) then greyed else look in
           Browser_draw.raised x 8. w 28. @ text_in l name (x +. ((w -. Browser_text.metrics look name) /. 2.)) 27.)
         buttons
    @ text "Location:" location_x 27.
    @ Browser_draw.sunken field_x 8. (field_width width) 28.
    @ [ box (P.rgb 255 255 255) (field_x +. 2.) 10. (field_width width -. 4.) 24. ]
    @ text (fitted ~keep_end:m.editing (m.location ^ if m.editing then "|" else "") (field_width width -. 12.)) (field_x +. 6.) 27.
    @ logo ~phase:(phase computer m) (width -. 46.) 4.
  in
  (* the tabs, the one shown white as its page *)
  let strip =
    if top = toolbar_height then []
    else
      let w = tab_width width m in
      box grey 0. toolbar_height width strip_height
      :: List.concat
           (List.mapi
              (fun i t ->
                let x = float_of_int i *. w in
                (if i = List.length m.left then Browser_draw.sunken else Browser_draw.raised) x toolbar_height w strip_height
                @ text (fitted ~keep_end:false (title t) (w -. 12.)) (x +. 6.) (toolbar_height +. 17.))
              (tabs m))
  in
  (* the Location field's offers, the chosen one blue *)
  let offered =
    List.concat
      (List.mapi
         (fun i (p : Places.place) ->
           let y = toolbar_height -. 8. +. (float_of_int i *. offer_height) in
           box (if i = m.choice then P.rgb 200 210 255 else P.rgb 255 255 255) field_x y (field_width width) offer_height
           :: text (fitted ~keep_end:false (if p.title = "" then p.url else p.title ^ " -- " ^ p.url) (field_width width -. 12.)) (field_x +. 6.) (y +. 16.))
         (offers m))
  in
  (* the status bar: where the link under the mouse goes, or what the last load said *)
  let status =
    box grey 0. (height -. status_height) width status_height
    :: box (P.rgb 96 96 96) 0. (height -. status_height) width 1.
    :: text (fitted ~keep_end:false (match over with Some link when not (Tab.busy m.tab) -> link | _ -> Tab.said m.tab) (width -. if Tab.busy m.tab then 190. else 80.)) 8. (height -. 6.)
    @ (if Tab.busy m.tab then progress_bar (width -. 170.) (height -. 16.) (Tab.pieces m.tab) else [])
    (* the zoom, when it is not 100% *)
    @ text (Browser_zoom.label z) (width -. 50.) (height -. 6.)
  in
  [ P.move screen.left screen.top (P.group (page @ toolbar @ strip @ status @ offered)) ]

(* opti: the shapes of the frame before given back, the very list,
 * when nothing they are made of has changed: the platform then draws
 * nothing (Redraw compares a frame's shapes with the last one's, and
 * two that are the same block of memory at once). A window at rest
 * on the Wikipedia article was 1.9 ms a frame, the page's shapes in
 * view listed again and compared (mini-chrome's Window_view.view).
 * old: view_simple at each frame; view=each is that way again *)
type shown = {
  page : Browser_page.t option;
  scroll : float;
  focus : Dom.element option;
  said : string;
  busy : bool;
  field : string * bool;
  zoom : float;
  size : float * float * float * float;
  over : string option;
  titles : string list * int; (* the tabs', the one shown *)
  offer : Places.place list * int; (* the Location field's, the one chosen *)
  phase : int option; (* the throbber's *)
  pieces : int * int;
}

let memo : bool ref = ref true
let last : (shown * P.shape list) option ref = ref None

let view (computer : P.computer) (m : model) : P.shape list =
  seen := true;
  let screen = computer.screen in
  let z = zoom m in
  let over =
    let x = computer.mouse.mx -. screen.left and y = screen.top -. computer.mouse.my in
    if y > top m && y < screen.height -. status_height then Tab.link_at m.tab ~x:(x /. z) ~y:(((y -. top m) /. z) +. Tab.scroll m.tab) else None
  in
  let now =
    { page = Tab.page m.tab; scroll = Tab.scroll m.tab; focus = Tab.focus m.tab; said = Tab.said m.tab; busy = Tab.busy m.tab; field = (m.location, m.editing); zoom = z;
      size = (screen.width, screen.height, screen.left, screen.top); over;
      titles = ((if m.left = [] && m.right = [] then [] else List.map title (tabs m)), List.length m.left); offer = (offers m, m.choice); phase = phase computer m; pieces = Tab.pieces m.tab }
  in
  let same (a : shown) (b : shown) : bool =
    (match (a.page, b.page) with Some p, Some q -> p == q | None, None -> true | _ -> false)
    && (match (a.focus, b.focus) with Some e, Some f -> e == f | None, None -> true | _ -> false)
    && a.scroll = b.scroll && a.said = b.said && a.busy = b.busy && a.field = b.field && a.zoom = b.zoom && a.size = b.size && a.over = b.over && a.titles = b.titles && a.offer = b.offer && a.phase = b.phase && a.pieces = b.pieces
  in
  match !last with
  | Some (was, shapes) when !memo && same was now -> shapes
  | _ ->
      let shapes = view_simple computer m over in
      last := Some (now, shapes);
      shapes

(* what the tab gave a program (Browser_helpers): the document written
 * to a file, if the program is given one, and the program started
 * beside the window *)
let helped (caps : < caps; .. >) (m : model) : model =
  match Tab.take_job m.tab with
  | None, _ -> m
  | Some (rule, url, body), tab ->
      let file =
        Option.map
          (fun bytes ->
            let dir = try CapSys.getenv caps "TMPDIR" with Not_found -> "/tmp" in
            let path = Filename.concat dir (Printf.sprintf "mini-netscape-%d-%s" (Hashtbl.hash url) (Filename.basename (fst (Browser_url.split_query (fst (Browser_url.split_fragment url)))))) in
            Logs.info (fun m -> m "writing %s, for %s" path (Browser_helpers.name rule));
            FS.write caps (Fpath.v path) bytes;
            path)
          body
      in
      Browser_helpers.run caps (Browser_helpers.command rule ~url ~file);
      { m with tab }

let update (caps : < caps; .. >) (computer : P.computer) (m : model) : model =
  let m = saved caps (helped caps (update_window caps computer m)) in
  (* (mini-ml's threads: the worker's turn) *)
  if Tab_worker.out () then Thread.yield ();
  m

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

(* the profile's directory: profile=DIR, or the user's; profile=off, none *)
let profile_dir (caps : < caps; .. >) (flags : P.flags) : string option =
  match List.assoc_opt "profile" flags with Some "off" -> None | Some dir -> Some dir | None -> Browser_profile.default_dir caps

let app (caps : < caps; .. >) (flags : P.flags) (profile : string option) ((kept, cookies, places) : Browser_profile.t * Cookie.jar * Places.t) =
  let address = match List.assoc_opt "url" flags with Some a -> a | None -> "about:home" in
  let jar = Cookie_jar.create cookies in
  (* the helper programs: the profile's, ~/.mailcap's, the built-in
   * ones, those on the PATH; none with helpers=off (the tests: a
   * frame dumped starts no program) *)
  let helpers =
    if List.assoc_opt "helpers" flags = Some "off" then []
    else
      let home = try Some (CapSys.getenv caps "HOME") with Not_found -> None in
      let mailcap =
        match Option.bind home (fun h -> FS.read_opt caps (Fpath.v (Filename.concat h ".mailcap"))) with
        | Some text -> Logs.info (fun m -> m "reading ~/.mailcap"); Browser_helpers.of_mailcap text
        | None -> []
      in
      Browser_helpers.available caps (kept.helpers @ mailcap @ Browser_helpers.defaults)
  in
  let blank = Tab.with_helpers helpers (Tab.with_jar jar (Tab.with_scripts (List.assoc_opt "scripts" flags <> Some "off") (Tab.empty P.default_width about))) in
  let tab = Tab.visit blank address in
  (* console=on: and what the engine's debugging switches say, if a
   * host sets one (Js_value.say) *)
  if List.assoc_opt "keep" flags = Some "off" then Tab.keeps := false;
  if List.assoc_opt "settle" flags = Some "off" then Tab.settles := false;
  if List.assoc_opt "draw" flags = Some "all" then Browser_draw.lazily := false;
  if List.assoc_opt "view" flags = Some "each" then memo := false;
  (match List.assoc_opt "worker" flags with Some "off" -> Tab_worker.working := Inline | Some "wait" -> Tab_worker.working := Waited | _ -> ());
  if List.assoc_opt "console" flags = Some "on" then Js_value.say := (fun line -> Console.eprint caps (line ^ "\n"));
  (* strict=on: a page's script refused whole if it does not parse, a
   * DOM method this browser lacks a TypeError, as a browser has them;
   * by default both are passed over with a warning (plan_browser.md, C) *)
  if List.assoc_opt "strict" flags = Some "on" then (Browser_script.strict := true; Js_eval.lenient := false);
  P.game view (update caps)
    { tab; left = []; right = []; blank; places; choice = -1; location = Tab.url tab; editing = false; fresh = false; before = []; cursor = P.Arrow; zooms = kept.zooms;
      console = (if List.assoc_opt "console" flags = Some "on" then Some 0 else None); jar; profile; window = kept.window; kept = (kept, 0, places); piece = None; later = [] }

let () =
  Cap.main (fun caps ->
      (* (-help: the usage, and the end, Exit.ExitCode) *)
      Exit.exit caps @@ Exit.catch @@ fun () ->
      (* the traces' reporter, before the flags: -v, -debug (Session) *)
      Logging.setup caps ~name:"mini-netscape";
      let flags = Playground_platform.flags caps in
      let profile = profile_dir caps flags in
      let (kept : Browser_profile.t), cookies = match profile with Some dir -> Browser_profile.load caps ~dir | None -> (Browser_profile.empty, []) in
      let places = match profile with Some dir -> Browser_profile.load_places caps ~dir | None -> Places.empty in
      (* the screen as large as the window (Session's flag window): the
       * size it had last, if the profile says and the user does not *)
      let asked = if List.mem_assoc "window" flags then [] else [ ("window", match kept.window with Some (w, h) -> Printf.sprintf "%dx%d" w h | None -> "") ] in
      (try Playground_platform.run_app caps (asked @ flags) (app caps flags profile (kept, cookies, places))
      with Failure msg ->
        Console.eprint caps (msg ^ "\n");
        CapStdlib.exit caps 1);
      Exit.OK)
