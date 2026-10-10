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
 * back; in the Location field, an address typed and Enter.
 *
 * The page is as wide as the playground's screen, 1000 units, scaled
 * into the window. Nothing is fetched while the window draws: a page
 * loading stops it (plan_browser.md, decision 6). No picture, no
 * script yet. A PDF file is shown, its pages one under the other
 * (Pdf_viewer; plan_pdf.md, stage F).
 *
 * usage: mini-netscape [url=address]     (a file's path is an address) *)

module P = Playground

type caps = < Cap.network; Cap.open_in >

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
}

(* the keys that do something once, when they go down *)
let once = [ "ArrowDown"; "ArrowUp"; "PageDown"; "PageUp"; "Home"; "End"; "Enter"; "Backspace"; "Escape"; "space" ]

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

let shown (m : model) : model = { m with location = Tab.url m.tab; editing = false; fresh = false }

let update (caps : < caps; .. >) (computer : P.computer) (m : model) : model =
  let screen = computer.screen and mouse = computer.mouse and keys = computer.keyboard in
  let visible = screen.height -. toolbar_height -. status_height in
  let held = List.filter (fun k -> Set_.mem k keys.keys) once in
  let pressed k = List.mem k held && not (List.mem k m.before) in
  let m = { m with before = held } in
  (* the mouse, in the window's coordinates *)
  let at = (mouse.mx -. screen.left, screen.top -. mouse.my) in
  let m = if mouse.mwheel <> 0. then { m with tab = Tab.scrolled (-.mouse.mwheel *. 60.) ~visible m.tab } else m in
  let m =
    if not mouse.mclick then m
    else if snd at < toolbar_height then
      match List.find_opt (fun (_, x, w) -> inside at (x, 8., w, 28.)) buttons with
      | Some ("Back", _, _) -> shown { m with tab = Tab.back caps m.tab }
      | Some ("Forward", _, _) -> shown { m with tab = Tab.forward caps m.tab }
      | Some (_, _, _) -> shown { m with tab = Tab.reload caps m.tab }
      | None -> if inside at (field_x, 8., field_width screen.width, 28.) then { m with editing = true; fresh = true } else { m with editing = false }
    else if snd at < screen.height -. status_height then
      shown { m with tab = Tab.click caps m.tab ~x:(fst at) ~y:(snd at -. toolbar_height +. Tab.scroll m.tab) }
    else m
  in
  if m.editing then
    let m = if keys.typed <> "" then { m with location = (if m.fresh then "" else m.location) ^ keys.typed; fresh = false } else m in
    if pressed "Enter" then shown { m with tab = Tab.visit caps m.tab m.location }
    else if pressed "Backspace" then { m with location = (if m.fresh || m.location = "" then "" else String.sub m.location 0 (String.length m.location - 1)); fresh = false }
    else if pressed "Escape" then shown m
    else m
  else if Tab.focus m.tab <> None then
    let m = if keys.typed <> "" then { m with tab = Tab.typed m.tab keys.typed } else m in
    if pressed "Enter" then shown { m with tab = Tab.key caps m.tab "enter" }
    else if pressed "Backspace" then { m with tab = Tab.key caps m.tab "backspace" }
    else m
  else
    let by d = { m with tab = Tab.scrolled d ~visible m.tab } in
    if pressed "ArrowDown" then by 40.
    else if pressed "ArrowUp" then by (-40.)
    else if pressed "PageDown" || pressed "space" then by (visible -. 40.)
    else if pressed "PageUp" then by (-.(visible -. 40.))
    else if pressed "Home" then by (-1e9)
    else if pressed "End" then by 1e9
    else if pressed "Backspace" then shown { m with tab = Tab.back caps m.tab }
    else m

(*****************************************************************************)
(* View *)
(*****************************************************************************)

(* Netscape's N: white on the dark blue of its night sky *)
let logo (x : float) (y : float) : P.shape list =
  let style : Style.t = { bold = true; italic = false; underline = false; strike = false; size = 26. } in
  box (P.rgb 0 0 96) x y 36. 36. :: Stroke_text.glyph (P.rgb 255 255 255) style "N" ~x:(x +. 9.) ~baseline:(-.(y +. 27.))

let view (computer : P.computer) (m : model) : P.shape list =
  let screen = computer.screen in
  let width = screen.width and height = screen.height in
  let visible = height -. toolbar_height -. status_height in
  let scroll = Tab.scroll m.tab in
  (* the page: what of it is in the window, its top left under the toolbar *)
  let page =
    match Tab.page m.tab with
    | None -> []
    | Some p ->
        let controls = Browser_draw.controls_drawn ~value:(Browser_page.value_of p) ~focus:(Tab.focus m.tab) p.layout in
        let seen = List.filter_map (fun (top, bottom, shape) -> if bottom > scroll && top < scroll +. visible then Some shape else None) (p.drawn @ controls) in
        let r, g, b = match p.background with Some c -> c | None -> (255, 255, 255) in
        [ box (P.rgb r g b) 0. toolbar_height width visible; P.move 0. (scroll -. toolbar_height) (P.group seen) ]
  in
  let toolbar =
    box grey 0. 0. width toolbar_height
    :: box (P.rgb 96 96 96) 0. (toolbar_height -. 1.) width 1.
    :: List.concat_map (fun (name, x, w) -> Browser_draw.raised x 8. w 28. @ text name (x +. ((w -. Browser_text.metrics look name) /. 2.)) 27.) buttons
    @ text "Location:" 250. 27.
    @ Browser_draw.sunken field_x 8. (field_width width) 28.
    @ [ box (P.rgb 255 255 255) (field_x +. 2.) 10. (field_width width -. 4.) 24. ]
    @ text (fitted ~keep_end:m.editing (m.location ^ if m.editing then "|" else "") (field_width width -. 12.)) (field_x +. 6.) 27.
    @ logo (width -. 46.) 4.
  in
  (* the status bar: where the link under the mouse goes, or what the last load said *)
  let over =
    let x = computer.mouse.mx -. screen.left and y = screen.top -. computer.mouse.my in
    if y > toolbar_height && y < height -. status_height then Tab.link_at m.tab ~x ~y:(y -. toolbar_height +. scroll) else None
  in
  let status =
    box grey 0. (height -. status_height) width status_height
    :: box (P.rgb 96 96 96) 0. (height -. status_height) width 1.
    :: text (fitted ~keep_end:false (match over with Some link -> link | None -> Tab.said m.tab) (width -. 16.)) 8. (height -. 6.)
  in
  [ P.move screen.left screen.top (P.group (page @ toolbar @ status)) ]

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

let app (caps : < caps; .. >) (flags : P.flags) =
  let address = match List.assoc_opt "url" flags with Some a -> a | None -> "about:home" in
  let tab = Tab.visit caps (Tab.empty P.default_width about) address in
  P.game view (update caps) { tab; location = Tab.url tab; editing = false; fresh = false; before = [] }

let () =
  Cap.main (fun caps ->
      let flags = Playground_platform.flags caps in
      try Playground_platform.run_app caps flags (app caps flags)
      with Failure msg ->
        Console.eprint caps (msg ^ "\n");
        CapStdlib.exit caps 1)
