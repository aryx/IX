(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyBrowser.mli *)
open TinyCalls
open TinyLibDraw
open TinyLibPlayground
open TinyLibGUI
open TinyBrowserText
open TinyBrowserLines
open TinyBrowserPage
open TinyBrowserAddress

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
  d_colour c_white 255 ^ d_colour c_black 0 ^ d_colour c_link 23
  ^ d_colour c_code 221
  ^ d_colour c_rule 136 ^ d_colour c_text 68

(*****************************************************************************)
(* The browser *)
(*****************************************************************************)

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
  mutable tb_mouse : mouse;           (* TinyLibGUI's: the field has the keys
                                       * when pressed in last *)
  tb_menu : menu_state;
}

type screen = {
  mutable sc_page : page;
  sc_nav : nav;
  sc_tools : tools;
  sc_cols : int;
  sc_rows : int;
  mutable sc_y : int;               (* the page's pixel at the top of its area *)
  mutable sc_drawn : int;           (* the lines before this one that are in
                                     * the area are drawn *)
  mutable sc_got : int;             (* the bytes of the page read so far *)
  mutable sc_state : string;        (* "reading", "done", or why there is no page *)
  mutable sc_msgs : string list;    (* drawing messages not yet written, last
                                     * first *)
}

let put sc m = sc.sc_msgs <- m :: sc.sc_msgs

(* What a menu's item or a button of the toolbar does ([act] below):
 * Typed is the toolbar's field, its text after a key *)
type act =
  | Back | Top | Reload | Quit | Address | Go_to of string | Go_typed
  | Typed of string

(* The menus (TinyLibGUI's): the page, a few articles to go to, and the
 * pages seen before (the last ten, the latest first) *)
let bookmarks = [ "OCaml"; "Plan 9 from Bell Labs"; "Unix"; "Niklaus Wirth" ]
let menus sc =
  let rec first n l =
    match l with x :: rest when n > 0 -> x :: first (n - 1) rest | _ -> [] in
  let short a = if String.length a > 56 then String.sub a 0 56 else a in
  [ "Page", [ "Back       b", Back; "Top", Top; "Reload", Reload;
              "Quit       q", Quit ];
    "Go", ("Address... g", Address) :: List.map (fun t -> t, Go_to t) bookmarks;
    "History",
    List.map (fun (a, _) -> short a, Go_to a) (first 10 sc.sc_nav.nv_history) ]

(* The drawing messages written. A menu that is open is over the page:
 * it is drawn again, over what the messages drew. *)
let send sc =
  if sc.sc_msgs <> [] then begin
    ignore (u_write 3 (String.concat "" (List.rev sc.sc_msgs)));
    sc.sc_msgs <- [];
    if sc.sc_tools.tb_menu.opened >= 0 then begin
      List.iter (draw 0 0 0)
        (List.tl (menu_view (sc.sc_cols * 8) (menus sc) sc.sc_tools.tb_menu));
      flush ()
    end
  end

let clip sc s =
  if String.length s > sc.sc_cols - 2 then
    String.sub s 0 (max 0 (sc.sc_cols - 2))
  else s

(* a row, filled with a colour *)
let fill_row sc row colour =
  put sc (d_fill 0 colour 0 (row * 16) (sc.sc_cols * 8) ((row * 16) + 16))

(* The page's area on the screen: from under the toolbar to the status
 * row, [area sc] pixels high. The page scrolls by pixels: its line i is
 * at area_top + 16 i - sc_y. *)
let area_top = bar_height + 32
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
let draw_slice sc dst y (r : run) =
  let id = r.pic / 256 and s = r.pic mod 256 in
  let pc = picture_of sc.sc_page id in
  let x = r.col * 8 and from = s * 16 in
  let high = min 16 (pc.pc_h - from) in
  if high > 0 then begin
    let have = if pc.pc_got > from then min high (pc.pc_got - from) else 0 in
    if have > 0 then
      put sc
        (d_draw dst (image_of id) (-1) x y (x + pc.pc_w) (y + have) 0 from);
    if have < high then begin
      put sc (d_fill dst c_code x (y + have) (x + pc.pc_w) (y + high));
      if s = 0 && pc.pc_got <= 0 && pc.pc_w >= 24 && high = 16 then begin
        let alt = if pc.pc_alt = "" then "picture" else pc.pc_alt in
        let fits = (pc.pc_w / 8) - 1 in
        put sc (d_text dst c_text (x + 4) y
                  (if String.length alt > fits then String.sub alt 0 (max 0 fits)
                   else alt))
      end
    end
  end

(* The page's line i, put on the screen (by the strip when it is cut by
 * the area's edge, or is half of a large heading's line). The text is a
 * dark grey, bold black in the kernel's bold font (its strokes wider,
 * an m's gaps kept: drawn twice, a pixel apart, an m was a block);
 * emphasis is italic; a link is blue and underlined; code is on light
 * grey; a large heading's characters are 16 by 32, the kernel's large
 * font, its top half on one line, its bottom half (pic -2) on the next. *)
let draw_line sc i (l : line) =
  let w = sc.sc_cols * 8 and at = area_top + (i * 16) - sc.sc_y in
  let tall = List.exists (fun (r : run) -> r.look land big <> 0) l.runs in
  let whole = not tall && at >= area_top && at + 16 <= area_top + area sc in
  let dst = if whole then 0 else c_strip and y = if whole then at else 0 in
  put sc (d_fill dst c_white 0 y w (y + 16));
  if l.rule then put sc (d_fill dst c_rule 0 (y + 7) w (y + 9))
  else
    List.iter (fun (r : run) ->
      if r.pic >= 0 then draw_slice sc dst y r
      else if r.col < sc.sc_cols && r.text <> "" then begin
        let k = if r.look land big <> 0 then 2 else 1 in
        let n = min (String.length r.text) ((sc.sc_cols - r.col) / k) in
        let t = String.sub r.text 0 n and x = r.col * 8
        and ry = if r.pic = -2 then y - 16 else y in
        if r.look land code <> 0 then
          put sc (d_fill dst c_code x y (x + (n * 8)) (y + 16));
        let ink =
          if r.link <> "" then c_link
          else if r.look land bold <> 0 then c_black else c_text in
        (* (a look's bold and emph are the kernel's style's bits) *)
        let style =
          (r.look land (bold + emph))
          lor (if r.look land under <> 0 then 4 else 0)
          lor (if k = 2 then 8 else 0) in
        put sc (if style = 0 then d_text dst ink x ry t
                else d_styled dst ink x ry style t);
        if r.link <> "" then
          put sc (d_line dst c_link x (ry + (16 * k) - 1) (x + (n * 8 * k) - 1)
                    (ry + (16 * k) - 1))
      end) l.runs;
  if not whole then begin
    let y0 = max at area_top and y1 = min (at + 16) (area_top + area sc) in
    if y0 < y1 then put sc (d_draw 0 c_strip (-1) 0 y0 w y1 0 (y0 - at))
  end

(* The bar of menus, the page's title at the right of their titles, and
 * the menu open, by TinyLibPlayground's shapes (after our messages) *)
let draw_bar sc =
  send sc;
  let w = sc.sc_cols * 8 and ms = menus sc in
  let x =
    List.fold_left (fun x (t, _) -> x + (8 * String.length t) + 16) 16 ms in
  let t =
    if title sc.sc_page <> "" then title sc.sc_page else sc.sc_nav.nv_address in
  let n = max 0 (((w - x) / 8) - 1) in
  (match menu_view w ms sc.sc_tools.tb_menu with
   | bar :: opened ->
     draw 0 0 0 bar;
     draw 0 x 1
       (Words (0, if String.length t > n then String.sub t 0 n else t));
     List.iter (draw 0 0 0) opened
   | [] -> ());
  flush ()

(* The toolbar: Back, the address in a field (its end, when it is longer
 * than the field: what is typed goes after the part not shown), Go; by
 * TinyLibGUI's widgets, at their places *)
let input_box sc = 72, bar_height + 4, (sc.sc_cols * 8) - 144, 24
let laid_tools sc =
  let (x, y, w, h) = input_box sc in
  let f = sc.sc_tools.tb_field in
  let cut = max 0 (String.length f - ((w - 16) / 8)) in
  let input =
    Input (String.sub f cut (String.length f - cut),
           fun t -> Typed (String.sub f 0 cut ^ t)) in
  let (s1, b1) = place 8 y 56 h (Button ("Back", Back)) in
  let (s2, b2) = place x y w h input in
  let (s3, b3) = place (x + w + 8) y 56 h (Button ("Go", Go_typed)) in
  s1 @ s2 @ s3, b1 @ b2 @ b3

(* the toolbar on its ground (TinyLibGUI's grey), and what the mouse
 * puts over it: a button held, the field's caret *)
let draw_tools sc =
  let (shapes, boxes) = laid_tools sc in
  send sc;
  draw 0 0 bar_height (Rect (0xcc, sc.sc_cols * 8, area_top - bar_height));
  List.iter (draw 0 0 0) shapes;
  List.iter (fun (_, s) -> draw 0 0 0 s) (over boxes sc.sc_tools.tb_mouse);
  flush ()

(* the field has the keys: the mouse's button went down in it last *)
let focused sc =
  inside sc.sc_tools.tb_mouse.fx sc.sc_tools.tb_mouse.fy (input_box sc)
let focus sc on =
  sc.sc_tools.tb_mouse <-
    { sc.sc_tools.tb_mouse with
      fx = (if on then 80 else -1);
      fy = (if on then bar_height + 8 else -1) }

let draw_status sc =
  let row = sc.sc_rows - 1 in
  fill_row sc row c_code;
  let kb = string_of_int ((sc.sc_got + 1023) / 1024) ^ " KB" in
  let text =
    (if sc.sc_state = "reading" then "reading, " ^ kb
     else if sc.sc_state = "done" then
       kb ^ ", " ^ string_of_int (count sc.sc_page) ^ " lines"
       ^ (if sc.sc_nav.nv_fetch >= 0 then
            ", picture " ^ string_of_int (sc.sc_nav.nv_fetch + 1) ^ " of "
            ^ string_of_int (pictures sc.sc_page)
          else "")
     else sc.sc_state)
    ^ "   space -: page, b: back, g: address, q: quit" in
  put sc (d_text 0 c_black 8 (row * 16) (clip sc text))

(* The page's lines that fall in its area, from pixel [a] to pixel [b]
 * of the page, drawn; white where the page has ended. *)
let draw_between sc a b =
  let first = a / 16 and last = (b + 15) / 16 in
  let ls = lines_between sc.sc_page first last in
  List.iteri (fun k l -> draw_line sc (first + k) l) ls;
  let bottom = area_top + ((first + List.length ls) * 16) - sc.sc_y in
  let y0 = max bottom (area_top + a - sc.sc_y)
  and y1 = area_top + b - sc.sc_y in
  if y0 < y1 then put sc (d_fill 0 c_white 0 y0 (sc.sc_cols * 8) y1);
  first + List.length ls

(* the whole area drawn again *)
let redraw sc = sc.sc_drawn <- draw_between sc sc.sc_y (sc.sc_y + area sc)

let max_y sc = max 0 ((count sc.sc_page * 16) - area sc)

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
      put sc (d_draw 0 0 (-1) 0 area_top w (area_top + h - delta) 0
                (area_top + delta));
      sc.sc_y <- y;
      let first = (y + h - delta) / 16 in
      let drawn = draw_between sc (y + h - delta) (y + h) in
      if sc.sc_drawn >= first then sc.sc_drawn <- max sc.sc_drawn drawn
    end
    else begin
      put sc
        (d_draw 0 0 (-1) 0 (area_top - delta) w (area_top + h) 0 area_top);
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

(* the page from line [line] on, as far as the page allows *)
let show_from sc line =
  let y = max 0 (min (line * 16) (max_y sc)) in
  if y <> sc.sc_y then begin sc.sc_y <- y; redraw sc end

(* The lines that arrived and fit below the ones on the screen; and the
 * place a page was asked to show (back, or a #fragment), once it has
 * come. *)
let show_new sc =
  if sc.sc_nav.nv_goal_id <> "" then
    (match anchor sc.sc_page sc.sc_nav.nv_goal_id with
     | Some line
       when line + rows_of_page sc <= count sc.sc_page
            || sc.sc_nav.nv_wire < 0 ->
       sc.sc_nav.nv_goal_id <- ""; show_from sc line
     | _ -> ());
  if sc.sc_nav.nv_goal >= 0
     && ((sc.sc_nav.nv_goal / 16) + rows_of_page sc <= count sc.sc_page
         || sc.sc_nav.nv_wire < 0) then begin
    let goal = sc.sc_nav.nv_goal in
    sc.sc_nav.nv_goal <- -1;
    let y = max 0 (min goal (max_y sc)) in
    if y <> sc.sc_y then begin sc.sc_y <- y; redraw sc end
  end;
  let last = min (count sc.sc_page) ((sc.sc_y + area sc + 15) / 16) in
  if sc.sc_drawn < last then begin
    List.iteri (fun k l -> draw_line sc (sc.sc_drawn + k) l)
      (lines_between sc.sc_page sc.sc_drawn last);
    sc.sc_drawn <- last
  end

(* The mouse's look: a hand over a link, the arrow elsewhere (d_cursor:
 * the machine's window or page shows it). Sent when it changes. *)
let hover sc over =
  if over <> sc.sc_nav.nv_hover then begin
    sc.sc_nav.nv_hover <- over;
    put sc (d_cursor (if over then 1 else 0))
  end

(* Asks for the page at [url] (a full address), which replaces the one
 * shown; its #fragment, if any, is shown when it comes. *)
let load sc url =
  if sc.sc_nav.nv_wire >= 0 then ignore (u_close sc.sc_nav.nv_wire);
  for i = 0 to pictures sc.sc_page - 1 do
    if (picture_of sc.sc_page i).pc_got >= 0 then put sc (d_free (image_of i))
  done;
  sc.sc_nav.nv_fetch <- -1;
  hover sc false;
  let address, id = fragment url in
  sc.sc_page <- create sc.sc_cols;
  sc.sc_nav.nv_address <- address;
  sc.sc_nav.nv_goal_id <- id;
  sc.sc_y <- 0;
  sc.sc_got <- 0;
  sc.sc_state <- "reading";
  sc.sc_tools.tb_field <- url;
  draw_bar sc;
  draw_tools sc;
  redraw sc;
  (* the page asked of the wire's other end, on its port 70 *)
  sc.sc_nav.nv_wire <- u_dial "10.0.0.1" 70;
  if sc.sc_nav.nv_wire < 0 then begin
    sc.sc_state <- "www: no network (tiny-machine -net dir gives one)";
    finish sc.sc_page
  end
  else ignore (u_write sc.sc_nav.nv_wire ("www " ^ url ^ "\r\n"));
  draw_status sc

(* The pictures, once the page is all there: the next one asked of the
 * wire's other end, as "img w h address", the ones on the screen first,
 * then in the page's order. Its answer is a line "0 w h", then a row of
 * pixels a message, which go into the picture's image as they come. *)
let rec next_picture sc =
  let p = sc.sc_page in
  let pending id = (picture_of p id).pc_got = -1 in
  let rec on_screen = function
    | [] -> -1
    | (l : line) :: rest ->
        (match
           List.filter (fun (r : run) -> r.pic >= 0 && pending (r.pic / 256))
             l.runs
         with
         | r :: _ -> r.pic / 256
         | [] -> on_screen rest) in
  let rec first id =
    if id >= pictures p then -1 else if pending id then id else first (id + 1)
  in
  let id =
    match
      on_screen
        (lines_between p (sc.sc_y / 16) ((sc.sc_y + area sc + 15) / 16))
    with
    | -1 -> first 0
    | id -> id in
  if id >= 0 then begin
    let pc = picture_of p id in
    let fd = u_dial "10.0.0.1" 70 in
    if fd < 0 then begin pc.pc_got <- -2; next_picture sc end
    else begin
      pc.pc_got <- -3;
      let url = resolve sc.sc_nav.nv_address (base p) pc.pc_src in
      ignore (u_write fd ("img " ^ string_of_int pc.pc_w ^ " "
                          ^ string_of_int pc.pc_h ^ " " ^ url ^ "\r\n"));
      sc.sc_nav.nv_wire <- fd;
      sc.sc_nav.nv_fetch <- id
    end
  end;
  draw_status sc

(* A message of the picture being fetched: its first line, then its
 * rows. A row that comes is drawn at once if its slice is on the
 * screen, so a picture is painted as it arrives. *)
let picture_message sc s =
  let id = sc.sc_nav.nv_fetch in
  let pc = picture_of sc.sc_page id in
  if pc.pc_got = -3 then begin
    match String.split_on_char ' ' s with
    | [ _; w; h ] when number w = pc.pc_w && number h = pc.pc_h ->
        put sc (d_image (image_of id) 0 0 pc.pc_w pc.pc_h 255);
        pc.pc_got <- 0
    | _ -> pc.pc_got <- -2
  end
  else if pc.pc_got >= 0 && pc.pc_got < pc.pc_h then begin
    let y = pc.pc_got in
    put sc (d_pixels (image_of id) 0 y s);
    pc.pc_got <- y + 1;
    let slice = (id * 256) + (y / 16) and first = sc.sc_y / 16 in
    List.iteri (fun k (l : line) ->
      List.iter (fun (r : run) ->
        if r.pic = slice then begin
          let x = r.col * 8
          and sy = area_top + ((first + k) * 16) - sc.sc_y + (y mod 16) in
          if sy >= area_top && sy < area_top + area sc then
            put sc (d_draw 0 (image_of id) (-1) x sy (x + pc.pc_w) (sy + 1) 0 y)
        end) l.runs)
      (lines_between sc.sc_page first ((sc.sc_y + area sc + 15) / 16))
  end

(* Goes to an address, remembering where we were. A link to a place of
 * the page shown (#cite_note-2) only moves to it. *)
let go sc url =
  let address, id = fragment url in
  sc.sc_nav.nv_history <-
    (sc.sc_nav.nv_address, sc.sc_y) :: sc.sc_nav.nv_history;
  if address = sc.sc_nav.nv_address && id <> "" then begin
    (match anchor sc.sc_page id with
     | Some line -> show_from sc line
     | None -> ());
    sc.sc_tools.tb_field <- url;
    draw_tools sc;
    draw_status sc
  end
  else load sc url

(* Back to the page before, scrolled where it was: moved to if it is the
 * same page, asked for again if not. *)
let back sc =
  match sc.sc_nav.nv_history with
  | [] -> ()
  | (address, y) :: rest ->
      sc.sc_nav.nv_history <- rest;
      if address = sc.sc_nav.nv_address then begin
        let y = max 0 (min y (max_y sc)) in
        if y <> sc.sc_y then begin sc.sc_y <- y; redraw sc end;
        sc.sc_tools.tb_field <- address;
        draw_tools sc
      end
      else begin load sc address; sc.sc_nav.nv_goal <- y end

(* the link under the mouse, if any *)
let link_at sc x y =
  let col = x / 8 and line = (sc.sc_y + y - area_top) / 16 in
  if y < area_top || y >= area_top + area sc then None
  else
    match lines_between sc.sc_page line (line + 1) with
    | [ l ] ->
        (match
           List.filter (fun (r : run) ->
             r.link <> "" && col >= r.col
             && col < r.col + (String.length r.text
                               * if r.look land big <> 0 then 2 else 1))
             l.runs
         with
         | r :: _ -> Some r.link
         | [] -> None)
    | _ -> None

(* What a menu's item or a button does; false for Quit *)
let act sc a =
  (match a with
   | Back -> back sc
   | Top -> show_from sc 0
   | Reload -> load sc sc.sc_nav.nv_address
   | Quit -> ()
   | Address -> sc.sc_tools.tb_field <- ""; focus sc true; draw_tools sc
   | Go_to t -> go sc (absolute t)
   | Go_typed ->
     if sc.sc_tools.tb_field = "" then
       sc.sc_tools.tb_field <- sc.sc_nav.nv_address
     else go sc (absolute sc.sc_tools.tb_field)
   | Typed t -> sc.sc_tools.tb_field <- t);
  a <> Quit

(* the toolbar as a TinyLibGUI program: its model the field's text, its
 * messages our actions (only its mouse and its keys are TinyLibGUI's) *)
let toolbar sc =
  { init = ""; view = (fun _ -> Label "");
    update = (fun a _ -> ignore (act sc a); sc.sc_tools.tb_field);
    key = (fun _ -> []) }

(* The mouse: the menus' first, then the toolbar's; over a link it is a
 * hand; the left button pressed on a link follows it; the wheel (the
 * buttons 8 and 16, Plan 9's) scrolls. A menu that closes uncovers
 * the toolbar and the page, drawn again. False for Quit. *)
let on_mouse sc x y buttons =
  let st = sc.sc_tools.tb_menu in
  let was = st.opened and item = st.item in
  let answer = menu_mouse (menus sc) st x y buttons in
  if was >= 0 && st.opened <> was then begin draw_tools sc; redraw sc end;
  if st.opened <> was || st.item <> item then draw_bar sc;
  match answer with
  | Picked a -> act sc a
  | Taken -> true
  | Ignored ->
      let (_, boxes) = laid_tools sc in
      let (field, m) =
        mouse (toolbar sc) boxes sc.sc_tools.tb_field sc.sc_tools.tb_mouse
          x y buttons in
      let changed =
        field <> sc.sc_tools.tb_field
        || over boxes m <> over boxes sc.sc_tools.tb_mouse in
      sc.sc_tools.tb_field <- field;
      sc.sc_tools.tb_mouse <- m;
      if changed then draw_tools sc;
      hover sc (link_at sc x y <> None);
      if buttons land 1 <> 0 && not sc.sc_nav.nv_pressed then
        (match link_at sc x y with
         | Some href ->
           go sc (resolve sc.sc_nav.nv_address (base sc.sc_page) href)
         | None -> ());
      sc.sc_nav.nv_pressed <- buttons land 1 <> 0;
      if buttons land 8 <> 0 then scroll_by sc (-48);
      if buttons land 16 <> 0 then scroll_by sc 48;
      true

(* What a key does; false for q, which quits. While the field has the
 * keys (a click in it, or g), they are TinyLibGUI's: its characters,
 * Backspace; Enter goes, Escape gives up. Otherwise the arrows are 128
 * to 131 (up, down, left, right): up and down scroll a line (the wheel
 * and the trackpad come as these: tiny-machine's window and page send
 * a step of the wheel as an arrow), left and right a screenful, as -
 * and space do. Backspace is 8 or 127. *)
let on_key sc k =
  if focused sc then begin
    (if k = 10 || k = 13 then begin
       focus sc false; ignore (act sc Go_typed)
     end
     else if k = 27 then begin
       focus sc false; sc.sc_tools.tb_field <- sc.sc_nav.nv_address
     end
     else
       sc.sc_tools.tb_field <-
         key (toolbar sc) (snd (laid_tools sc)) sc.sc_tools.tb_field
           sc.sc_tools.tb_mouse k);
    draw_tools sc;
    true
  end
  else begin
    let page = area sc - 16 in
    (if k = Char.code ' ' || k = 131 then glide sc page
     else if k = Char.code '-' || k = 130 then glide sc (- page)
     else if k = 129 then scroll_by sc 16
     else if k = 128 then scroll_by sc (-16)
     else if k = Char.code 'b' || k = 8 || k = 127 then back sc
     else if k = Char.code 'g' then ignore (act sc Address));
    k <> Char.code 'q'
  end

(* the end: the page's connection closed, the screen white *)
let quit sc =
  if sc.sc_nav.nv_wire >= 0 then ignore (u_close sc.sc_nav.nv_wire);
  hover sc false;
  for row = 0 to sc.sc_rows - 1 do fill_row sc row c_white done;
  send sc

let browse typed =
  let w, h = window_size () in
  let nav =
    { nv_address = ""; nv_wire = -1; nv_history = []; nv_goal = -1;
      nv_goal_id = ""; nv_pressed = false; nv_fetch = -1; nv_hover = false } in
  let sc =
    { sc_page = create (w / 8); sc_nav = nav;
      sc_tools = { tb_field = ""; tb_mouse = up; tb_menu = menu_closed () };
      sc_cols = w / 8; sc_rows = h / 16; sc_y = 0; sc_drawn = 0;
      sc_got = 0; sc_state = "reading"; sc_msgs = [] } in
  put sc colours;
  put sc (d_image c_strip 0 0 (sc.sc_cols * 8) 16 255);
  load sc (absolute typed);
  send sc;
  let fds = Array.make 3 0 in
  (* [keys]: whether keys may still come. When they have ended and the
   * page is all there, the program ends and leaves the page on the
   * screen. *)
  let rec loop keys =
    if sc.sc_nav.nv_wire >= 0 || keys then begin
      let n = ref 0 in
      if keys then begin fds.(0) <- 0; fds.(1) <- 4; n := 2 end;
      if sc.sc_nav.nv_wire >= 0 then begin
        fds.(!n) <- sc.sc_nav.nv_wire; n := !n + 1
      end;
      let ready = u_ready fds !n 0 in
      if sc.sc_nav.nv_wire >= 0 && ready = sc.sc_nav.nv_wire
         && sc.sc_nav.nv_fetch >= 0 then begin
        let s = u_read sc.sc_nav.nv_wire 1024 in
        if s = "" then begin
          ignore (u_close sc.sc_nav.nv_wire);
          sc.sc_nav.nv_wire <- -1;
          let pc = picture_of sc.sc_page sc.sc_nav.nv_fetch in
          if pc.pc_got < 0 then pc.pc_got <- -2;
          sc.sc_nav.nv_fetch <- -1;
          next_picture sc
        end
        else picture_message sc s;
        send sc;
        loop keys
      end
      else if sc.sc_nav.nv_wire >= 0 && ready = sc.sc_nav.nv_wire then begin
        let s = u_read sc.sc_nav.nv_wire 1024 in
        if s = "" then begin
          finish sc.sc_page;
          ignore (u_close sc.sc_nav.nv_wire);
          sc.sc_nav.nv_wire <- -1;
          sc.sc_state <- "done";
          show_new sc; draw_bar sc; draw_status sc;
          next_picture sc
        end
        else begin
          let before = sc.sc_got / 16384 in
          sc.sc_got <- sc.sc_got + String.length s;
          feed sc.sc_page s;
          show_new sc;
          if sc.sc_got / 16384 <> before then draw_status sc
        end;
        send sc;
        loop keys
      end
      else if keys && ready = 4 then begin
        let s = u_read 4 12 in
        if String.length s = 12 && int16 s 8 >= 0
           && not (on_mouse sc (int16 s 0) (int16 s 4) (int16 s 8)) then quit sc
        else begin send sc; loop keys end
      end
      else if keys && ready = 0 then begin
        let typed = u_read 0 16 in
        if typed = "" then loop false
        else begin
          let rec each i =
            i >= String.length typed
            || (on_key sc (Char.code typed.[i]) && each (i + 1)) in
          if each 0 then begin send sc; loop keys end else quit sc
        end
      end
      else loop keys
    end in
  loop true
