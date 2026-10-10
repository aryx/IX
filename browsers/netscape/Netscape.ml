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
 *   | [Back] [Forward] [Reload]  Location: [ http://...       ] [N] |
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
 * back; in the Location field, an address typed and Enter. Ctrl and +
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
 * clock. A PDF file is shown, its pages one under the other
 * (Pdf_viewer; plan_pdf.md, stage F).
 *
 * What is ours: the name says the window's period, not the engine's
 * (plan_browser.md, decision 1). Netscape 1 had no style sheets and
 * no scripts; a Netscape faithful to it, over Mosaic's kind of layout
 * (Html_layout, which the engine still has), would not show a page
 * of today. One tab, no bookmarks, no cookies, no cache, and a page's
 * requests one after the other on one thread.
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
 * chapter, the same pipeline. Tali Garsiel, "How Browsers Work"
 * (2011; from memory): WebKit's and Gecko's seen from above.
 *
 * usage: mini-netscape [url=address] [scripts=off] [console=on] [keep=off] [profile=dir|off] [window=WxH]
 *   (a file's path is an address; console=on: what the page's scripts
 *   print, and their errors, on the standard error; keep=off: a
 *   connection a request; profile: where the cookies and the zooms are
 *   kept, ~/.config/mini-netscape if not said, off for nowhere; window:
 *   the window's size at first, the one it had last if not said) *)

module P = Playground

type caps = < Cap.network; Cap.open_in; Cap.open_out; Cap.env; Cap.stderr >

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
<p>The arrows, Page Up and Down, Space and the wheel scroll; Backspace goes back."

let about (name : string) : string option = match name with "home" -> Some home | "blank" -> Some "" | _ -> None

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

type model = {
  tab : Tab.t;
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
  kept : Browser_profile.t * int; (* what its files have: the preferences, the jar as it was written (its changes) *)
}

(* the keys that do something once, when they go down *)
let once = [ "ArrowDown"; "ArrowUp"; "PageDown"; "PageUp"; "Home"; "End"; "Enter"; "Backspace"; "Escape"; "space"; "="; "+"; "-"; "0" ]

(*****************************************************************************)
(* The window's places, x right and y down from its top left *)
(*****************************************************************************)

let toolbar_height = 44.
let status_height = 22.
let buttons = [ ("Back", 8., 60.); ("Forward", 74., 84.); ("Reload", 164., 72.) ]
let field_x = 330.
let field_width (width : float) : float = width -. field_x -. 60.
let inside (x, y) (bx, by, bw, bh) = x >= bx && x <= bx +. bw && y >= by && y <= by +. bh
let grey = P.rgb 192 192 192
let look : Looks.t = { Browser_text.root_look with size = 13. }

(* a rectangle and a text, by their top left and their baseline *)
let box (color : P.color) (x : float) (y : float) (w : float) (h : float) : P.shape =
  P.move (x +. (w /. 2.)) (-.(y +. (h /. 2.))) (P.rectangle color w h)

let text (s : string) (x : float) (baseline : float) : P.shape list =
  Browser_draw.plain_glyphs { text = s; look; x; width = Browser_text.metrics look s; baseline; picture = None; control = None; element = Dom.element "span" [] }

(* a text cut to what fits in [room], its end kept (an address typed) or its start *)
let fitted ~(keep_end : bool) (s : string) (room : float) : string =
  let rec cut s = if s = "" || Browser_text.metrics look s <= room then s else cut (if keep_end then String.sub s 1 (String.length s - 1) else String.sub s 0 (String.length s - 1)) in
  cut s

(*****************************************************************************)
(* Update *)
(*****************************************************************************)

(* the zoom of the page shown, or asked for: its site's *)
(* the site the page is of, for its zoom; "file" for what is not from
 * the network (a file's first directory would be read as a host) *)
let host (m : model) : string = match Url.parse (Tab.url m.tab) with Ok { scheme = Some ("http" | "https"); authority = Some a; _ } -> a.host | _ -> "file"
let zoom (m : model) : float = Browser_zoom.of_host m.zooms (host m)

(* the page laid out at the window's width divided by its zoom *)
let fitted_tab (width : float) (m : model) : model = { m with tab = Tab.resized (width /. zoom m) m.tab }

let zoomed (width : float) (change : Browser_zoom.change) (m : model) : model =
  fitted_tab width { m with zooms = Browser_zoom.with_host m.zooms (host m) (Browser_zoom.apply change (zoom m)) }

let shown (m : model) : model = { m with location = Tab.url m.tab; editing = false; fresh = false }

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
  else if y < height -. status_height then
    match Tab.under m.tab ~x:(x /. z) ~y:(((y -. toolbar_height) /. z) +. Tab.scroll m.tab) with
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
      let preferences, cookies = m.kept in
      let now : Browser_profile.t = { zooms = m.zooms; window = m.window } in
      let changes = Cookie_jar.changes m.jar in
      let wrote =
        if now <> preferences then Some (Browser_profile.save caps ~dir now, (now, cookies))
        else if changes <> cookies && not (Tab.busy m.tab) then Some (Browser_profile.save_cookies caps ~dir (Cookie_jar.cookies m.jar), (preferences, changes))
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
  let visible = screen.height -. toolbar_height -. status_height in
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
    if Tab.busy m.tab && !seen then begin
      seen := false;
      let tab = Tab.step caps m.tab in
      { m with tab; location = (if m.editing then m.location else Tab.url tab) }
    end
    else m
  in
  (* the page's timers, on the frame's clock; its Date, from the time it is *)
  let (P.Time now) = computer.time in
  let m = { m with tab = Tab.advance (1000. /. 60.) (Tab.at (Float.round (now *. 1000.)) m.tab) } in
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
      | Some (_, _, _) -> shown { m with tab = Tab.reload m.tab }
      | None -> if inside at (field_x, 8., field_width screen.width, 28.) then { m with editing = true; fresh = true } else { m with editing = false }
    else if snd at < screen.height -. status_height then
      shown { m with tab = Tab.click m.tab ~x:(fst at /. zoom m) ~y:(((snd at -. toolbar_height) /. zoom m) +. Tab.scroll m.tab) }
    else m
  in
  let change = if control then List.find_map (fun k -> if pressed k then Browser_zoom.key k else None) [ "="; "+"; "-"; "0" ] else None in
  if change <> None then match change with Some c -> zoomed screen.width c m | None -> m
  else if m.editing then
    let m = if keys.typed <> "" then { m with location = (if m.fresh then "" else m.location) ^ keys.typed; fresh = false } else m in
    if pressed "Enter" then shown { m with tab = Tab.visit m.tab m.location }
    else if pressed "Backspace" then { m with location = (if m.fresh || m.location = "" then "" else String.sub m.location 0 (String.length m.location - 1)); fresh = false }
    else if pressed "Escape" then shown m
    else m
  else if Tab.focus m.tab <> None then
    let m = if keys.typed <> "" then { m with tab = Tab.typed m.tab keys.typed } else m in
    if pressed "Enter" then shown { m with tab = Tab.key m.tab "enter" }
    else if pressed "Backspace" then { m with tab = Tab.key m.tab "backspace" }
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
    else m

(*****************************************************************************)
(* View *)
(*****************************************************************************)

(* Netscape's N: white on the dark blue of its night sky *)
(* (and, while a page is on its way, dark on the white of a comet's
 * tail: Netscape's N moved then) *)
let logo ~(busy : bool) (x : float) (y : float) : P.shape list =
  let style : Style.t = { bold = true; italic = false; underline = false; strike = false; size = 26. } in
  let sky = P.rgb 0 0 96 and white = P.rgb 255 255 255 in
  box (if busy then white else sky) x y 36. 36. :: Stroke_text.glyph (if busy then sky else white) style "N" ~x:(x +. 9.) ~baseline:(-.(y +. 27.))

let view (computer : P.computer) (m : model) : P.shape list =
  seen := true;
  let screen = computer.screen in
  let width = screen.width and height = screen.height in
  let visible = height -. toolbar_height -. status_height in
  let scroll = Tab.scroll m.tab and z = zoom m in
  (* the page: what of it is in the window, its top left under the toolbar *)
  let page =
    match Tab.page m.tab with
    | None -> []
    | Some p ->
        let controls = Browser_draw.controls_drawn ~value:(Browser_page.value_of p) ~focus:(Tab.focus m.tab) p.layout in
        let seen = List.filter_map (fun (top, bottom, shape) -> if bottom > scroll && top < scroll +. (visible /. z) then Some shape else None) (p.drawn @ controls) in
        let r, g, b = match p.background with Some c -> c | None -> (255, 255, 255) in
        [ box (P.rgb r g b) 0. toolbar_height width visible; P.move 0. (-.toolbar_height) (P.scale z (P.move 0. scroll (P.group seen))) ]
  in
  let toolbar =
    box grey 0. 0. width toolbar_height
    :: box (P.rgb 96 96 96) 0. (toolbar_height -. 1.) width 1.
    :: List.concat_map (fun (name, x, w) -> Browser_draw.raised x 8. w 28. @ text name (x +. ((w -. Browser_text.metrics look name) /. 2.)) 27.) buttons
    @ text "Location:" 250. 27.
    @ Browser_draw.sunken field_x 8. (field_width width) 28.
    @ [ box (P.rgb 255 255 255) (field_x +. 2.) 10. (field_width width -. 4.) 24. ]
    @ text (fitted ~keep_end:m.editing (m.location ^ if m.editing then "|" else "") (field_width width -. 12.)) (field_x +. 6.) 27.
    @ logo ~busy:(Tab.busy m.tab) (width -. 46.) 4.
  in
  (* the status bar: where the link under the mouse goes, or what the last load said *)
  let over =
    let x = computer.mouse.mx -. screen.left and y = screen.top -. computer.mouse.my in
    if y > toolbar_height && y < height -. status_height then Tab.link_at m.tab ~x:(x /. z) ~y:(((y -. toolbar_height) /. z) +. scroll) else None
  in
  let status =
    box grey 0. (height -. status_height) width status_height
    :: box (P.rgb 96 96 96) 0. (height -. status_height) width 1.
    :: text (fitted ~keep_end:false (match over with Some link when not (Tab.busy m.tab) -> link | _ -> Tab.said m.tab) (width -. 80.)) 8. (height -. 6.)
    (* the zoom, when it is not 100% *)
    @ text (Browser_zoom.label z) (width -. 50.) (height -. 6.)
  in
  [ P.move screen.left screen.top (P.group (page @ toolbar @ status)) ]

let update (caps : < caps; .. >) (computer : P.computer) (m : model) : model = saved caps (update_window caps computer m)

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

(* the profile's directory: profile=DIR, or the user's; profile=off, none *)
let profile_dir (caps : < caps; .. >) (flags : P.flags) : string option =
  match List.assoc_opt "profile" flags with Some "off" -> None | Some dir -> Some dir | None -> Browser_profile.default_dir caps

let app (caps : < caps; .. >) (flags : P.flags) (profile : string option) ((kept, cookies) : Browser_profile.t * Cookie.jar) =
  let address = match List.assoc_opt "url" flags with Some a -> a | None -> "about:home" in
  let jar = Cookie_jar.create cookies in
  let tab = Tab.visit (Tab.with_jar jar (Tab.with_scripts (List.assoc_opt "scripts" flags <> Some "off") (Tab.empty P.default_width about))) address in
  (* console=on: and what the engine's debugging switches say, if a
   * host sets one (Js_value.say) *)
  if List.assoc_opt "keep" flags = Some "off" then Tab.keeps := false;
  if List.assoc_opt "console" flags = Some "on" then Js_value.say := (fun line -> Console.eprint caps (line ^ "\n"));
  P.game view (update caps) { tab; location = Tab.url tab; editing = false; fresh = false; before = []; cursor = P.Arrow; zooms = kept.zooms; console = (if List.assoc_opt "console" flags = Some "on" then Some 0 else None); jar; profile; window = kept.window; kept = (kept, 0) }

let () =
  Cap.main (fun caps ->
      let flags = Playground_platform.flags caps in
      let profile = profile_dir caps flags in
      let (kept : Browser_profile.t), cookies = match profile with Some dir -> Browser_profile.load caps ~dir | None -> (Browser_profile.empty, []) in
      (* the screen as large as the window (Session's flag window): the
       * size it had last, if the profile says and the user does not *)
      let asked = if List.mem_assoc "window" flags then [] else [ ("window", match kept.window with Some (w, h) -> Printf.sprintf "%dx%d" w h | None -> "") ] in
      try Playground_platform.run_app caps (asked @ flags) (app caps flags profile (kept, cookies))
      with Failure msg ->
        Console.eprint caps (msg ^ "\n");
        CapStdlib.exit caps 1)
