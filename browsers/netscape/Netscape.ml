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
 * The mouse: a click on a link follows it, on a field gives it the
 * keys, on a button sends its form; the wheel scrolls. The keys: the
 * arrows, Page Up and Down, Space, Home and End scroll; Backspace goes
 * back; in the Location field, an address typed and Enter. Ctrl and +
 * (or =), Ctrl and -, Ctrl and the wheel zoom the page, Ctrl and 0
 * back to 100% (Browser_zoom: Chrome's steps, each site its own): the
 * page is laid out narrower and drawn scaled.
 *
 * The page is as wide as the playground's screen, 1000 units, scaled
 * into the window. Nothing is fetched while the window draws
 * (plan_browser.md, decision 6): a page on its way is fetched a piece
 * between two frames (the page and its sheets, then a picture each),
 * the status bar saying which and the N turned white meanwhile. The
 * cursor is a hand over a link or a button, an I-beam over a field.
 * A page's scripts run (browsers/webapi over browsers/javascript:
 * mini-chrome's engine and DOM of today), their timers on the frame's
 * clock. A PDF file is shown, its pages one under the other
 * (Pdf_viewer; plan_pdf.md, stage F).
 *
 * usage: mini-netscape [url=address] [scripts=off] [console=on]
 *   (a file's path is an address; console=on: what the page's scripts
 *   print, and their errors, on the standard error) *)

module P = Playground

type caps = < Cap.network; Cap.open_in; Cap.stderr >

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
let host (m : model) : string = match Url.parse (Tab.url m.tab) with Ok { authority = Some a; _ } -> a.host | _ -> ""
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

let update (caps : < caps; .. >) (computer : P.computer) (m : model) : model =
  let screen = computer.screen and mouse = computer.mouse and keys = computer.keyboard in
  let visible = screen.height -. toolbar_height -. status_height in
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
  (* the page's timers, on the frame's clock *)
  let m = { m with tab = Tab.advance (1000. /. 60.) m.tab } in
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

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

let app (caps : < caps; .. >) (flags : P.flags) =
  let address = match List.assoc_opt "url" flags with Some a -> a | None -> "about:home" in
  let tab = Tab.visit (Tab.with_scripts (List.assoc_opt "scripts" flags <> Some "off") (Tab.empty P.default_width about)) address in
  (* console=on: and what the engine's debugging switches say, if a
   * host sets one (Js_value.say) *)
  if List.assoc_opt "console" flags = Some "on" then Js_value.say := (fun line -> Console.eprint caps (line ^ "\n"));
  P.game view (update caps) { tab; location = Tab.url tab; editing = false; fresh = false; before = []; cursor = P.Arrow; zooms = Browser_zoom.empty; console = (if List.assoc_opt "console" flags = Some "on" then Some 0 else None) }

let () =
  Cap.main (fun caps ->
      let flags = Playground_platform.flags caps in
      try Playground_platform.run_app caps flags (app caps flags)
      with Failure msg ->
        Console.eprint caps (msg ^ "\n");
        CapStdlib.exit caps 1)
