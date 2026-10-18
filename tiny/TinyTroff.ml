(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyTroff.mli *)
open TinyOffice

(* strings joined (TinyLibStd's String.concat, two by two) *)
let glue (l : string list) : string = String.concat "" l


(* a string's characters, each as a string *)
let chars (s : string) : string list = List.init (String.length s) (fun i -> String.make 1 s.[i])

(* the objects in reading order: by their page, their top, their left *)
let rec in_order (l : obj list) : obj list =
  let rec insert (b : obj) l =
    match l with
    | (c : obj) :: rest when c.page_no < b.page_no || (c.page_no = b.page_no && (c.y < b.y || (c.y = b.y && c.x <= b.x))) -> c :: insert b rest
    | _ -> b :: l in
  match l with b :: rest -> insert b (in_order rest) | [] -> []

(* the parts in reading order, a list a page (to the last page that has
 * a part) *)
let pages_of (parts : obj list) : obj list list =
  let n = List.fold_left (fun m (b : obj) -> max m (b.page_no + 1)) 1 parts in
  List.init n (fun p -> List.filter (fun (b : obj) -> b.page_no = p) parts)

(* a text's lines, each its characters and their styles *)
let styled_lines (data : string) : (string * string) list =
  let (t, st) = decode data in
  let rec go i =
    match String.index_from_opt t i '\n' with
    | Some e -> (String.sub t i (e - i), String.sub st i (e - i)) :: go (e + 1)
    | None -> [ (String.sub t i (String.length t - i), String.sub st i (String.length t - i)) ] in
  if t = "" then [] else go 0

(* a line all large: a heading *)
let heading (t : string) (st : string) = t <> "" && String.for_all (fun c -> Char.code c land 8 <> 0) st

(* a sheet's size, its columns and rows; each cell's value as it is
 * shown, and whether it is a number (at the right), an error *)
let sheet_size (data : string) : int * int =
  List.fold_left (fun (nc, nr) (n, _) ->
    let r = match int_of_string_opt (String.sub n 1 (String.length n - 1)) with Some r -> r | None -> 1 in
    (max nc (Char.code n.[0] - 96), max nr r)) (0, 0) (cells data)

let shown (value : string -> value) (data : string) (c : int) (r : int) : string * bool * bool =
  let n = name c r in
  if not (List.exists (fun (m, _) -> m = n) (cells data)) then ("", false, false)
  else match value n with
    | Num k -> (string_of_int k, true, false)
    | Str s -> (s, false, false)
    | Err e -> ("#" ^ e, false, true)

(*****************************************************************************)
(* Text *)
(*****************************************************************************)

(* a line's words filled to a width *)
let fill (width : int) (line : string) : string list =
  let words = List.filter (fun w -> w <> "") (String.split_on_char ' ' line) in
  let rec go cur acc = function
    | w :: rest ->
        if cur = "" then go w acc rest
        else if String.length cur + 1 + String.length w <= width then go (cur ^ " " ^ w) acc rest
        else go w (cur :: acc) rest
    | [] -> List.rev (if cur = "" then acc else cur :: acc) in
  match go "" [] words with [] -> [ "" ] | l -> l

(* a text box: each line filled, a heading underlined with = *)
let text_lines (width : int) (data : string) : string list =
  List.concat (List.map (fun (t, st) -> if heading t st then [ t; String.make (String.length t) '=' ] else fill width t) (styled_lines data))

(* a sheet: its values in columns, a number at its column's right *)
let sheet_lines (data : string) : string list =
  let value = values data and (nc, nr) = sheet_size data in
  let cols = List.init nc (fun c -> c) in
  let wide = List.map (fun c -> List.fold_left (fun m r -> let (s, _, _) = shown value data c r in max m (String.length s)) 1 (List.init nr (fun r -> r))) cols in
  List.init nr (fun r ->
    glue (List.map2 (fun c w ->
      let (s, num, _) = shown value data c r in
      let pad = String.make (w - String.length s) ' ' in
      (if c = 0 then "" else "  ") ^ (if num then pad ^ s else s ^ pad)) cols wide))

(* the rows of a grid of characters, without the spaces at their ends,
 * nor the empty rows at its end *)
let grid_lines (g : string array array) : string list =
  let rec trim l = match l with "" :: rest -> trim rest | l -> l in
  let rows = List.init (Array.length g) (fun r ->
    let n = ref (Array.length g.(r)) in
    while !n > 0 && g.(r).(!n - 1) = " " do decr n done;
    glue (List.init !n (fun c -> g.(r).(c)))) in
  List.rev (trim (List.rev rows))

(* A drawing as characters, one for 8 by 8 pixels: a box's sides of -
 * and |, its corners +, its label in its middle; a text where it is;
 * then an arrow across then up or down, in the places left (a box's
 * side is not drawn over), its head > < v ^ before the box it goes
 * to *)
let drawing_lines (b : obj) : string list =
  let cols = (b.w + 7) / 8 and rows = (b.h + 7) / 8 in
  let g = Array.make rows (Array.make 0 " ") in
  for r = 0 to rows - 1 do g.(r) <- Array.make cols " " done;
  let inside c r = c >= 0 && c < cols && r >= 0 && r < rows in
  let put c r s = if inside c r then g.(r).(c) <- s in
  let free c r = inside c r && g.(r).(c) = " " in
  let put_free c r s = if free c r then g.(r).(c) <- s in
  let label c r s = List.iteri (fun k ch -> put (c + k) r ch) (chars s) in
  let shapes = figures b.data in
  List.iter (fun (kind, nums, text) ->
    match kind, nums with
    | "box", [ x; y; w; h ] ->
        let c0 = x / 8 and r0 = y / 8 and c1 = (x + w) / 8 and r1 = (y + h) / 8 in
        for c = c0 to c1 do put c r0 "-"; put c r1 "-" done;
        for r = r0 to r1 do put c0 r "|"; put c1 r "|" done;
        List.iter (fun (c, r) -> put c r "+") [ (c0, r0); (c1, r0); (c0, r1); (c1, r1) ];
        label ((c0 + c1 + 1 - String.length text) / 2) ((r0 + r1) / 2) text
    | "text", [ x; y ] -> label (x / 8) ((y + 8) / 8) text
    | _ -> ()) shapes;
  List.iter (fun (kind, nums, _) ->
    match kind, nums with
    | "arrow", [ x0; y0; x1; y1 ] ->
        let c0 = x0 / 8 and r0 = y0 / 8 and c1 = x1 / 8 and r1 = y1 / 8 in
        let dc = if r1 <> r0 then 0 else if c1 >= c0 then 1 else -1 and dr = if r1 > r0 then 1 else if r1 < r0 then -1 else 0 in
        let hc, hr = if free c1 r1 then c1, r1 else c1 - dc, r1 - dr in
        for c = min c0 c1 to max c0 c1 do put_free c r0 "-" done;
        for r = min r0 r1 to max r0 r1 do put_free c1 r "|" done;
        if r1 <> r0 then put c1 r0 "+";
        put hc hr (if dr > 0 then "v" else if dr < 0 then "^" else if dc > 0 then ">" else "<")
    | _ -> ()) shapes;
  grid_lines g

(* a paint: its rows, white a space *)
let paint_lines (data : string) : string list =
  let rows = List.map (fun row -> glue (List.map (fun ch -> if ch = "." then " " else ch) (chars row))) (String.split_on_char '\n' data) in
  let rec trim l = match l with "" :: rest -> trim rest | l -> l in
  List.rev (trim (List.rev rows))

(* a chart: a line a bar, its label, #s for its share of the largest
 * (30 for it), its value; or why it has none *)
let chart_lines (page : obj list) (b : obj) : string list =
  match chart_bars page b with
  | [], why -> [ "[" ^ why ^ "]" ]
  | bars, _ ->
      let top = List.fold_left (fun m (_, v) -> max m v) 1 bars and wide = List.fold_left (fun m (l, _) -> max m (String.length l)) 0 bars in
      List.map (fun (l, v) -> l ^ String.make (wide - String.length l) ' ' ^ "  " ^ String.make (max 0 (v * 30 / top)) '#' ^ " " ^ string_of_int v) bars

let to_text (width : int) (doc : string) : string =
  let parts = in_order (parse 640 480 doc) in
  let one (b : obj) =
    if b.kind = "sheet" then sheet_lines b.data
    else if b.kind = "drawing" then drawing_lines b
    else if b.kind = "paint" then paint_lines b.data
    else if b.kind = "chart" then chart_lines parts b
    else text_lines width b.data in
  let page bs = List.concat (List.mapi (fun k b -> (if k = 0 then [] else [ "" ]) @ one b) bs) in
  (* (a page after a form feed, as nroff's) *)
  let pages = List.map page (pages_of parts) in
  glue (List.map (fun l -> l ^ "\n") (List.concat (List.mapi (fun k ls -> (if k = 0 then [] else [ "\012" ]) @ ls) pages)))

(*****************************************************************************)
(* HTML *)
(*****************************************************************************)

(* a text in HTML: & < > and the double quote written as entities *)
let esc (s : string) : string =
  glue (List.map (fun ch -> if ch = "&" then "&amp;" else if ch = "<" then "&lt;" else if ch = ">" then "&gt;" else if ch = "\"" then "&quot;" else ch) (chars s))

(* a style's tags, opening and closing *)
let opens (k : int) = (if k land 8 <> 0 then "<span class=l>" else "") ^ (if k land 4 <> 0 then "<u>" else "") ^ (if k land 2 <> 0 then "<i>" else "") ^ (if k land 1 <> 0 then "<b>" else "")
let closes (k : int) = (if k land 1 <> 0 then "</b>" else "") ^ (if k land 2 <> 0 then "</i>" else "") ^ (if k land 4 <> 0 then "</u>" else "") ^ (if k land 8 <> 0 then "</span>" else "")

(* a line's characters, each run of a style in its tags (without the
 * styles of base, the line's own) *)
let runs_html (t : string) (st : string) (base : int) : string =
  let n = String.length t in
  let rec go i was acc =
    if i >= n then glue (List.rev (closes was :: acc))
    else begin
      let k = Char.code st.[i] land lnot base in
      go (i + 1) k (esc (String.make 1 t.[i]) :: (if k <> was then opens k :: closes was :: acc else acc))
    end in
  go 0 0 []

(* a text box: a line a paragraph, a heading an h1, an empty line an
 * empty paragraph (the page's place kept) *)
let text_html (data : string) : string =
  glue (List.map (fun (t, st) ->
    if heading t st then "<h1>" ^ runs_html t st 8 ^ "</h1>\n"
    else if t = "" then "<p>&nbsp;</p>\n"
    else "<p>" ^ runs_html t st 0 ^ "</p>\n") (styled_lines data))

(* a sheet: a table of its values *)
let sheet_html (data : string) : string =
  let value = values data and (nc, nr) = sheet_size data in
  "<table>\n"
  ^ glue (List.init nr (fun r ->
      "<tr>" ^ glue (List.init nc (fun c ->
        let (s, num, err) = shown value data c r in
        "<td" ^ (if num then " class=n" else if err then " class=e" else "") ^ ">" ^ esc s ^ "</td>")) ^ "</tr>\n"))
  ^ "</table>\n"

(* a drawing: SVG, its boxes, arrows (a line across then up or down, a
 * head of three points) and texts *)
let drawing_html (b : obj) : string =
  let num k = string_of_int k in
  let svg_text x y anchor s = "<text x=\"" ^ num x ^ "\" y=\"" ^ num y ^ "\" text-anchor=\"" ^ anchor ^ "\" dominant-baseline=\"middle\">" ^ esc s ^ "</text>" in
  "<svg width=\"" ^ num b.w ^ "\" height=\"" ^ num b.h ^ "\">\n"
  ^ glue (List.map (fun (kind, nums, text) ->
      match kind, nums with
      | "box", [ x; y; w; h ] ->
          "<rect x=\"" ^ num x ^ "\" y=\"" ^ num y ^ "\" width=\"" ^ num w ^ "\" height=\"" ^ num h ^ "\" fill=\"none\" stroke=\"black\"/>"
          ^ (if text = "" then "" else svg_text (x + (w / 2)) (y + (h / 2)) "middle" text) ^ "\n"
      | "arrow", [ x0; y0; x1; y1 ] ->
          let dx, dy = if y1 > y0 then 0, -1 else if y1 < y0 then 0, 1 else if x1 >= x0 then -1, 0 else 1, 0 in
          let p x y = num x ^ "," ^ num y in
          "<polyline points=\"" ^ p x0 y0 ^ " " ^ p x1 y0 ^ " " ^ p x1 y1 ^ "\" fill=\"none\" stroke=\"black\"/>"
          ^ "<polygon points=\"" ^ p x1 y1 ^ " " ^ p (x1 + (6 * dx) - (4 * dy)) (y1 + (6 * dy) - (4 * dx)) ^ " " ^ p (x1 + (6 * dx) + (4 * dy)) (y1 + (6 * dy) + (4 * dx)) ^ "\"/>\n"
      | "text", [ x; y ] -> svg_text x (y + 8) "start" text ^ "\n"
      | _ -> "") (figures b.data))
  ^ "</svg>\n"

(* a paint: SVG, each run of a colour on a row a rectangle (white left
 * out), 4 by 4 a pixel *)
let colours = [ ('k', "#000"); ('r', "#f00"); ('g', "#0a0"); ('b', "#00f"); ('y', "#ff0"); ('o', "#e90"); ('p', "#80c"); ('n', "#840"); ('a', "#888") ]

let paint_html (b : obj) : string =
  let num k = string_of_int k in
  let row r line =
    let n = String.length line in
    let rec go i acc =
      if i >= n then acc
      else begin
        let j = ref (i + 1) in
        while !j < n && line.[!j] = line.[i] do incr j done;
        go !j (match List.assoc_opt line.[i] colours with
               | Some c -> ("<rect x=\"" ^ num (4 * i) ^ "\" y=\"" ^ num (4 * r) ^ "\" width=\"" ^ num (4 * (!j - i)) ^ "\" height=\"4\" fill=\"" ^ c ^ "\"/>") :: acc
               | None -> acc)
      end in
    go 0 [] in
  let lines = String.split_on_char '\n' b.data in
  "<svg width=\"" ^ num (b.w - 4) ^ "\" height=\"" ^ num (b.h - 4) ^ "\" shape-rendering=\"crispEdges\">\n"
  ^ glue (List.map (fun s -> s ^ "\n") (List.concat (List.mapi (fun r line -> List.rev (row r line)) lines)))
  ^ "</svg>\n"

(* a chart: SVG, as the office draws it: a bar a value, its value above
 * it, its label under it, the axis a grey line *)
let bar_colours = [ "#00f"; "#f00"; "#0a0"; "#ff0"; "#e90"; "#80c" ]

let chart_html (page : obj list) (b : obj) : string =
  let num k = string_of_int k in
  let txt x y s = "<text x=\"" ^ num x ^ "\" y=\"" ^ num y ^ "\">" ^ esc s ^ "</text>" in
  "<svg width=\"" ^ num b.w ^ "\" height=\"" ^ num b.h ^ "\">\n"
  ^ (match chart_bars page b with
     | [], why -> txt 4 14 why ^ "\n"
     | bars, _ ->
         let n = List.length bars and top = List.fold_left (fun m (_, v) -> max m v) 1 bars in
         let bw = max 6 ((b.w - 16) / n) and base = b.h - 20 and room = b.h - 42 in
         glue (List.mapi (fun k (label, v) ->
           let x = 8 + (k * bw) and tall = max 0 (v * room / top) in
           "<rect x=\"" ^ num (x + 2) ^ "\" y=\"" ^ num (base - tall) ^ "\" width=\"" ^ num (bw - 4) ^ "\" height=\"" ^ num tall ^ "\" fill=\"" ^ List.nth bar_colours (k mod 6) ^ "\"/>"
           ^ txt (x + 2) (base - tall - 4) (string_of_int v) ^ txt (x + 2) (base + 14) label ^ "\n") bars)
         ^ "<line x1=\"4\" y1=\"" ^ num base ^ "\" x2=\"" ^ num (b.w - 4) ^ "\" y2=\"" ^ num base ^ "\" stroke=\"#999\"/>\n")
  ^ "</svg>\n"

let style = "body{margin:16px;font:13px/16px monospace}.page{position:relative;margin-bottom:16px}.page+.page{border-top:1px dashed #ccc}.box{position:absolute;overflow:hidden}"
  ^ "p{margin:0;min-height:16px}h1,.l{font-size:26px;line-height:32px}h1{margin:0}"
  ^ "table{border-collapse:collapse}td{border:1px solid #ccc;padding:0 4px;height:15px;min-width:56px}td.n{text-align:right}td.e{color:#c00}"

let to_html (title : string) (doc : string) : string =
  let parts = in_order (parse 640 480 doc) in
  let num k = string_of_int k in
  (* a page: a block the size of its parts, each part at its place *)
  let page bs =
    let width = List.fold_left (fun m (b : obj) -> max m (b.x + b.w)) 0 bs and height = List.fold_left (fun m (b : obj) -> max m (b.y + b.h)) 0 bs in
    "<div class=page style=\"width:" ^ num width ^ "px;height:" ^ num height ^ "px\">\n"
    ^ glue (List.map (fun (b : obj) ->
        "<div class=box style=\"left:" ^ num b.x ^ "px;top:" ^ num b.y ^ "px;width:" ^ num b.w ^ "px;height:" ^ num b.h ^ "px\">\n"
        ^ (if b.kind = "sheet" then sheet_html b.data
           else if b.kind = "drawing" then drawing_html b
           else if b.kind = "paint" then paint_html b
           else if b.kind = "chart" then chart_html parts b
           else text_html b.data)
        ^ "</div>\n") bs)
    ^ "</div>\n" in
  glue ([ "<!doctype html>\n<html><head><meta charset=\"utf-8\"><title>"; esc title; "</title>\n<style>"; style; "</style></head>\n<body>\n" ]
        @ List.map page (pages_of parts)
        @ [ "</body></html>\n" ])

(*****************************************************************************)
(* PDF *)
(*****************************************************************************)

(* A page of PDF for each page of the document, all the size of the
 * largest, a pixel a point: its text in Courier, one of the fonts every
 * reader has (no font carried), which at 13.33 points is 8 points a
 * character, the office's 8 by 16 (its bold, oblique and both for the
 * styles, twice the size for large); its lines and rectangles as PDF
 * draws them. Not compressed: a page is a text of drawing operators,
 * which a test reads. *)

(* a text in a PDF string: \ ( ) after a \ *)
let pdf_esc (s : string) : string =
  glue (List.map (fun ch -> if ch = "\\" || ch = "(" || ch = ")" then "\\" ^ ch else ch) (chars s))

(* colours, as PDF's three numbers: the paint's and the bars' *)
let pdf_colours = [ ('k', "0 0 0"); ('r', "1 0 0"); ('g', "0 .67 0"); ('b', "0 0 1"); ('y', "1 1 0"); ('o', "1 .6 0"); ('p', ".53 0 .8"); ('n', ".53 .27 0"); ('a', ".53 .53 .53") ]
let pdf_bars = [ "0 0 1"; "1 0 0"; "0 .67 0"; "1 1 0"; "1 .6 0"; ".53 0 .8" ]

(* The operators of a page of height h, its y going down as the
 * office's: a rectangle filled, one stroked, a line, a text whose top
 * is at y (its baseline 12 points lower, 24 when large), in a style *)
let fill h colour x y w hh = colour ^ " rg " ^ string_of_int x ^ " " ^ string_of_int (h - y - hh) ^ " " ^ string_of_int w ^ " " ^ string_of_int hh ^ " re f\n"
let frame_pdf h colour x y w hh = colour ^ " RG " ^ string_of_int x ^ " " ^ string_of_int (h - y - hh) ^ " " ^ string_of_int w ^ " " ^ string_of_int hh ^ " re S\n"
let line_pdf h colour x0 y0 x1 y1 = colour ^ " RG " ^ string_of_int x0 ^ " " ^ string_of_int (h - y0) ^ " m " ^ string_of_int x1 ^ " " ^ string_of_int (h - y1) ^ " l S\n"
let text_pdf h style x y s =
  let big = style land 8 <> 0 in
  "0 0 0 rg BT /F" ^ string_of_int (style land 3) ^ " " ^ (if big then "26.67" else "13.33") ^ " Tf " ^ string_of_int x ^ " " ^ string_of_int (h - y - (if big then 24 else 12)) ^ " Td (" ^ pdf_esc s ^ ") Tj ET\n"
  ^ (if style land 4 <> 0 then line_pdf h "0 0 0" x (y + (if big then 30 else 15)) (x + (String.length s * if big then 16 else 8)) (y + (if big then 30 else 15)) else "")

(* a text box, as the office lays it out: each run of a style on a line
 * at the line's bottom, the lines that fit *)
let text_pdf_box h (b : obj) : string =
  let (t, st) = decode b.data in
  let lay = lay_out (b.w - 8) t st and n = String.length t in
  let fits l = lay.top.(l) + lay.tall.(l) <= b.h - 4 in
  let rec runs i acc =
    if i >= n then acc
    else if t.[i] = '\n' || not (fits lay.ln.(i)) then runs (i + 1) acc
    else begin
      let j = ref (i + 1) and l = lay.ln.(i) and k = Char.code st.[i] in
      while !j < n && t.[!j] <> '\n' && lay.ln.(!j) = l && st.[!j] = st.[i] do incr j done;
      let y = b.y + 2 + lay.top.(l) + lay.tall.(l) - (if k land 8 <> 0 then 32 else 16) in
      runs !j (text_pdf h k (b.x + 4 + lay.px.(i)) y (String.sub t i (!j - i)) :: acc)
    end in
  glue (List.rev (runs 0 []))

(* a sheet: its values in cells of 64 by 16, a number at the right, the
 * grid's lines grey *)
let sheet_pdf h (b : obj) : string =
  let value = values b.data and (nc, nr) = sheet_size b.data in
  glue (List.concat (List.init nr (fun r -> List.init nc (fun c ->
    let (s, num, _) = shown value b.data c r in
    let x = b.x + (64 * c) and y = b.y + (16 * r) in
    frame_pdf h ".8 .8 .8" x y 64 16 ^ (if s = "" then "" else text_pdf h 0 (if num then x + 60 - (8 * String.length s) else x + 4) y s)))))

(* a drawing: its boxes stroked, its arrows a line across then up or
 * down and a head filled, its texts *)
let drawing_pdf h (b : obj) : string =
  glue (List.map (fun (kind, nums, label) ->
    match kind, nums with
    | "box", [ x; y; w; hh ] ->
        frame_pdf h "0 0 0" (b.x + x) (b.y + y) w hh ^ (if label = "" then "" else text_pdf h 0 (b.x + x + (w / 2) - (4 * String.length label)) (b.y + y + (hh / 2) - 8) label)
    | "arrow", [ x0; y0; x1; y1 ] ->
        let dx, dy = if y1 > y0 then 0, -1 else if y1 < y0 then 0, 1 else if x1 >= x0 then -1, 0 else 1, 0 in
        let p x y = string_of_int (b.x + x) ^ " " ^ string_of_int (h - b.y - y) in
        line_pdf h "0 0 0" (b.x + x0) (b.y + y0) (b.x + x1) (b.y + y0) ^ line_pdf h "0 0 0" (b.x + x1) (b.y + y0) (b.x + x1) (b.y + y1)
        ^ "0 0 0 rg " ^ p x1 y1 ^ " m " ^ p (x1 + (6 * dx) - (4 * dy)) (y1 + (6 * dy) - (4 * dx)) ^ " l " ^ p (x1 + (6 * dx) + (4 * dy)) (y1 + (6 * dy) + (4 * dx)) ^ " l f\n"
    | "text", [ x; y ] -> text_pdf h 0 (b.x + x) (b.y + y) label
    | _ -> "") (figures b.data))

(* a paint: a rectangle a run of a colour on a row, 4 by 4 a pixel *)
let paint_pdf h (b : obj) : string =
  let lines = String.split_on_char '\n' b.data in
  glue (List.mapi (fun r line ->
    let n = String.length line in
    let rec go i acc =
      if i >= n then acc
      else begin
        let j = ref (i + 1) in
        while !j < n && line.[!j] = line.[i] do incr j done;
        go !j (match List.assoc_opt line.[i] pdf_colours with
               | Some c -> fill h c (b.x + 2 + (4 * i)) (b.y + 2 + (4 * r)) (4 * (!j - i)) 4 :: acc
               | None -> acc)
      end in
    glue (List.rev (go 0 []))) lines)

(* a chart: its bars as the office draws them *)
let chart_pdf h (page : obj list) (b : obj) : string =
  match chart_bars page b with
  | [], why -> text_pdf h 0 (b.x + 4) (b.y + 2) why
  | bars, _ ->
      let n = List.length bars and top = List.fold_left (fun m (_, v) -> max m v) 1 bars in
      let bw = max 6 ((b.w - 16) / n) and base = b.y + b.h - 20 and room = b.h - 42 in
      glue (List.mapi (fun k (label, v) ->
        let x = b.x + 8 + (k * bw) and tall = max 0 (v * room / top) in
        fill h (List.nth pdf_bars (k mod 6)) (x + 2) (base - tall) (bw - 4) tall
        ^ text_pdf h 0 (x + 2) (base - tall - 16) (string_of_int v) ^ text_pdf h 0 (x + 2) (base + 2) label) bars)
      ^ line_pdf h ".6 .6 .6" (b.x + 4) base (b.x + b.w - 4) base

(* a number of 10 digits, as the cross-reference table has them *)
let ten (k : int) = let s = string_of_int k in String.make (10 - String.length s) '0' ^ s

let to_pdf (doc : string) : string =
  let parts = in_order (parse 640 480 doc) in
  let pages = pages_of parts in
  let n = List.length pages in
  (* every page the size of the largest one's parts *)
  let width = List.fold_left (fun m (b : obj) -> max m (b.x + b.w)) 1 parts and height = List.fold_left (fun m (b : obj) -> max m (b.y + b.h)) 1 parts in
  let drawn bs = glue (List.map (fun (b : obj) ->
    if b.kind = "sheet" then sheet_pdf height b
    else if b.kind = "drawing" then drawing_pdf height b
    else if b.kind = "paint" then paint_pdf height b
    else if b.kind = "chart" then chart_pdf height parts b
    else text_pdf_box height b) bs) in
  let num k = string_of_int k in
  let font k name = num (3 + k) ^ " 0 obj << /Type /Font /Subtype /Type1 /BaseFont /" ^ name ^ " /Encoding /WinAnsiEncoding >> endobj\n" in
  (* the objects: 1 the catalog, 2 the pages, 3 to 6 the fonts, then a
   * page's and its contents' for each page, 7 and 8 the first's *)
  let page_objects k bs =
    let content = drawn bs in
    [ num (7 + (2 * k)) ^ " 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 " ^ num width ^ " " ^ num height
      ^ "] /Resources << /Font << /F0 3 0 R /F1 4 0 R /F2 5 0 R /F3 6 0 R >> >> /Contents " ^ num (8 + (2 * k)) ^ " 0 R >> endobj\n";
      num (8 + (2 * k)) ^ " 0 obj << /Length " ^ num (String.length content) ^ " >>\nstream\n" ^ content ^ "endstream endobj\n" ] in
  let kids = glue (List.init n (fun k -> (if k = 0 then "" else " ") ^ num (7 + (2 * k)) ^ " 0 R")) in
  let objects = [
    "1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n";
    "2 0 obj << /Type /Pages /Kids [" ^ kids ^ "] /Count " ^ num n ^ " >> endobj\n";
    font 0 "Courier"; font 1 "Courier-Bold"; font 2 "Courier-Oblique"; font 3 "Courier-BoldOblique" ]
    @ List.concat (List.mapi page_objects pages) in
  let head = "%PDF-1.4\n" in
  (* each object's place in the file, for the cross-reference table *)
  let rec places at l = match l with o :: rest -> at :: places (at + String.length o) rest | [] -> [] in
  let body = glue objects and count = List.length objects + 1 in
  head ^ body ^ "xref\n0 " ^ num count ^ "\n0000000000 65535 f \n" ^ glue (List.map (fun at -> ten at ^ " 00000 n \n") (places (String.length head) objects))
  ^ "trailer << /Size " ^ num count ^ " /Root 1 0 R >>\nstartxref\n" ^ num (String.length head + String.length body) ^ "\n%%EOF\n"
