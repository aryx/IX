(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Screen.mli *)
module TSys = TinyLibSystem
module D = TinyLibDraw
module P = TinyLibPlayground
module G = TinyLibGUI
open Lines

(*****************************************************************************)
(* The screen *)
(*****************************************************************************)

(* The colours, each an image of one pixel on our connection to the
 * screen (image 0 is where we draw: the screen, or our window). The
 * numbers in d_colour are bytes of the machine's palette. Our images
 * are above the playground's (3 plus a colour's byte, up to 258), which
 * the menus and the toolbar are drawn with. *)
let c_white = 261
let c_black = 262
let c_link = 263
let c_code = 264
let c_rule = 265
let c_text = 268
let colours =
  D.d_colour c_white 255 ^ D.d_colour c_black 0 ^ D.d_colour c_link 23
  ^ D.d_colour c_code 221
  ^ D.d_colour c_rule 136 ^ D.d_colour c_text 68

(*****************************************************************************)
(* What the screen shows *)
(*****************************************************************************)

type wire = Wire_off | Wire_page of int | Wire_picture of int * int

type nav = {
  mutable nv_address : string;
  mutable nv_wire : wire;
  mutable nv_history : (string * int) list;
  mutable nv_goal : int option;
  mutable nv_goal_id : string option;
  mutable nv_pressed : bool;
  mutable nv_hover : bool;
}

type tools = {
  mutable tb_field : string;
  mutable tb_mouse : G.mouse;
  tb_menu : G.menu_state;
}

type doc = {
  mutable dc_got : int;
  mutable dc_head : string;
  mutable dc_type : string option;
  mutable dc_status : int option;
  mutable dc_file : int option;
}

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
  mutable sc_y : int;
  mutable sc_drawn : int;
  sc_doc : doc;
  mutable sc_state : state;
  mutable sc_msgs : string list;
}

let put sc m = sc.sc_msgs <- m :: sc.sc_msgs

type act =
  | Back | Top | Reload | Quit | Address | Search | Go_to of string
  | Go_typed
  | Typed of string

(* The menus are the page's, a few articles to go to, and the last ten
 * pages seen, the latest first. *)
let bookmarks = [ "OCaml"; "Plan 9 from Bell Labs"; "Unix"; "Niklaus Wirth" ]
let menus sc =
  let rec first n l =
    match l with x :: rest when n > 0 -> x :: first (n - 1) rest | _ -> [] in
  let short a = if String.length a > 56 then String.sub a 0 56 else a in
  [ "Page", [ "Back       b", Back; "Top", Top; "Reload", Reload;
              "Quit       q", Quit ];
    "Go", ("Address... g", Address) :: ("Search...  s", Search)
          :: List.map (fun t -> t, Go_to t) bookmarks;
    "History",
    List.map (fun (a, _) -> short a, Go_to a) (first 10 sc.sc_nav.nv_history) ]

(* Writes the messages kept. A menu that is open is over the page, so it
 * is drawn again over what the messages drew. *)
let send sc =
  if sc.sc_msgs <> [] then begin
    (try TSys.write TSys.fd_draw (String.concat "" (List.rev sc.sc_msgs))
     with Failure _ -> ());
    sc.sc_msgs <- [];
    if sc.sc_tools.tb_menu.opened <> None then begin
      List.iter (P.draw 0 0 0)
        (List.tl (G.menu_view (sc.sc_cols * 8) (menus sc) sc.sc_tools.tb_menu));
      P.flush ()
    end
  end

let clip sc s =
  if String.length s > sc.sc_cols - 2 then
    String.sub s 0 (max 0 (sc.sc_cols - 2))
  else s

let fill_row sc row colour =
  put sc (D.d_fill 0 colour (0, row * 16, sc.sc_cols * 8, (row * 16) + 16))

(* The page's area on the screen: from under the toolbar to the status
 * row, [area sc] pixels high. The page scrolls by pixels: its line i is
 * at area_top + 16 i - sc_y. *)
let area_top = G.bar_height + 32
let area sc = ((sc.sc_rows - 1) * 16) - area_top
let rows_of_page sc = area sc / 16

