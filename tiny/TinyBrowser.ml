(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyBrowser.mli *)
module TSys = TinyLibSystem
module D = TinyLibDraw
module P = TinyLibPlayground
module G = TinyLibGUI
open Lines

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

let body (sc : Screen.screen) (media : string) s =
  match sc.sc_doc.dc_file with
  | Some fd -> (try TSys.write fd s with Failure _ -> ())
  | None ->
    if is_html media then Html.feed sc.sc_page s
    else if String.starts_with "text/" media then Html.feed sc.sc_page (escaped s)

(* Returns the body's media type: HTML when the head does not say, as
 * when there is no head. *)
let body_start caps (sc : Screen.screen) : string =
  let d = sc.sc_doc in
  let media =
    match Http.media_type d.dc_head with "" -> "text/html" | t -> t in
  d.dc_status <- Http.status d.dc_head;
  d.dc_type <- Some media;
  (match List.assoc_opt media helpers with
   | Some (_, file) ->
     d.dc_file <-
       (try Some (TSys.open_out caps (Fpath.v file)) with Failure _ -> None)
   | None ->
     if is_html media then ()
     else if String.starts_with "text/" media then Html.feed sc.sc_page "<pre>"
     else Html.feed sc.sc_page ("<p>" ^ media ^ ": www does not show it.</p>"));
  media

(* An answer that does not start with HTTP/ has no head: all of it is
 * body. *)
let take caps (sc : Screen.screen) s =
  let d = sc.sc_doc in
  match d.dc_type with
  | Some media -> body sc media s
  | None ->
    d.dc_head <- d.dc_head ^ s;
    let headless =
      String.length d.dc_head >= 5
      && not (String.starts_with "HTTP/" d.dc_head) in
    match (if headless then Some 0 else Http.head_end d.dc_head) with
    | None -> ()
    | Some e ->
      let rest = String.sub d.dc_head e (String.length d.dc_head - e) in
      d.dc_head <- String.sub d.dc_head 0 e;
      body sc (body_start caps sc) rest

(* The page's end: a helper's file closed and its program started *)
let body_end caps (sc : Screen.screen) =
  let d = sc.sc_doc in
  let media =
    match d.dc_type with
    | Some media -> media
    | None ->
      let rest = d.dc_head in
      d.dc_head <- "";
      let media = body_start caps sc in
      body sc media rest;
      media in
  match List.assoc_opt media helpers with
  | Some (prog, file) ->
    let what =
      match d.dc_file with
      | None -> "could not be kept in " ^ file
      | Some fd ->
        TSys.close fd;
        d.dc_file <- None;
        if TSys.spawn caps (Fpath.v ("/bin/" ^ prog)) [ prog; file ] = None then
          "kept in " ^ file ^ ", but there is no " ^ prog ^ " to show it"
        else "kept in " ^ file ^ ", given to " ^ prog in
    Html.feed sc.sc_page ("<p>" ^ media ^ ": " ^ what ^ ".</p>")
  | None -> ()

(* A refused connection or write is no reason for www to end. *)
let dialed caps =
  try Some (TSys.dial caps "10.0.0.1" 70) with Failure _ -> None
let wire_write fd s = try TSys.write fd s with Failure _ -> ()

let hang_up (sc : Screen.screen) =
  (match sc.sc_nav.nv_wire with
   | Wire_page fd -> TSys.close fd
   | Wire_picture (fd, _) -> TSys.close fd
   | Wire_off -> ());
  sc.sc_nav.nv_wire <- Wire_off

