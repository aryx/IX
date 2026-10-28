(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyBrowser.mli *)
open TinyCalls
open TinyLibDraw
open TinyLibGUI
open TinyBrowserText
open TinyBrowserLines
open TinyBrowserHtml
open TinyBrowserAddress
open TinyBrowserHttp
open TinyBrowserScreen

(*****************************************************************************)
(* The browsing *)
(*****************************************************************************)

(* What www does not show itself, given to a program that does, as
 * Mosaic's helpers: a Content-Type, the program in /bin, and the file
 * its bytes are kept in, in the current directory, for it to read *)
let helpers =
  [ "audio/wav", ("play", "www.wav"); "audio/x-wav", ("play", "www.wav");
    "audio/wave", ("play", "www.wav");
    "application/pdf", ("page", "www.pdf") ]

let is_html kind = kind = "text/html" || kind = "application/xhtml+xml"

(* a text as HTML's characters, for a text/plain shown in a <pre> *)
let escaped s =
  String.concat ""
    (List.init (String.length s) (fun i ->
       match s.[i] with
       | '<' -> "&lt;"
       | '&' -> "&amp;"
       | c -> String.make 1 c))

(* bytes of the body: read as HTML, as a text, or kept for a helper *)
let body sc s =
  let d = sc.sc_doc in
  if d.dc_file >= 0 then ignore (u_write d.dc_file s)
  else if is_html d.dc_type then feed sc.sc_page s
  else if String.starts_with "text/" d.dc_type then feed sc.sc_page (escaped s)

(* The head's end: the status, and what the body is (HTML when the head
 * does not say, as when there is no head) *)
let body_start sc =
  let d = sc.sc_doc in
  d.dc_status <- status d.dc_head;
  d.dc_type <- (match media_type d.dc_head with "" -> "text/html" | t -> t);
  match List.assoc_opt d.dc_type helpers with
  | Some (_, file) -> d.dc_file <- u_open file 0x601
  | None ->
    if is_html d.dc_type then ()
    else if String.starts_with "text/" d.dc_type then feed sc.sc_page "<pre>"
    else feed sc.sc_page ("<p>" ^ d.dc_type ^ ": www does not show it.</p>")

(* A message of the page: the head kept until it ends, then the body *)
let take sc s =
  let d = sc.sc_doc in
  if d.dc_type <> "" then body sc s
  else begin
    d.dc_head <- d.dc_head ^ s;
    let headless =
      String.length d.dc_head >= 5
      && not (String.starts_with "HTTP/" d.dc_head) in
    let e = if headless then 0 else head_end d.dc_head in
    if e >= 0 then begin
      let rest = String.sub d.dc_head e (String.length d.dc_head - e) in
      d.dc_head <- String.sub d.dc_head 0 e;
      body_start sc;
      body sc rest
    end
  end

(* The page's end: a helper's file closed and its program started *)
let body_end sc =
  let d = sc.sc_doc in
  if d.dc_type = "" then begin
    let rest = d.dc_head in
    d.dc_head <- "";
    body_start sc;
    body sc rest
  end;
  match List.assoc_opt d.dc_type helpers with
  | Some (prog, file) ->
    let what =
      if d.dc_file < 0 then "could not be kept in " ^ file
      else begin
        ignore (u_close d.dc_file);
        d.dc_file <- -1;
        if u_spawn ("/bin/" ^ prog) [ prog; file ] < 0 then
          "kept in " ^ file ^ ", but there is no " ^ prog ^ " to show it"
        else "kept in " ^ file ^ ", given to " ^ prog
      end in
    feed sc.sc_page ("<p>" ^ d.dc_type ^ ": " ^ what ^ ".</p>")
  | None -> ()

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
  if sc.sc_doc.dc_file >= 0 then ignore (u_close sc.sc_doc.dc_file);
  sc.sc_doc.dc_got <- 0;
  sc.sc_doc.dc_head <- "";
  sc.sc_doc.dc_type <- "";
  sc.sc_doc.dc_status <- 0;
  sc.sc_doc.dc_file <- -1;
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
  else ignore (u_write sc.sc_nav.nv_wire (request url));
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
   | Search -> sc.sc_tools.tb_field <- "?"; focus sc true; draw_tools sc
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
 * keys (a click in it, g, or s), they are TinyLibGUI's: its characters,
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
     else if k = Char.code 'g' then ignore (act sc Address)
     else if k = Char.code 's' then ignore (act sc Search));
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
      sc_doc = { dc_got = 0; dc_head = ""; dc_type = ""; dc_status = 0;
                 dc_file = -1 };
      sc_state = "reading"; sc_msgs = [] } in
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
          body_end sc;
          finish sc.sc_page;
          ignore (u_close sc.sc_nav.nv_wire);
          sc.sc_nav.nv_wire <- -1;
          sc.sc_state <- "done";
          (* a page that sends us on (a search's result), not to itself *)
          let on =
            resolve sc.sc_nav.nv_address (base sc.sc_page)
              (refresh sc.sc_page) in
          if refresh sc.sc_page <> "" && on <> sc.sc_nav.nv_address then
            load sc on
          else begin
            show_new sc; draw_bar sc; draw_status sc;
            next_picture sc
          end
        end
        else begin
          let before = sc.sc_doc.dc_got / 16384 in
          sc.sc_doc.dc_got <- sc.sc_doc.dc_got + String.length s;
          take sc s;
          show_new sc;
          if sc.sc_doc.dc_got / 16384 <> before then draw_status sc
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