(* A line cut by the page area's edge (half scrolled out) is drawn first
 * into [c_strip], an image of one line kept for that, then copied to
 * its place on the screen, cut to the area: so it never draws over the
 * bar or the status line. A line all inside the area is drawn on the
 * screen itself. *)
let c_strip = 269

(* A picture's image on our connection is its number plus 272 (the
 * colours and the strip are below). *)
let image_of id = 272 + id

(* A slice of a picture (16 rows of it) into dst at row y: the rows that
 * have come, from the picture's image, and a grey box for the rest;
 * until its first rows come, its alternative text on the grey. *)
let draw_slice sc dst y (r : run) id s =
  let pc = Html.picture_of sc.sc_page id in
  let x = r.col * 8 and from = s * 16 in
  let high = min 16 (pc.pc_h - from) in
  let rows = match pc.pc_got with Pic_rows n -> n | _ -> 0 in
  if high > 0 then begin
    let have = if rows > from then min high (rows - from) else 0 in
    if have > 0 then
      put sc
        (D.d_draw dst (image_of id) (-1) (x, y, x + pc.pc_w, y + have) (0, from));
    if have < high then begin
      put sc (D.d_fill dst c_code (x, y + have, x + pc.pc_w, y + high));
      if s = 0 && rows = 0 && pc.pc_w >= 24 && high = 16 then begin
        let alt = if pc.pc_alt = "" then "picture" else pc.pc_alt in
        let fits = (pc.pc_w / 8) - 1 in
        put sc (D.d_text dst c_text (x + 4, y)
                  (if String.length alt > fits then String.sub alt 0 (max 0 fits)
                   else alt))
      end
    end
  end

(* Line i goes through the strip when the area's edge cuts it or when it
 * is half of a large heading's line. Bold is black in the kernel's bold
 * font, which keeps an m's gaps (drawing twice, a pixel apart, made an
 * m a block). A large heading uses the kernel's 16 by 32 font, its top
 * half on one line and its bottom half (Run_lower) on the next. *)
