(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)

(* mini-page: a PDF file's pages, or a picture, looked at
 * (docs/plans/done/plan_pdf.md), after Plan 9's page(1).
 *
 * Plan 9's page is a viewer round other programs: Ghostscript draws a
 * PostScript or a PDF file's pages, jpg and png read a picture, and
 * page shows what they give it. Here the drawing is in the program:
 * lib_graphics/pdf reads the file and draws a page (Pdf_render), each
 * page is a picture, a Bitmap of Playground's, and the pages are one
 * under another, a gap of grey between, the window going along them
 * (as most viewers today; Plan 9's page shows one page, and the next
 * is a key away). No PostScript: there is no interpreter of it here.
 *
 *   file's bytes --Pdf--> pages --Pdf_render, at a zoom--> pictures
 *                                                             |
 *                     keys and mouse: which page, the         v
 *                     zoom, a turn, how far down     the window's Bitmaps
 *
 * A page is drawn when it first comes into the window at a zoom and a
 * turn; the pictures in the window are kept, and the last few others
 * (a page is megabytes): going back to the page before is at once.
 * The model is a value, as every Playground program's; a page's
 * picture is made in the update (the view only shows), which is why a
 * key that changes the page takes the time of its drawing. Where a
 * page is down the pages is worked out again each frame from the
 * pages' sizes (tops): a thousand pages are a thousand additions,
 * nothing next to drawing one.
 *
 * A picture (PNG, JPEG) is a document of one page, scaled and turned
 * as it is shown, not drawn again.
 *
 * Not done: page's menu of the pages (a number and Enter goes to
 * one); a file's outline and links; text found or copied (-t prints
 * a file's words).
 *
 * Where it stands. It is the reader of what mini-office writes:
 * Office_export makes a document a PDF file (Shape_render_pdf,
 * Pdf_write) and this program shows it, so the two ends of the
 * format are in ix and the tests of the one use the other. The
 * readers of pictures are mini-office's too (Image_file, over Png
 * and Jpeg). Like mini-office it is a
 * Playground program and knows no window: Colors (apps/misc) is the
 * other kind, a program that talks to the draw device itself.
 *
 * cs-history:
 * PostScript (Adobe, 1984) describes a page by a program: a
 * language with loops and procedures whose running draws, which is
 * why showing page 300 means running the 299 before it, and why a
 * viewer of it is an interpreter. PDF (Adobe, 1993) kept
 * PostScript's way of drawing and dropped the language: each page a
 * plain list of operators, the pages found by a table at the end of
 * the file, so that any page can be shown first (Pdf_render.mli,
 * Pdf_write.mli). Plan 9's page handed both to Ghostscript, a
 * PostScript interpreter that also reads PDF; with PDF alone the
 * interpreter is not needed, and the whole reader fits in a
 * library.
 *
 * References: page(1). ISO 32000-1:2008, the PDF 1.7 reference.
 * docs/plans/done/plan_pdf.md. *)

let usage =
  "usage: mini-page file            a PDF file's pages, or a picture (PNG, JPEG), in a window\n\
  \       mini-page -t file         the words of each page, printed\n\
  \       mini-page -ppm n file out page n's picture written to out (a PPM), a pixel a point\n\
   in the window:\n\
  \  space, PageDown, right        the next page\n\
  \  Backspace, PageUp, left       the page before\n\
  \  a number, then Enter          that page\n\
  \  up, down, the wheel           the pages moved along\n\
  \  the mouse's button held       drags them\n\
  \  + and -                       larger, smaller;  f  the window's width again\n\
  \  r                             a quarter turn;   q  the end\n"

(*****************************************************************************)
(* A document *)
(*****************************************************************************)

type source =
  | Pages of Pdf.t * Pdf_render.cache * Pdf.page array
  | Picture of Rgba_image.t
  (* why not, shown in the window *)
  | Nothing of string

(* a file by its first bytes *)
let source (bytes : string) : source =
  try
    if Pdf.sniff bytes then
      let pdf = Pdf.of_string bytes in
      Pages (pdf, Pdf_render.cache (), Array.of_list (Pdf.pages pdf))
    else if Image_file.known bytes then Picture (Image_file.decode bytes)
    else Nothing "neither a PDF file nor a picture (PNG, JPEG)"
  with Failure why -> Nothing why

