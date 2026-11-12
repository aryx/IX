(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *
 * testing:
 * With no system calls, the office is tested on the host by typing keys
 * and moving the mouse at it (tests/TinyOffice_test.sh).
 *)

open TinyLibPlayground
open TinyLibGUI
open Model
open Text
open Sheet
open Drawing
open Paint
open Chart
open File

(* what a key or the mouse asks of the program around: nothing, to save
 * the file, to quit *)
type request = Continue | Save | Quit

let say (o : office) (m : string) = o.message <- m

let create (width : int) (height : int) (path : Fpath.t) (s : string)
    : office =
  let file = Fpath.to_string path in
  let page = parse width height s in
  let where = { file; width; height; shown = 0; pages = pages_in s } in
  { page; undo = []; clean = page; sel = None; editing = Nothing; drag = None;
    at = (16, 40); menu = menu_closed (); message = ""; prefix = false; where }

let saved (o : office) =
  o.clean <- o.page;
  o.message <- "Wrote " ^ o.where.file

(* the document's file (File's), for the program around *)
let text = File.text

(*****************************************************************************)
(* Editing a box *)
(*****************************************************************************)

(* what is being edited put back into its box: a text box's text, what
 * is typed in a cell *)
let commit (o : office) =
  if o.sel <> None then
    match o.editing with
    | Writing d -> change o (encode d.txt d.sty)
    | Cell (c, r, Some t) -> put_cell o c r t
    | _ -> ()

let finish (o : office) = commit o; o.editing <- Nothing

(*****************************************************************************)
(* The keys and the mouse *)
(*****************************************************************************)

let help =
  "the menus above; a click edits a box; its tab moves it, its corner resizes it"

let quit (o : office) : request =
  let refused = "Not saved: Save it, or Quit again" in
  if o.page == o.clean || o.message = refused then Quit
  else (o.message <- refused; Continue)