let draw_line sc i (l : line) =
  let w = sc.sc_cols * 8 and at = area_top + (i * 16) - sc.sc_y in
  let tall = List.exists (fun (r : run) -> r.look land big <> 0) l.runs in
  let whole = not tall && at >= area_top && at + 16 <= area_top + area sc in
  let dst = if whole then 0 else c_strip and y = if whole then at else 0 in
  put sc (D.d_fill dst c_white (0, y, w, y + 16));
  if l.rule then put sc (D.d_fill dst c_rule (0, y + 7, w, y + 9))
  else
    l.runs |> List.iter (fun (r : run) ->
      match r.part with
      | Run_slice (id, s) -> draw_slice sc dst y r id s
      | _ when r.col < sc.sc_cols && r.text <> "" ->
        let k = if r.look land big <> 0 then 2 else 1 in
        let n = min (String.length r.text) ((sc.sc_cols - r.col) / k) in
        let t = String.sub r.text 0 n and x = r.col * 8
        and ry = if r.part = Run_lower then y - 16 else y in
        if r.look land code <> 0 then
          put sc (D.d_fill dst c_code (x, y, x + (n * 8), y + 16));
        let ink =
          if r.link <> None then c_link
          else if r.look land bold <> 0 then c_black else c_text in
        (* (a look's bold and emph are the kernel's style's bits) *)
        let style =
          (r.look land (bold + emph))
          lor (if r.look land under <> 0 then 4 else 0)
          lor (if k = 2 then 8 else 0) in
        put sc (if style = 0 then D.d_text dst ink (x, ry) t
                else D.d_styled dst ink (x, ry) style t);
        if r.link <> None then
          put sc (D.d_line dst c_link (x, ry + (16 * k) - 1)
                    (x + (n * 8 * k) - 1, ry + (16 * k) - 1))
      | _ -> ());
  if not whole then begin
    let y0 = max at area_top and y1 = min (at + 16) (area_top + area sc) in
    if y0 < y1 then put sc (D.d_draw 0 c_strip (-1) (0, y0, w, y1) (0, y0 - at))
  end

(* The page's title goes at the right of the menus' titles. Our messages
 * are sent first, as the playground's shapes go over them. *)
let draw_bar sc =
  send sc;
  let w = sc.sc_cols * 8 and ms = menus sc in
  let x =
    List.fold_left (fun x (t, _) -> x + (8 * String.length t) + 16) 16 ms in
  let t =
    let title = Html.title sc.sc_page in
    if title <> "" then title else sc.sc_nav.nv_address in
  let n = max 0 (((w - x) / 8) - 1) in
  (match G.menu_view w ms sc.sc_tools.tb_menu with
   | bar :: opened ->
     P.draw 0 0 0 bar;
     P.draw 0 x 1
       (P.Words (0, if String.length t > n then String.sub t 0 n else t));
     List.iter (P.draw 0 0 0) opened
   | [] -> ());
  P.flush ()

(* When the address is longer than the field, the field shows its end,
 * and what is typed goes after the part not shown. *)
let input_box sc = 72, G.bar_height + 4, (sc.sc_cols * 8) - 144, 24
let laid_tools sc =
  let (x, y, w, h) = input_box sc in
  let f = sc.sc_tools.tb_field in
  let cut = max 0 (String.length f - ((w - 16) / 8)) in
  let input =
    G.Input (String.sub f cut (String.length f - cut),
           fun t -> Typed (String.sub f 0 cut ^ t)) in
  let (s1, b1) = G.place 8 y 56 h (G.Button ("Back", Back)) in
  let (s2, b2) = G.place x y w h input in
  let (s3, b3) = G.place (x + w + 8) y 56 h (G.Button ("Go", Go_typed)) in
  s1 @ s2 @ s3, b1 @ b2 @ b3

(* G.over adds what the mouse puts over the toolbar: a button held, the
 * field's caret. *)
let draw_tools sc =
  let (shapes, boxes) = laid_tools sc in
  send sc;
  P.draw 0 0 G.bar_height (P.Rect (0xcc, sc.sc_cols * 8, area_top - G.bar_height));
  List.iter (P.draw 0 0 0) shapes;
  List.iter (fun (_, s) -> P.draw 0 0 0 s) (G.over boxes sc.sc_tools.tb_mouse);
  P.flush ()

(* the field has the keys: the mouse's button went down in it last *)
let focused sc = G.focused sc.sc_tools.tb_mouse (input_box sc)
let focus sc on =
  sc.sc_tools.tb_mouse <-
    { sc.sc_tools.tb_mouse with
      m_focus = (if on then Some (80, G.bar_height + 8) else None) }

let draw_status sc =
  let row = sc.sc_rows - 1 in
  fill_row sc row c_code;
  let d = sc.sc_doc in
  let kb = string_of_int ((d.dc_got + 1023) / 1024) ^ " KB" in
  let text =
    (match sc.sc_state with
     | Page_reading -> "reading, " ^ kb
     | Page_done ->
       (match d.dc_status with
        | Some n when n <> 200 -> string_of_int n ^ ", "
        | _ -> "")
       ^ kb ^ ", " ^ string_of_int (Html.count sc.sc_page) ^ " lines"
       ^ (match sc.sc_nav.nv_wire with
          | Wire_picture (_, id) ->
              ", picture " ^ string_of_int (id + 1) ^ " of "
              ^ string_of_int (Html.pictures sc.sc_page)
          | _ -> "")
     | Page_none why -> why)
    ^ "   space -: page, b: back, g: address, q: quit" in
  put sc (D.d_text 0 c_black (8, row * 16) (clip sc text))

(* The page's lines that fall in its area, from pixel [a] to pixel [b]
 * of the page, drawn; white where the page has ended. *)
let draw_between sc a b =
  let first = a / 16 and last = (b + 15) / 16 in
  let ls = Html.lines_between sc.sc_page first last in
  List.iteri (fun k l -> draw_line sc (first + k) l) ls;
  let bottom = area_top + ((first + List.length ls) * 16) - sc.sc_y in
  let y0 = max bottom (area_top + a - sc.sc_y)
  and y1 = area_top + b - sc.sc_y in
  if y0 < y1 then put sc (D.d_fill 0 c_white (0, y0, sc.sc_cols * 8, y1));
  first + List.length ls

let redraw sc = sc.sc_drawn <- draw_between sc sc.sc_y (sc.sc_y + area sc)

let max_y sc = max 0 ((Html.count sc.sc_page * 16) - area sc)

(* Scrolls by [d] pixels (up when negative). What stays on the screen is
 * moved there by one copy of the screen onto itself, and only the strip
 * that comes in is drawn: a scroll of a line draws one line, not the
 * screen's thirty. *)
let scroll_by sc d =
  let y = max 0 (min (sc.sc_y + d) (max_y sc)) in
  let delta = y - sc.sc_y and h = area sc and w = sc.sc_cols * 8 in
  if delta <> 0 then begin
    if abs delta >= h then begin sc.sc_y <- y; redraw sc end
    else if delta > 0 then begin
      put sc (D.d_draw 0 0 (-1) (0, area_top, w, area_top + h - delta)
                (0, area_top + delta));
      sc.sc_y <- y;
      let first = (y + h - delta) / 16 in
      let drawn = draw_between sc (y + h - delta) (y + h) in
      if sc.sc_drawn >= first then sc.sc_drawn <- max sc.sc_drawn drawn
    end
    else begin
      put sc
        (D.d_draw 0 0 (-1) (0, area_top - delta, w, area_top + h) (0, area_top));
      sc.sc_y <- y;
      ignore (draw_between sc y (y - delta));
      sc.sc_drawn <- min sc.sc_drawn ((y + h + 15) / 16)
    end
  end

(* A screenful at a time, in steps of a few lines, so that the page is
 * seen moving rather than jumping: the same lines are drawn as by a
 * jump, as each step only draws what comes in. *)
let glide sc d =
  let step = 64 in
  let rec go left =
    if left <> 0 then begin
      let s = if left > 0 then min step left else max (- step) left in
      let before = sc.sc_y in
      scroll_by sc s;
      send sc;
      if sc.sc_y <> before then go (left - s)
    end in
  go d

let show_from sc line =
  let y = max 0 (min (line * 16) (max_y sc)) in
  if y <> sc.sc_y then begin sc.sc_y <- y; redraw sc end

(* The lines that arrived and fit below the ones on the screen; and the
 * place a page was asked to show (back, or a #fragment), once it has
 * come. *)
let show_new sc =
  let all_there = sc.sc_nav.nv_wire = Wire_off in
  (match sc.sc_nav.nv_goal_id with
   | Some id ->
       (match Html.anchor sc.sc_page id with
        | Some line
          when line + rows_of_page sc <= Html.count sc.sc_page || all_there ->
            sc.sc_nav.nv_goal_id <- None; show_from sc line
        | _ -> ())
   | None -> ());
  (match sc.sc_nav.nv_goal with
   | Some goal
     when (goal / 16) + rows_of_page sc <= Html.count sc.sc_page || all_there ->
       sc.sc_nav.nv_goal <- None;
       let y = max 0 (min goal (max_y sc)) in
       if y <> sc.sc_y then begin sc.sc_y <- y; redraw sc end
   | _ -> ());
  let last = min (Html.count sc.sc_page) ((sc.sc_y + area sc + 15) / 16) in
  if sc.sc_drawn < last then begin
    List.iteri (fun k l -> draw_line sc (sc.sc_drawn + k) l)
      (Html.lines_between sc.sc_page sc.sc_drawn last);
    sc.sc_drawn <- last
  end

(* The mouse's look: a hand over a link, the arrow elsewhere (d_cursor:
 * the machine's window or page shows it). Sent when it changes. *)
let hover sc over =
  if over <> sc.sc_nav.nv_hover then begin
    sc.sc_nav.nv_hover <- over;
    put sc (D.d_cursor (if over then D.Cursor_hand else D.Cursor_arrow))
  end