(* Asks for the page at [url] (a full address), which replaces the one
 * shown; its #fragment, if any, is shown when it comes. *)
let load caps (sc : Screen.screen) url =
  hang_up sc;
  for i = 0 to Html.pictures sc.sc_page - 1 do
    match (Html.picture_of sc.sc_page i).pc_got with
    | Pic_rows _ -> Screen.put sc (D.d_free (Screen.image_of i))
    | _ -> ()
  done;
  Screen.hover sc false;
  let address, id = Url.fragment url in
  sc.sc_page <- Html.create sc.sc_cols;
  sc.sc_nav.nv_address <- address;
  sc.sc_nav.nv_goal_id <- id;
  sc.sc_y <- 0;
  (match sc.sc_doc.dc_file with
   | Some fd -> TSys.close fd
   | None -> ());
  sc.sc_doc.dc_got <- 0;
  sc.sc_doc.dc_head <- "";
  sc.sc_doc.dc_type <- None;
  sc.sc_doc.dc_status <- None;
  sc.sc_doc.dc_file <- None;
  sc.sc_state <- Page_reading;
  sc.sc_tools.tb_field <- url;
  Screen.draw_bar sc;
  Screen.draw_tools sc;
  Screen.redraw sc;
  (match dialed caps with
   | None ->
       sc.sc_state <-
         Page_none "www: no network (tiny-machine -net dir gives one)";
       Html.finish sc.sc_page
   | Some fd ->
       sc.sc_nav.nv_wire <- Wire_page fd;
       wire_write fd (Http.request url));
  Screen.draw_status sc

(* The pictures, once the page is all there: the next one asked of the
 * wire's other end, as "img w h address", the ones on the screen first,
 * then in the page's order. Its answer is a line "0 w h", then a row of
 * pixels a message, which go into the picture's image as they come. *)
let rec next_picture caps (sc : Screen.screen) =
  let p = sc.sc_page in
  let pending id = (Html.picture_of p id).pc_got = Pic_unasked in
  let rec on_screen = function
    | [] -> None
    | (l : line) :: rest ->
        (match
           List.filter_map (fun (r : run) ->
             match r.part with
             | Run_slice (id, _) when pending id -> Some id
             | _ -> None) l.runs
         with
         | id :: _ -> Some id
         | [] -> on_screen rest) in
  let rec first id =
    if id >= Html.pictures p then None
    else if pending id then Some id
    else first (id + 1) in
  let next =
    match
      on_screen
        (Html.lines_between p (sc.sc_y / 16) ((sc.sc_y + Screen.area sc + 15) / 16))
    with
    | Some id -> Some id
    | None -> first 0 in
  (match next with
   | None -> ()
   | Some id ->
    let pc = Html.picture_of p id in
    (match dialed caps with
     | None -> pc.pc_got <- Pic_failed; next_picture caps sc
     | Some fd ->
         pc.pc_got <- Pic_asked;
         let url = Url.resolve sc.sc_nav.nv_address (Html.base p) pc.pc_src in
         wire_write fd ("img " ^ string_of_int pc.pc_w ^ " "
                        ^ string_of_int pc.pc_h ^ " " ^ url ^ "\r\n");
         sc.sc_nav.nv_wire <- Wire_picture (fd, id)));
  Screen.draw_status sc

(* A message of the picture being fetched: its first line, then its
 * rows. A row that comes is drawn at once if its slice is on the
 * screen, so a picture is painted as it arrives. *)
let picture_message (sc : Screen.screen) (id : int) s =
  let pc = Html.picture_of sc.sc_page id in
  match pc.pc_got with
  | Pic_asked -> (
    match String.split_on_char ' ' s with
    | [ _; w; h ] when Strings.number w = pc.pc_w && Strings.number h = pc.pc_h ->
        Screen.put sc (D.d_image (Screen.image_of id) (0, 0, pc.pc_w, pc.pc_h) 255);
        pc.pc_got <- Pic_rows 0
    | _ -> pc.pc_got <- Pic_failed)
  | Pic_rows y when y < pc.pc_h ->
    Screen.put sc (D.d_pixels (Screen.image_of id) (0, y) s);
    pc.pc_got <- Pic_rows (y + 1);
    let slice = Run_slice (id, y / 16) and first = sc.sc_y / 16 in
    List.iteri (fun k (l : line) ->
      List.iter (fun (r : run) ->
        if r.part = slice then begin
          let x = r.col * 8
          and sy = Screen.area_top + ((first + k) * 16) - sc.sc_y + (y mod 16) in
          if sy >= Screen.area_top && sy < Screen.area_top + Screen.area sc then
            Screen.put sc
              (D.d_draw 0 (Screen.image_of id) (-1)
                 (x, sy, x + pc.pc_w, sy + 1) (0, y))
        end) l.runs)
      (Html.lines_between sc.sc_page first ((sc.sc_y + Screen.area sc + 15) / 16))
  | _ -> ()

(* Goes to an address, remembering where we were. A link to a place of
 * the page shown (#cite_note-2) only moves to it. *)
let go caps (sc : Screen.screen) url =
  let address, id = Url.fragment url in
  sc.sc_nav.nv_history <-
    (sc.sc_nav.nv_address, sc.sc_y) :: sc.sc_nav.nv_history;
  match id with
  | Some id when address = sc.sc_nav.nv_address ->
      (match Html.anchor sc.sc_page id with
       | Some line -> Screen.show_from sc line
       | None -> ());
      sc.sc_tools.tb_field <- url;
      Screen.draw_tools sc;
      Screen.draw_status sc
  | _ -> load caps sc url

(* Back to the page before, scrolled where it was: moved to if it is the
 * same page, asked for again if not. *)
let back caps (sc : Screen.screen) =
  match sc.sc_nav.nv_history with
  | [] -> ()
  | (address, y) :: rest ->
      sc.sc_nav.nv_history <- rest;
      if address = sc.sc_nav.nv_address then begin
        let y = max 0 (min y (Screen.max_y sc)) in
        if y <> sc.sc_y then begin sc.sc_y <- y; Screen.redraw sc end;
        sc.sc_tools.tb_field <- address;
        Screen.draw_tools sc
      end
      else begin load caps sc address; sc.sc_nav.nv_goal <- Some y end

let link_at (sc : Screen.screen) x y =
  let col = x / 8 and line = (sc.sc_y + y - Screen.area_top) / 16 in
  if y < Screen.area_top || y >= Screen.area_top + Screen.area sc then None
  else
    match Html.lines_between sc.sc_page line (line + 1) with
    | [ l ] ->
        (match
           List.filter (fun (r : run) ->
             r.link <> None && col >= r.col
             && col < r.col + (String.length r.text
                               * if r.look land big <> 0 then 2 else 1))
             l.runs
         with
         | r :: _ -> r.link
         | [] -> None)
    | _ -> None

(* What a menu's item or a button does; false for Quit *)
let act caps (sc : Screen.screen) (a : Screen.act) =
  (match a with
   | Back -> back caps sc
   | Top -> Screen.show_from sc 0
   | Reload -> load caps sc sc.sc_nav.nv_address
   | Quit -> ()
   | Address ->
       sc.sc_tools.tb_field <- ""; Screen.focus sc true; Screen.draw_tools sc
   | Search ->
       sc.sc_tools.tb_field <- "?"; Screen.focus sc true; Screen.draw_tools sc
   | Go_to t -> go caps sc (Url.absolute t)
   | Go_typed ->
     if sc.sc_tools.tb_field = "" then
       sc.sc_tools.tb_field <- sc.sc_nav.nv_address
     else go caps sc (Url.absolute sc.sc_tools.tb_field)
   | Typed t -> sc.sc_tools.tb_field <- t);
  a <> Quit

(* the toolbar as a TinyLibGUI program: its model the field's text, its
 * messages our actions (only its mouse and its keys are TinyLibGUI's) *)
let toolbar caps (sc : Screen.screen) : (string, Screen.act) G.gui =
  { init = ""; view = (fun _ -> G.Label "");
    update = (fun a _ -> ignore (act caps sc a); sc.sc_tools.tb_field);
    key = (fun _ -> []) }

(* The mouse: the menus' first, then the toolbar's; over a link it is a
 * hand; the left button pressed on a link follows it; the wheel (the
 * buttons 8 and 16, Plan 9's) scrolls. A menu that closes uncovers
 * the toolbar and the page, drawn again. False for Quit. *)
let on_mouse caps (sc : Screen.screen) x y buttons =
  let st = sc.sc_tools.tb_menu in
  let was = st.opened and item = st.item in
  let answer = G.menu_mouse (Screen.menus sc) st x y buttons in
  if was <> None && st.opened <> was then begin
    Screen.draw_tools sc; Screen.redraw sc
  end;
  if st.opened <> was || st.item <> item then Screen.draw_bar sc;
  match answer with
  | G.Picked a -> act caps sc a
  | G.Taken -> true
  | G.Ignored ->
      let (_, boxes) = Screen.laid_tools sc in
      let (field, m) =
        G.mouse (toolbar caps sc) boxes sc.sc_tools.tb_field sc.sc_tools.tb_mouse
          x y buttons in
      let changed =
        field <> sc.sc_tools.tb_field
        || G.over boxes m <> G.over boxes sc.sc_tools.tb_mouse in
      sc.sc_tools.tb_field <- field;
      sc.sc_tools.tb_mouse <- m;
      if changed then Screen.draw_tools sc;
      Screen.hover sc (link_at sc x y <> None);
      if buttons land 1 <> 0 && not sc.sc_nav.nv_pressed then
        (match link_at sc x y with
         | Some href ->
           go caps sc (Url.resolve sc.sc_nav.nv_address (Html.base sc.sc_page) href)
         | None -> ());
      sc.sc_nav.nv_pressed <- buttons land 1 <> 0;
      if buttons land 8 <> 0 then Screen.scroll_by sc (-48);
      if buttons land 16 <> 0 then Screen.scroll_by sc 48;
      true

(* What a key does; false for q, which quits. While the field has the
 * keys (a click in it, g, or s), they are TinyLibGUI's: its characters,
 * Backspace; Enter goes, Escape gives up. Otherwise up and down scroll
 * a line (the wheel and the trackpad come as these: tiny-machine's
 * window and page send a step of the wheel as an arrow), left and right
 * a screenful, as - and space do. *)
let on_key caps (sc : Screen.screen) (k : P.key) : bool =
  if Screen.focused sc then begin
    (match k with
     | P.Enter -> Screen.focus sc false; ignore (act caps sc Go_typed)
     | P.Escape ->
         Screen.focus sc false; sc.sc_tools.tb_field <- sc.sc_nav.nv_address
     | _ ->
         sc.sc_tools.tb_field <-
           G.key (toolbar caps sc) (snd (Screen.laid_tools sc)) sc.sc_tools.tb_field
             sc.sc_tools.tb_mouse k);
    Screen.draw_tools sc;
    true
  end
  else begin
    let page = Screen.area sc - 16 in
    (match k with
     | P.Char ' ' | P.Right -> Screen.glide sc page
     | P.Char '-' | P.Left -> Screen.glide sc (- page)
     | P.Down -> Screen.scroll_by sc 16
     | P.Up -> Screen.scroll_by sc (-16)
     | P.Char 'b' | P.Backspace -> back caps sc
     | P.Char 'g' -> ignore (act caps sc Address)
     | P.Char 's' -> ignore (act caps sc Search)
     | _ -> ());
    k <> P.Char 'q'
  end

let quit (sc : Screen.screen) =
  hang_up sc;
  Screen.hover sc false;
  for row = 0 to sc.sc_rows - 1 do Screen.fill_row sc row Screen.c_white done;
  Screen.send sc

let browse caps typed =
  let w, h = G.window_size caps in
  let nav : Screen.nav =
    { nv_address = ""; nv_wire = Wire_off; nv_history = []; nv_goal = None;
      nv_goal_id = None; nv_pressed = false; nv_hover = false } in
  let sc : Screen.screen =
    { sc_page = Html.create (w / 8); sc_nav = nav;
      sc_tools = { tb_field = ""; tb_mouse = G.up; tb_menu = G.menu_closed () };
      sc_cols = w / 8; sc_rows = h / 16; sc_y = 0; sc_drawn = 0;
      sc_doc = { dc_got = 0; dc_head = ""; dc_type = None; dc_status = None;
                 dc_file = None };
      sc_state = Page_reading; sc_msgs = [] } in
  Screen.put sc Screen.colours;
  Screen.put sc (D.d_image Screen.c_strip (0, 0, sc.sc_cols * 8, 16) 255);
  load caps sc (Url.absolute typed);
  Screen.send sc;
  (* [keys]: whether keys may still come. When they have ended and the
   * page is all there, the program ends and leaves the page on the
   * screen. *)
  let rec loop keys =
    let wire =
      match sc.sc_nav.nv_wire with
      | Wire_page fd -> [ fd ]
      | Wire_picture (fd, _) -> [ fd ]
      | Wire_off -> [] in
    if wire <> [] || keys then begin
      let fds = (if keys then [ TSys.fd_stdin; TSys.fd_mouse ] else []) @ wire in
      (* (the first ready; -1 none, which TSys.ready without a deadline
       * does not answer) *)
      let ready = match TSys.ready fds None with Some n -> n | None -> -1 in
      match sc.sc_nav.nv_wire with
      | Wire_picture (fd, id) when ready = fd ->
        let s = TSys.read fd 1024 in
        if s = "" then begin
          hang_up sc;
          let pc = Html.picture_of sc.sc_page id in
          (match pc.pc_got with
           | Pic_rows _ -> ()
           | _ -> pc.pc_got <- Pic_failed);
          next_picture caps sc
        end
        else picture_message sc id s;
        Screen.send sc;
        loop keys
      | Wire_page fd when ready = fd ->
        let s = TSys.read fd 1024 in
        if s = "" then begin
          body_end caps sc;
          Html.finish sc.sc_page;
          hang_up sc;
          sc.sc_state <- Page_done;
          (* a page that sends us on (a search's result), not to itself *)
          let on =
            Url.resolve sc.sc_nav.nv_address (Html.base sc.sc_page)
              (Html.refresh sc.sc_page) in
          if Html.refresh sc.sc_page <> "" && on <> sc.sc_nav.nv_address then
            load caps sc on
          else begin
            Screen.show_new sc; Screen.draw_bar sc; Screen.draw_status sc;
            next_picture caps sc
          end
        end
        else begin
          let before = sc.sc_doc.dc_got / 16384 in
          sc.sc_doc.dc_got <- sc.sc_doc.dc_got + String.length s;
          take caps sc s;
          Screen.show_new sc;
          if sc.sc_doc.dc_got / 16384 <> before then Screen.draw_status sc
        end;
        Screen.send sc;
        loop keys
      | _ when keys && ready = TSys.fd_mouse ->
        (match D.mouse_event (TSys.read TSys.fd_mouse 12) with
         | Some e when e.mo_buttons >= 0
                       && not (on_mouse caps sc e.mo_x e.mo_y e.mo_buttons) ->
             quit sc
         | _ -> Screen.send sc; loop keys)
      | _ when keys && ready = TSys.fd_stdin ->
        let typed = TSys.read TSys.fd_stdin 16 in
        if typed = "" then loop false
        else begin
          let rec each i =
            i >= String.length typed
            || (on_key caps sc (P.key_of_byte typed.[i]) && each (i + 1)) in
          if each 0 then begin Screen.send sc; loop keys end else quit sc
        end
      | _ -> loop keys
    end in
  loop true

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

(* www address, or www words to search; user/www.ml calls it. *)
let main caps argv =
  if Array.length argv < 2 then begin
    TinyLibSystem.eprint caps "usage: www address\n";
    Exit.Code 1
  end
  else begin
    browse caps
      (String.concat " " (Array.to_list (Array.sub argv 1 (Array.length argv - 1))));
    Exit.OK
  end