let count (s : source) : int = match s with Pages (_, _, pages) -> Array.length pages | Picture _ | Nothing _ -> 1

(* a page's size in points (a picture's: its pixels), turned *)
let size (s : source) (page : int) (turn : int) : float * float =
  let w, h =
    match s with
    | Pages (_, _, pages) -> Pdf_render.size pages.(page)
    | Picture img -> (float img.width, float img.height)
    | Nothing _ -> (1., 1.)
  in
  if turn mod 2 = 1 then (h, w) else (w, h)

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

(* a picture kept: of which page, at which zoom (in thousandths) and turn *)
type kept = { page : int; zoom : int; turn : int; image : Rgba_image.t }

type model = {
  name : string;
  source : source;
  (* from 0: the one gone to, or at the window's middle once moved along *)
  page : int;
  zoom : float; (* pixels a point *)
  turn : int; (* quarter turns, clockwise: 0 to 3 *)
  (* the pages one under another: how far down them the window's top
   * is, in pixels, and where their middle is across the window *)
  down : float;
  x : float;
  (* the pictures drawn, those in the window first *)
  kept : kept list;
  (* a page's number being typed *)
  number : string;
  (* the frame before: the keys held, and where the mouse held the pages *)
  was : string list;
  held : (float * float) option;
  quit : unit -> unit;
}

(* pictures kept besides the window's *)
let keep = 3

let thousandths (zoom : float) : int =
  int_of_float (Float.round (zoom *. 1000.))

(* points between two pages, and above the first and below the last *)
let gap = 8.

(* where each page's top is down the pages, in pixels; the last of the
 * array is their whole height *)
let tops (m : model) : float array =
  let n = count m.source in
  let a = Array.make (n + 1) (gap *. m.zoom) in
  for i = 0 to n - 1 do
    let _, h = size m.source i m.turn in
    a.(i + 1) <- a.(i) +. ((h +. gap) *. m.zoom)
  done;
  a

(* the window's height above the status line *)
let status_line = 30.
let room (s : Playground.screen) : float = s.height -. status_line

(* the pages in the window *)
let shown (s : Playground.screen) (m : model) : int list =
  let tops = tops m in
  let inside (i : int) =
    tops.(i + 1) -. (gap *. m.zoom) > m.down && tops.(i) < m.down +. room s
  in
  List.filter inside (List.init (count m.source) (fun (i : int) -> i))

(* the page at the window's middle *)
let middle (s : Playground.screen) (m : model) : int =
  let tops = tops m and at = m.down +. (room s /. 2.) in
  let rec find (i : int) : int =
    if i + 1 < count m.source && tops.(i + 1) <= at then find (i + 1) else i
  in
  find 0

(* the window within the pages: not past their ends; pages shorter
 * than the window in its middle *)
let within (s : Playground.screen) (m : model) : model =
  let total = (tops m).(count m.source) and room = room s in
  let down =
    if total <= room then (total -. room) /. 2.
    else Float.max 0. (Float.min m.down (total -. room))
  in
  { m with down }

(* the window's pages' pictures, drawn if they are not kept. A PDF's
 * page is drawn at the zoom and turned by the reader (sharp at any
 * size); a picture is kept as it is, and the view scales and turns it *)
let drawn (s : Playground.screen) (m : model) : model =
  match m.source with
  | Pages (pdf, cache, pages) ->
      let zoom = thousandths m.zoom in
      let is (i : int) (k : kept) =
        k.page = i && k.zoom = zoom && k.turn = m.turn
      in
      let draw (i : int) : kept =
        let p = pages.(i) in
        let p = { p with rotate = (p.rotate + (90 * m.turn)) mod 360 } in
        let image =
          Pdf_render.render ~options:Pdf_render.full
            ~stroke_glyph:Pdf_render.hershey pdf cache p ~scale:m.zoom
        in
        { page = i; zoom; turn = m.turn; image }
      in
      let shown = shown s m in
      let now =
        List.map
          (fun (i : int) ->
            match List.find_opt (is i) m.kept with
            | Some k -> k
            | None -> draw i)
          shown
      in
      let others =
        List.filter
          (fun (k : kept) -> not (List.exists (fun (i : int) -> is i k) shown))
          m.kept
      in
      let others = List.filteri (fun (i : int) (_ : kept) -> i < keep) others in
      { m with kept = now @ others }
  | Picture _ | Nothing _ -> m

(* another page, its top at the window's *)
let go (page : int) (m : model) : model =
  let page = max 0 (min (count m.source - 1) page) in
  { m with page; down = (tops m).(page) -. (gap *. m.zoom) }

(* the page as wide as the window, less a margin each side (a picture:
 * no larger than it is; no page: as it is), from its top *)
let fit (width : float) (m : model) : model =
  let w, _ = size m.source m.page m.turn in
  let zoom = (width -. 40.) /. w in
  let zoom =
    match m.source with
    | Picture _ -> Float.min 1. zoom
    | Nothing _ -> 1.
    | Pages _ -> zoom
  in
  go m.page { m with zoom; x = 0. }

let start (name : string) (bytes : string) ~(quit : unit -> unit) : model =
  let s =
    Playground.to_screen Playground.default_width Playground.default_height
  in
  let m =
    { name; source = source bytes; page = 0; zoom = 1.; turn = 0;
      down = 0.; x = 0.; kept = []; number = ""; was = []; held = None;
      quit }
  in
  drawn s (within s (fit s.width m))

(*****************************************************************************)
(* The update *)
(*****************************************************************************)

let zoomed (s : Playground.screen) (by : float) (m : model) : model =
  let zoom = Float.max 0.1 (Float.min 8. (m.zoom *. by)) in
  (* what is at the window's middle stays there *)
  let half = room s /. 2. and by = zoom /. m.zoom in
  { m with zoom; x = m.x *. by; down = ((m.down +. half) *. by) -. half }

let update (computer : Playground.computer) (m : model) : model =
  let s = computer.screen in
  let k = computer.keyboard and mouse = computer.mouse in
  let now = Set_.elements k.keys in
  let pressed (key : string) = List.mem key now && not (List.mem key m.was) in
  let digits =
    String.concat ""
      (List.filter
         (fun (s : string) -> s >= "0" && s <= "9")
         (List.init (String.length k.typed) (fun (i : int) ->
              String.make 1 k.typed.[i])))
  in
  let typed (c : char) = String.contains k.typed c in
  let m = { m with number = m.number ^ digits } in
  let m =
    if pressed "Enter" && m.number <> "" then
      { (go (int_of_string m.number - 1) m) with number = "" }
    else if pressed "Escape" then { m with number = "" }
    else if pressed "space" || pressed "PageDown" || pressed "ArrowRight"
    then go (m.page + 1) m
    else if pressed "Backspace" || pressed "PageUp" || pressed "ArrowLeft"
    then go (m.page - 1) m
    else if typed '+' || typed '=' then zoomed s 1.25 m
    else if typed '-' then zoomed s 0.8 m
    else if typed 'f' then fit s.width m
    else if typed 'r' then fit s.width { m with turn = (m.turn + 1) mod 4 }
    else if typed 'q' then (m.quit (); m)
    else m
  in
  let m = within s m in
  (* the pages moved along: the arrows held, the wheel, the mouse
   * dragging them; the page is then the one at the middle *)
  let step =
    (if k.kup then -30. else 0.) +. (if k.kdown then 30. else 0.)
    -. (mouse.mwheel *. 60.)
  in
  let before = m.down in
  let m = { m with down = m.down +. step } in
  let m =
    match (mouse.mdown, m.held) with
    | true, Some (hx, hy) -> { m with x = mouse.mx -. hx; down = mouse.my +. hy }
    | true, None -> { m with held = Some (mouse.mx -. m.x, m.down -. mouse.my) }
    | false, _ -> { m with held = None }
  in
  let m = within s m in
  let m = if m.down <> before then { m with page = middle s m } else m in
  drawn s { m with was = now }

(*****************************************************************************)
(* The view *)
(*****************************************************************************)

let view (computer : Playground.computer) (m : model) : Playground.shape list =
  let s = computer.screen in
  let tops = tops m in
  let page (i : int) : Playground.shape list =
    (* its middle, up the window *)
    let _, h = size m.source i m.turn in
    let y = s.top -. (tops.(i) +. (h *. m.zoom /. 2.) -. m.down) in
    match m.source with
    | Pages _ -> (
        let zoom = thousandths m.zoom in
        let is (k : kept) = k.page = i && k.zoom = zoom && k.turn = m.turn in
        match List.find_opt is m.kept with
        | Some k ->
            (* its corner on a pixel, not its centre (a picture of an odd
             * width has its centre in the middle of one): the pixels are
             * then shown as they are, none blended with its neighbour *)
            let w = float k.image.width and h = float k.image.height in
            let on_pixel (centre : float) (size : float) =
              Float.round (centre -. (size /. 2.)) +. (size /. 2.)
            in
            [ Playground.bitmap w h k.image
              |> Playground.move (on_pixel m.x w) (on_pixel y h) ]
        | None -> [])
    | Picture img ->
        (* (turned by the shape's angle, which goes the other way) *)
        let w = float img.width *. m.zoom and h = float img.height *. m.zoom in
        [ Playground.bitmap w h img
          |> Playground.rotate (-90. *. float m.turn)
          |> Playground.move m.x y ]
    | Nothing why -> [ Playground.words Playground.black why ]
  in
  let w, h = size m.source m.page m.turn in
  let status =
    Printf.sprintf "%s     page %d of %d     %d%%     %d by %d%s" m.name
      (m.page + 1) (count m.source)
      (int_of_float (Float.round (m.zoom *. 100.)))
      (int_of_float (Float.round w)) (int_of_float (Float.round h))
      (if m.number = "" then "" else "     go to page " ^ m.number)
  in
  let grey = Playground.rgb 120 120 128 in
  let bar = s.bottom +. (status_line /. 2.) in
  (Playground.rectangle grey s.width s.height
   :: List.concat_map page (shown s m))
  @ [
      Playground.rectangle (Playground.rgb 225 225 225) s.width status_line
      |> Playground.move 0. bar;
      Playground.words (Playground.rgb 40 40 40) status
      |> Playground.move 0. bar;
    ]

(*****************************************************************************)
(* Without a window *)
(*****************************************************************************)

(* a picture as a PPM: three bytes a pixel after a line of text *)
let ppm (img : Rgba_image.t) : string =
  let b = Buffer.create ((3 * img.width * img.height) + 20) in
  Buffer.add_string b (Printf.sprintf "P6\n%d %d\n255\n" img.width img.height);
  for i = 0 to (img.width * img.height) - 1 do
    Buffer.add_string b (Bytes.sub_string img.rgba (4 * i) 3)
  done;
  Buffer.contents b

let pages_of (bytes : string) : Pdf.t * Pdf_render.cache * Pdf.page array =
  match source bytes with
  | Pages (pdf, cache, pages) -> (pdf, cache, pages)
  | Picture _ -> failwith "a picture has no pages"
  | Nothing why -> failwith why

let () =
  Cap.main (fun caps ->
      let read (file : string) : string = FS.read caps (Fpath.v file) in
      (* (-help: the usage, and the end, Exit.ExitCode) *)
      Exit.exit caps @@ Exit.catch @@ fun () ->
      (try
        match Array.to_list (CapSys.argv caps) with
        | [ _; "-t"; file ] ->
            let pdf, cache, pages = pages_of (read file) in
            Array.iteri
              (fun (i : int) (p : Pdf.page) -> Console.print caps (Printf.sprintf "-- page %d\n%s\n" (i + 1) (Pdf_render.text pdf cache p)))
              pages
        | [ _; "-ppm"; n; file; out ] ->
            let pdf, cache, pages = pages_of (read file) in
            let n = int_of_string n in
            if n < 1 || n > Array.length pages then failwith (Printf.sprintf "%s has %d page(s)" file (Array.length pages));
            FS.write caps (Fpath.v out) (ppm (Pdf_render.render ~options:Pdf_render.full ~stroke_glyph:Pdf_render.hershey pdf cache pages.(n - 1) ~scale:1.))
        | _ -> (
            let flags = Playground_platform.flags caps in
            (* the file: the first word that is no name=value *)
            match List.find_opt (fun ((_, value) : string * string) -> value = "") flags with
            | None -> failwith usage
            | Some (file, _) ->
                let model = start (Filename.basename file) (read file) ~quit:(fun () -> CapStdlib.exit caps 0) in
                (* heap=modest: a page's picture is megabytes kept, not a
                 * game's floats of a frame (Plan9_loop says what it changes) *)
                Playground_platform.run_app caps (("heap", "modest") :: flags) (Playground.game view update model))
      with Failure msg ->
        Console.eprint caps (msg ^ "\n");
        CapStdlib.exit caps 1);
      Exit.OK)