(* a new box where the last click was, of a kind, edited at once (the
 * menus' Insert) *)
let add (o : office) (kind : kind) (w : int) (h : int) =
  let x, y = o.at in
  keep o;
  let rec fresh k =
    let n = "sheet" ^ string_of_int k in
    if List.exists (fun (b : obj) -> b.called = n) o.page then fresh (k + 1)
    else n in
  o.page <-
    o.page @ [ { kind; x; y; w; h; data = "";
                 called = (if kind = Box_sheet then fresh 1 else "");
                 page_no = o.where.shown } ];
  let i = List.length o.page - 1 in
  o.sel <- Some i;
  match kind with
  | Box_text -> edit o i x y false
  | Box_sheet -> o.editing <- Cell (0, 0, None)
  | Box_paint -> o.editing <- Painting (1, 0, None)
  | _ -> o.editing <- Sketch (0, None)

(* what a menu's item asks for (the keys ask for the same) *)
let command (o : office) (c : command) : request =
  match c with
  | Do_save -> commit o; Save
  | Do_quit -> commit o; quit o
  | Do_undo ->
      finish o;
      (match o.undo with
       | p :: rest -> o.page <- p; o.undo <- rest; o.sel <- None; fit_pages o
       | [] -> o.message <- "No more undo");
      Continue
  | Do_delete ->
      finish o;
      (match o.sel with
       | Some i -> keep o; o.page <- replace o.page i None; o.sel <- None
       | None -> ());
      Continue
  | Do_add kind ->
      finish o;
      (match kind with
       | Box_sheet -> add o kind (26 + (4 * cell_w)) (18 + (6 * 16))
       | Box_drawing -> add o kind 300 160
       | Box_paint -> add o kind 200 124
       | _ -> add o Box_text 200 84);
      Continue
  | Do_tool t ->
      (match o.editing with
       | Sketch (_, _) -> o.editing <- Sketch (t, None)
       | _ -> ());
      Continue
  | Do_ink k ->
      (match o.editing with
       | Painting (_, brush, _) -> o.editing <- Painting (k, brush, None)
       | _ -> ());
      Continue
  | Do_brush k ->
      (match o.editing with
       | Painting (ink, _, _) -> o.editing <- Painting (ink, k, None)
       | _ -> ());
      Continue
  | Do_clear ->
      (match o.editing with Painting (_, _, _) -> change o "" | _ -> ());
      Continue
  | Do_cut ->
      (match o.editing with Writing d -> copy d; put_text d "" "" | _ -> ());
      Continue
  | Do_copy -> (match o.editing with Writing d -> copy d | _ -> ()); Continue
  | Do_paste ->
      (match o.editing with
       | Writing d -> let (t, st) = !clipboard in put_text d t st
       | _ -> ());
      Continue
  | Do_style bit ->
      (match o.editing with Writing d -> restyle d bit | _ -> ());
      Continue
  | Do_name ->
      (match o.editing with
       | Cell (_, _, _) -> commit o; o.editing <- Naming ""
       | _ -> ());
      Continue
  | Do_chart ->
      (match o.editing with
       | Cell (c, _, _) -> commit o; make_chart o c
       | _ -> ());
      Continue
  | Do_page d ->
      finish o;
      o.sel <- None;
      let p = o.where.shown + d in
      if p >= 0 && p < o.where.pages then o.where.shown <- p
      else
        o.message <- (if d > 0 then "No next page" else "No page before");
      Continue
  | Do_new_page ->
      (* a page after the one shown, the pages after moved one on *)
      finish o;
      keep o;
      let p = o.where.shown in
      o.page <-
        List.map (fun (b : obj) ->
          if b.page_no > p then { b with page_no = b.page_no + 1 } else b)
          o.page;
      o.where.pages <- o.where.pages + 1;
      o.where.shown <- p + 1;
      o.sel <- None;
      Continue
  | Do_delete_page ->
      (* the page shown and what is on it gone, the pages after moved
       * back *)
      finish o;
      if o.where.pages > 1 then begin
        keep o;
        let p = o.where.shown in
        o.page <-
          List.map (fun (b : obj) ->
            if b.page_no > p then { b with page_no = b.page_no - 1 } else b)
            (List.filter (fun (b : obj) -> b.page_no <> p) o.page);
        o.where.pages <- o.where.pages - 1;
        o.where.shown <- min p (o.where.pages - 1);
        o.sel <- None
      end
      else o.message <- "The one page is not deleted";
      Continue

(* the menus: File, Edit, Insert, the box's being edited (a text's
 * Format, a sheet's, a drawing's tools, a paint's colours: the one in
 * use marked), Page last (where it stays, as a Window menu); the keys
 * at the right *)
let office_menus (o : office) : (string * (string * command) list) list =
  [ ("File", [ ("Save     C-x C-s", Do_save); ("Quit     C-x C-c", Do_quit) ]);
    ("Edit", [ ("Undo       C-_", Do_undo); ("Cut        C-w", Do_cut);
               ("Copy", Do_copy); ("Paste      C-y", Do_paste);
               ("Delete box", Do_delete) ]);
    ("Insert", [ ("Text       C-o", Do_add Box_text);
                 ("Sheet    C-x t", Do_add Box_sheet);
                 ("Drawing  C-x d", Do_add Box_drawing);
                 ("Paint    C-x p", Do_add Box_paint) ]) ]
  @ (match o.editing with
     | Writing d ->
         let mark k s = (if d.typing land k <> 0 then "* " else "  ") ^ s in
         [ ("Format", [ (mark 1 "Bold       C-b", Do_style 1);
                        (mark 2 "Italic     Tab", Do_style 2);
                        (mark 4 "Underline  C-u", Do_style 4);
                        (mark 8 "Large      C-l", Do_style 8);
                        ("  Plain", Do_style 0) ]) ]
     | Cell (_, _, _) ->
         [ ("Sheet", [ ("Name...", Do_name);
                       ("Chart of this column", Do_chart) ]) ]
     | Painting (ink, brush, _) ->
         let colour k =
           ((if k = ink then "* " else "  ") ^ List.nth paint_names k
            ^ "      " ^ string_of_int k, Do_ink k) in
         [ ("Paint",
            List.init 10 colour
            @ [ ((if brush = 0 then "* " else "  ") ^ "Thin brush", Do_brush 0);
                ((if brush = 1 then "* " else "  ") ^ "Thick brush",
                 Do_brush 1);
                ("  Clear", Do_clear) ]) ]
     | Sketch (tool, _) ->
         let mark k s = (if k = tool then "* " else "  ") ^ s in
         [ ("Draw", [ (mark 0 "Box", Do_tool 0); (mark 1 "Arrow", Do_tool 1);
                      (mark 2 "Text", Do_tool 2) ]) ]
     | _ -> [])
  @ [ ("Page", [ ("Next      C-x ]", Do_page 1);
                 ("Previous  C-x [", Do_page (-1));
                 ("New page", Do_new_page);
                 ("Delete page", Do_delete_page) ]) ]

let key (o : office) (k : key) : request =
  (* C-x and C-_ (undo) are the office's even while a box is edited *)
  let own = k = Ctrl 'x' || k = Ctrl '_' in
  match o.editing with
  | Writing d when not o.prefix && not own ->
      o.message <- ""; write_key o d k; Continue
  | Cell (c, r, typed) when not o.prefix && k <> Ctrl 'x' ->
      o.message <- ""; cell_key o c r typed k; Continue
  | Sketch (tool, _) when not o.prefix && k <> Ctrl 'x' ->
      o.message <- ""; sketch_key o tool k; Continue
  | Painting (_, brush, _) when not o.prefix && not own ->
      o.message <- ""; paint_key o brush k; Continue
  | Naming typed when not o.prefix && k <> Ctrl 'x' ->
      o.message <- ""; name_key o typed k; Continue
  | _ ->
      let was = o.message in
      o.message <- "";
      if o.prefix then begin
        o.prefix <- false;
        match k with
        | Ctrl 's' -> command o Do_save
        | Ctrl ('c' | 'q') -> o.message <- was; command o Do_quit
        | Char 't' -> command o (Do_add Box_sheet)
        | Char 'd' -> command o (Do_add Box_drawing)
        | Char 'p' -> command o (Do_add Box_paint)
        | Char ']' -> command o (Do_page 1)
        | Char '[' -> command o (Do_page (-1))
        | _ -> o.message <- "C-x: not a command"; Continue
      end
      else begin
        (match k with
         | Ctrl 'x' -> o.prefix <- true
         | Ctrl 'o' -> ignore (command o (Do_add Box_text))
         | Backspace when o.sel <> None -> ignore (command o Do_delete)
         | Ctrl '_' -> ignore (command o Do_undo)
         | Ctrl 'g' -> o.sel <- None; o.message <- "Quit"
         | _ -> o.message <- help);
        Continue
      end

(* where the selected box is moved by the left button, its tab above
 * it (its kind written in it, or a sheet's name); where it is resized,
 * its corner *)
let tab_text (b : obj) =
  if b.called <> "" then b.called else kind_name b.kind
let tab (b : obj) = (b.x, b.y - 16, (8 * String.length (tab_text b)) + 8, 16)
let corner (b : obj) = (b.x + b.w - 8, b.y + b.h - 8, 8, 8)

let on_handle (o : office) (x : int) (y : int) : bool =
  o.sel <> None
  && (let b = selected_box o in inside x y (tab b) || inside x y (corner b))

(* box i grabbed by the mouse at (x, y), to move or to resize *)
let grab (o : office) (i : int) (x : int) (y : int) (resizing : bool) =
  keep o;
  o.drag <- Some (i, x, y, List.nth o.page i, resizing)

(* the grabbed box, the mouse now at (x, y): moved (its tab kept below
 * the menus), or resized *)
let dragged (o : office) (x : int) (y : int) =
  match o.drag with
  | Some (i, mx, my, was, resizing) when x <> mx || y <> my ->
      let moved =
        if resizing then
          { was with w = max 32 (was.w + x - mx); h = max 24 (was.h + y - my) }
        else
          { was with x = max 0 (was.x + x - mx);
                     y = max (bar_height + 16) (was.y + y - my) } in
      o.page <- replace o.page i (Some moved)
  | _ -> ()

(* (x, y) in drawing b, kept inside it *)
let in_drawing (b : obj) (x : int) (y : int) =
  (max 0 (min (b.w - 2) (x - b.x)), max 0 (min (b.h - 2) (y - b.y)))

(* The mouse on the page, its buttons b, was before. The mouse is a
 * place, not its history: a drag may be seen as a press and a let go
 * far apart, so the let go counts where it is. *)
let page_mouse (o : office) (was : int) (x : int) (y : int) (b : int) =
  let pressed k = b land k <> 0 && was land k = 0 in
  let i = hit o x y in
  (* the click is on the box being edited *)
  let on_it = pressed 1 && i <> None && i = o.sel in
  match o.editing with
  | _ when pressed 1 && on_handle o x y ->
      (* the selected box's tab or corner: it is moved or resized *)
      let resizing = inside x y (corner (selected_box o)) in
      finish o;
      grab o (selected o) x y resizing
  | Painting (ink, brush, _) when on_it ->
      (* in the paint being edited: a stroke begins, kept for undo *)
      let (c, r) = pixel_at (selected_box o) x y in
      keep o;
      paint o ink brush c r c r;
      o.editing <- Painting (ink, brush, Some (c, r))
  | Painting (ink, brush, Some (c0, r0)) ->
      (* the stroke goes on to where the mouse is, and ends where it is
       * let go *)
      let (c, r) = pixel_at (selected_box o) x y in
      paint o ink brush c0 r0 c r;
      o.editing <-
        Painting (ink, brush, if b land 1 <> 0 then Some (c, r) else None)
  | Writing d when on_it ->
      (* in the text being edited: the cursor there, a selection from it *)
      let ob = selected_box o in
      go_to d
        (index_at (lay_out (ob.w - 8) d.txt d.sty) d.txt d.sty (x - ob.x - 4)
           (y - ob.y - 2));
      d.selecting <- true
  | Writing d when d.selecting ->
      (* the selection follows the mouse, to where it is let go *)
      let ob = selected_box o in
      d.cur <-
        index_at (lay_out (ob.w - 8) d.txt d.sty) d.txt d.sty (x - ob.x - 4)
          (y - ob.y - 2);
      if b land 1 = 0 then d.selecting <- false
  | Sketch (tool, _) when on_it ->
      (* in the drawing being edited: a stroke begins *)
      let (sx, sy) = in_drawing (selected_box o) x y in
      o.editing <- Sketch (tool, Some (sx, sy, sx, sy))
  | Sketch (tool, Some (x0, y0, _, _)) ->
      (* the stroke follows the mouse; let go, it is a shape *)
      let (ex, ey) = in_drawing (selected_box o) x y in
      if b land 1 <> 0 then o.editing <- Sketch (tool, Some (x0, y0, ex, ey))
      else
        (o.editing <- Sketch (tool, None);
         draw_stroke o tool (x0, y0, ex, ey))
  | _ ->
  if pressed 1 then begin
    (* a click: the editing ends; in a text box, another begins *)
    finish o;
    o.at <- (x, y);
    o.sel <- i;
    match i with
    | Some i ->
        (match (List.nth o.page i).kind with
         | Box_text -> edit o i x y true
         | Box_sheet -> choose o i x y
         | Box_drawing -> o.editing <- Sketch (0, None)
         | Box_paint -> o.editing <- Painting (1, 0, None)
         | Box_chart -> ())
    | None -> ()
  end
  else if pressed 4 || pressed 2 then begin
    (* the right button: the box under it grabbed, by its corner to
     * resize *)
    finish o;
    o.sel <- i;
    match i with
    | Some i ->
        let b = List.nth o.page i in
        grab o i x y (x >= b.x + b.w - 12 && y >= b.y + b.h - 12)
    | None -> ()
  end
  else if b <> 0 then dragged o x y
  else begin
    (* let go: a box grabbed and not moved is no change to undo *)
    dragged o x y;
    (match o.drag, o.undo with
     | Some _, p :: rest when p == o.page -> o.undo <- rest
     | _ -> ());
    o.drag <- None
  end

(* the mouse: the menus' first, then the page's *)
let mouse (o : office) (x : int) (y : int) (b : int) : request =
  let was = o.menu.held in
  match menu_mouse (office_menus o) o.menu x y b with
  (* (Quit's refusal kept, as C-x C-c keeps it: Quit again quits; old:
   * cleared, and a page not saved was never left by the menu) *)
  | Picked c -> (if c <> Do_quit then o.message <- ""); command o c
  | Taken -> Continue
  | Ignored -> page_mouse o was x y b; Continue

(*****************************************************************************)
(* The view *)
(*****************************************************************************)


(* a box's frame: blue when it is selected, with its tab above it and a
 * small square at its corner, where the mouse moves it and resizes it *)
let frame (b : obj) (selected : bool) : shape list =
  let c = if selected then blue else grey
  and x1 = b.x + b.w - 1
  and y1 = b.y + b.h - 1 in
  let (tx, ty, tw, th) = tab b in
  [ Move (b.x, b.y, Rect (c, b.w, 1)); Move (b.x, y1, Rect (c, b.w, 1));
    Move (b.x, b.y, Rect (c, 1, b.h)); Move (x1, b.y, Rect (c, 1, b.h)) ]
  @ (if selected then
       [ Move (tx, ty, Rect (c, tw, th));
         Move (tx + 4, ty, Words (white, tab_text b));
         Move (x1 - 7, y1 - 7, Rect (c, 8, 8)) ]
     else [])

(* the status line: the page's message (what was just done, or why
 * not: it goes at the next key or click), or what the box being edited
 * says, or the file's name (old: a sheet's, a paint's or a drawing's
 * words over the message, and Quit's refusal not seen) *)
let status (o : office) : shape list =
  let file = o.where.file
  and width = o.where.width
  and height = o.where.height in
  let file =
    if o.where.pages > 1 then
      file ^ " (page " ^ string_of_int (o.where.shown + 1) ^ " of "
      ^ string_of_int o.where.pages ^ ")"
    else file in
  let said = if o.message <> "" then o.message else match o.editing with
    | Writing d ->
        let names =
          List.filter (fun t -> t <> "")
            (List.init 4 (fun k ->
               if d.typing land (1 lsl k) <> 0 then
                 List.nth [ "bold"; "italic"; "underlined"; "large" ] k
               else "")) in
        "text, typing "
        ^ (if names = [] then "plain" else String.concat " " names)
        ^ "; the Format menu, or C-b, Tab, C-u, C-l"
    | Cell (c, r, typed) when o.sel <> None ->
        (* the formula bar: the cell, what is being typed in it, or what
         * was *)
        name c r ^ ": "
        ^ (match typed with
           | Some t -> t ^ "_"
           | None -> typed_in (selected_box o).data (name c r))
    | Naming typed ->
        "the sheet's name: " ^ typed ^ "_ (Enter gives it, C-g not)"
    | Painting (ink, brush, _) ->
        "paint: " ^ List.nth paint_names ink
        ^ (if brush = 0 then ", thin" else ", thick")
        ^ "; the left button paints; the Paint menu, or a digit"
    | Sketch (tool, _) ->
        "drawing: " ^ List.nth tools tool
        ^ " (Tab: another); the left button draws; type a label"
    | _ -> "" in
  let m = if said <> "" then said
    else if o.prefix then "C-x-"
    else
      file ^ (if o.page == o.clean then "" else " (modified)") ^ "    "
      ^ help in
  let m =
    if String.length m * 8 > width - 8 then String.sub m 0 ((width - 8) / 8)
    else m in
  [ Move (0, height - 18, Rect (light_grey, width, 18));
    Move (4, height - 17, Words (black, m)) ]

let view (o : office) : shape list =
  let width = o.where.width and height = o.where.height in
  let i = ref (-1) in
  Rect (white, width, height)
  :: List.concat (List.map (fun (b : obj) ->
       incr i;
       if b.page_no <> o.where.shown then [] else
       let content = match o.editing with
         | Writing d when o.sel = Some !i -> text_view b d.txt d.sty (Some d)
         | Cell (c, r, _) when o.sel = Some !i -> sheet_view b (Some (c, r))
         | Sketch (tool, stroke) when o.sel = Some !i ->
             drawing_view b tool stroke
         | _ ->
             match b.kind with
             | Box_text -> let (t, st) = decode b.data in text_view b t st None
             | Box_sheet -> sheet_view b None
             | Box_drawing -> drawing_view b 0 None
             | Box_paint -> paint_view b
             | Box_chart -> chart_view o.page b in
       [ Group (frame b (o.sel = Some !i) @ content) ]) o.page)
  @ [ Group (status o) ] @ menu_view width (office_menus o) o.menu

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

(* The program, office: the document of a file on a canvas, its keys
 * and mouse, saved when it asks (user/office.ml its one line; old:
 * there whole) *)
module TSys = TinyLibSystem

let main caps argv =
  if Array.length argv <> 2 then begin
    TSys.eprint caps "usage: office file\n";
    Exit.Code 1
  end
  else
    let file = argv.(1) in
    let path = Fpath.v file in
    let text0 = try TSys.read_file caps path with Failure _ -> "" in
    let answer o r =
      match r with
      | Continue -> Some o
      | Save ->
        (try TSys.write_file caps path (text o); saved o
         with Failure _ -> say o ("Cannot write " ^ file));
        Some o
      | Quit -> None in
    run_canvas caps {
      first = (fun w h -> create w h path text0);
      picture = view;
      typed = (fun k o -> answer o (key o k));
      moved = (fun x y b o -> answer o (mouse o x y b)) };
    Exit.OK
