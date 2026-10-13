(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See To_pdf.mli *)

(* Lengths are in thousandths of a point, whole numbers of them: a
 * letter's width in a font is so many thousandths of its size, and
 * the sizes are whole points. (Layout.mli says why whole.) *)
let point = 1000.
let paper_width = 612. *. point
let paper_height = 792. *. point
let size = 10
let leading = 12. *. point

(* an en: half the text's size *)
let en = float_of_int size *. point /. 2.

(* the header's line, the first of the text's and the last a page may
 * have; the page number's *)
let header_y = paper_height -. (54. *. point)
let first_y = paper_height -. (90. *. point)
let last_y = 72. *. point
let number_y = 42. *. point

(* (the room after a tag 3 points: tmac.an's) *)
let look : Layout.look = { en; inch = 72. *. point; width = 0.; tag_room = 3. *. point; justify = true }

let font_name (f : Doc.font) : string =
  match f with Doc.Roman -> "Times-Roman" | Doc.Italic -> "Times-Italic" | Doc.Bold -> "Times-Bold" | Doc.Mono -> "Courier"

let point_size (style : Doc.style) : int = max 1 (size + style.size)

(* what could not be written, the last first *)
let missing : string list ref = ref []

(* A character as it is written in a font: itself if the encoding has
 * it; troff's own choices (a minus, the quotes); for a few that it has
 * not, ASCII's way of saying them. *)
let written (f : Doc.font) (c : string) : string =
  match c with
  | "\xc2\xa0" -> " "
  (* (the three that are not seen: the layout's) *)
  | "\xc2\xad" | "\xe2\x81\xa0" | "\xe2\x80\x8b" -> c
  | "\xe2\x80\x91" -> "-"
  | "\xe2\x88\x92" -> if f = Doc.Mono then "-" else "\xe2\x80\x93"
  | "`" -> if f = Doc.Mono then c else "\xe2\x80\x98"
  | "'" -> if f = Doc.Mono then c else "\xe2\x80\x99"
  | _ ->
      (* (ASCII; not a byte that is no character, which is a "?" too) *)
      if (String.length c = 1 && c.[0] < '\x80') || (String.length c > 1 && Pdf_write.writes (Utf8.code c)) then c
      else
        match c with
        | "\xe2\x86\x92" -> "->" | "\xe2\x86\x90" -> "<-" | "\xe2\x89\xa4" -> "<=" | "\xe2\x89\xa5" -> ">=" | "\xe2\x89\xa0" -> "!="
        | "\xe2\x88\x99" -> "\xe2\x80\xa2"
        | _ -> if not (List.mem c !missing) then missing := c :: !missing; "?"

let shown (f : Doc.font) (s : string) : string = String.concat "" (List.map (written f) (fst (Utf8.chars s)))

(* a character's width in a font, in thousandths of its size: looked
 * up once *)
let widths : (Doc.font * string, int) Hashtbl.t = Hashtbl.create 512

let char_width (f : Doc.font) (c : string) : int =
  match Hashtbl.find_opt widths (f, c) with
  | Some w -> w
  | None ->
      let w = match Option.bind (Glyph_names.name (Utf8.code c)) (Standard_widths.width (font_name f)) with Some w -> w | None -> 500 in
      Hashtbl.add widths (f, c) w; w

let metrics (style : Doc.style) (s : string) : float =
  let total = List.fold_left (fun w c -> w + char_width style.font c) 0 (fst (Utf8.chars (shown style.font s))) in
  float_of_int (total * point_size style)

let measure (text : Doc.inline list) : float =
  let total = List.fold_left (fun w (i : Doc.inline) -> match i with Doc.Text (style, s) -> w +. metrics style (Doc.letters s) | Doc.Break -> w) 0. text in
  total /. en

(* a text at a place, both in thousandths of a point *)
let put (pdf : Pdf_write.t) (c : Pdf_write.content) (style : Doc.style) (x : float) (y : float) (s : string) =
  Pdf_write.text pdf c ~font:(font_name style.font) ~size:(float_of_int (point_size style)) (x /. point, y /. point) s

(* the room a rule across a table takes *)
let rule_room = Float.round (leading /. 3.)

(* how much of a sheet rows take; the rows as lines, what is to stay
 * together no longer said *)
let rec height (rows : Layout.row list) : float =
  List.fold_left (fun h (r : Layout.row) ->
    match r with
    | Layout.Line _ -> h +. leading
    | Layout.Skip n -> let down = Float.round (n *. leading) in h +. down
    | Layout.Together inner -> h +. height inner
    | Layout.Rule _ -> h +. rule_room
    | Layout.Drawing (_, p) -> h +. Float.round (p.high *. 72. *. point) +. leading
    | Layout.Foot _ -> h) 0. rows

let rec flat (rows : Layout.row list) : Layout.row list =
  List.concat_map (fun (r : Layout.row) -> match r with Layout.Together inner | Layout.Foot inner -> flat inner | _ -> [ r ]) rows

let file (d : Doc.t) : string * string list * int =
  missing := [];
  (* the lines that go past the paper's right edge *)
  let over = ref 0 in
  let pdf = Pdf_write.create ~compress:true in
  let (head_left, head_middle, head_right) = d.header in
  let width_of (s : string) = metrics Doc.plain s in
  (* the lines in the middle of the paper: its left edge to their start *)
  let width = Float.round (d.width *. en) in
  let left = Float.round ((paper_width -. width) /. 2.) in
  let page = ref (Pdf_write.content ()) and number = ref 1 and y = ref first_y and used = ref false in
  (* the sheet's footnotes, the last first, and those that found no
   * room on it; the lowest line the text may have, above them *)
  let feet = ref [] and waiting = ref [] and limit = ref last_y in
  let line (at : float) (pieces : Layout.piece list) =
    List.iter (fun (p : Layout.piece) ->
      let s = shown p.style.font p.text in
      (* (an exponent, an index: a third of the size up or down) *)
      let up = float_of_int (p.style.shift * size * 1000 / 3) in
      if String.trim s <> "" then put pdf !page p.style (left +. p.x) (at +. up) s) pieces;
    match List.rev pieces with
    | (last : Layout.piece) :: _ when left +. last.x +. metrics last.style last.text > paper_width -> incr over
    | _ -> () in
  (* a rule above where the next line will stand, at [at] *)
  let across (at : float) (x0 : float) (x1 : float) =
    let y = (at +. leading -. rule_room) /. point in
    Pdf_write.pen !page 0.5;
    Pdf_write.polyline !page [ ((left +. x0) /. point, y); ((left +. x1) /. point, y) ];
    Pdf_write.stroke !page in
  (* a footnote's room: its lines, and one for the rule over the first *)
  let room (rows : Layout.row list) : float = height rows +. leading in
  let finish () =
    let c = !page in
    (* the footnotes, the last line of the last on the sheet's last line *)
    if !feet <> [] then begin
      (* a short rule under the text, a line's room for it and between
       * two footnotes *)
      let rule = (!limit -. Float.round (leading /. 4.)) /. point in
      Pdf_write.pen c 0.5;
      Pdf_write.polyline c [ (left /. point, rule); ((left +. (72. *. point)) /. point, rule) ];
      Pdf_write.stroke c;
      let at = ref !limit in
      List.iter (fun rows ->
        at := !at -. leading;
        List.iter (fun (r : Layout.row) ->
          match r with
          | Layout.Line pieces -> line !at pieces; at := !at -. leading
          | Layout.Skip n -> let down = Float.round (n *. leading) in at := !at -. down
          | Layout.Rule (x0, x1) -> across !at x0 x1; at := !at -. rule_room
          | _ -> ()) (flat rows)) (List.rev !feet)
    end;
    if head_left <> "" || head_right <> "" then begin
      put pdf c Doc.plain left header_y head_left;
      put pdf c Doc.plain (left +. Float.floor ((width -. width_of head_middle) /. 2.)) header_y head_middle;
      put pdf c Doc.plain (left +. width -. width_of head_right) header_y head_right
    end;
    let n = string_of_int !number in
    put pdf c Doc.plain (left +. Float.floor ((width -. width_of n) /. 2.)) number_y n;
    Pdf_write.page pdf ~width:(paper_width /. point) ~height:(paper_height /. point) c;
    page := Pdf_write.content (); incr number; y := first_y; used := false;
    feet := !waiting; waiting := [];
    limit := List.fold_left (fun l rows -> l +. room rows) last_y !feet in
  let rec write (r : Layout.row) =
    match r with
    (* (no space at a page's top) *)
    | Layout.Skip n -> if !used then begin let down = Float.round (n *. leading) in y := !y -. down end
    | Layout.Line pieces ->
        if !y < !limit then finish ();
        line !y pieces;
        used := true; y := !y -. leading
    | Layout.Rule (x0, x1) -> across !y x0 x1; y := !y -. rule_room
    | Layout.Drawing (x, p) ->
        (* its top where the next line's letters would reach, half a
         * line of room under it *)
        let high = Float.round (p.high *. 72. *. point) in
        if !used && !y -. high < !limit && high <= first_y -. !limit then finish ();
        let top = !y +. Float.round (leading *. 0.7) in
        let at (px : float) (py : float) : float * float = (left +. x +. Float.round (px *. 72. *. point), top -. high +. Float.round (py *. 72. *. point)) in
        Pdf_write.pen !page 0.5;
        List.iter (fun (m : Doc.mark) ->
          match m with
          | Doc.Stroke points ->
              Pdf_write.polyline !page (List.map (fun (px, py) -> let ax, ay = at px py in (ax /. point, ay /. point)) points);
              Pdf_write.stroke !page
          | Doc.Label (px, py, side, text) ->
              let ax, ay = at px py in
              let wide = measure text *. en in
              let from = if side < 0 then ax else if side > 0 then ax -. wide else ax -. Float.floor (wide /. 2.) in
              (* (the letters' middle on the place, not their foot) *)
              let pieces, _ = Layout.one_line metrics (from -. left) text in
              line (ay -. Float.round (float_of_int size *. point *. 0.3)) pieces) p.marks;
        used := true; y := !y -. high -. Float.round (leading /. 2.)
    | Layout.Together rows ->
        (* (on the next sheet if it does not fit on this one, unless it
         * would not fit on an empty one either) *)
        if !used && !y -. height rows +. leading < !limit && height rows <= first_y -. !limit then finish ();
        List.iter write rows
    | Layout.Foot rows ->
        (* (on this sheet if there is room under the line its mark is
         * on; else on the next) *)
        if !y -. room rows >= !limit then begin feet := rows :: !feet; limit := !limit +. room rows end
        else waiting := rows :: !waiting in
  List.iter write (Layout.rows look metrics d);
  finish ();
  while !feet <> [] do finish () done;
  (Pdf_write.to_string pdf, List.rev !missing, !over)
