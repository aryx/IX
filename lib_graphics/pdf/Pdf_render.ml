(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: mini-chrome's libs/pdf/Pdf_render.ml; render's options and stroke_glyph are said, where they were optional (full, and hershey, which the interface gives now) (docs/plans/plan_pdf.md) *)

(* See Pdf_render.mli *)

open Pdf_object

type letters = Outlines | Strokes

(* what of a page's drawing is done in full, each to be turned off: the
 * simple rendering, and what each refinement adds *)
type options = {
  letters : letters; (* the file's fonts, or our stroke font at their widths *)
  gradients : bool; (* else a gradient's middle colour, flat *)
  clips : bool; (* else what is drawn is not cut to the clipping paths *)
  pictures : bool; (* else a grey box where a picture is *)
  transparency : bool; (* else everything is opaque *)
}

let full : options = { letters = Outlines; gradients = true; clips = true; pictures = true; transparency = true }
let plain : options = { letters = Strokes; gradients = false; clips = false; pictures = false; transparency = false }

(* "strokes,-gradients": words that turn a part on, or off with a minus; "plain" and "full" all of them *)
let options_of_string (s : string) : options =
  List.fold_left
    (fun o word ->
      let off = String.length word > 0 && word.[0] = '-' in
      match if off then String.sub word 1 (String.length word - 1) else word with
      | "plain" -> plain
      | "full" -> full
      | "strokes" -> { o with letters = (if off then Outlines else Strokes) }
      | "outlines" -> { o with letters = (if off then Strokes else Outlines) }
      | "gradients" -> { o with gradients = not off }
      | "clips" -> { o with clips = not off }
      | "pictures" -> { o with pictures = not off }
      | "transparency" -> { o with transparency = not off }
      | _ -> o)
    full (String.split_on_char ',' s)

type state = {
  ctm : Affine.t;
  clip : Pdf_canvas.clip;
  fill : Pdf_color.rgb;
  stroke : Pdf_color.rgb;
  fill_alpha : float;
  stroke_alpha : float;
  fill_space : Pdf_color.space;
  stroke_space : Pdf_color.space;
  line_width : float;
  font : Pdf_font.t option;
  size : float;
  char_space : float;
  word_space : float;
  stretch : float;
  leading : float;
  rise : float;
  mode : int; (* 0 filled, 1 stroked, 2 both, 3 not shown *)
  fill_shading : (Pdf_object.t * Affine.t) option; (* filled with a gradient, in its own space *)
}

type cache = { fonts : (int, Pdf_font.t) Hashtbl.t }

let cache () : cache = { fonts = Hashtbl.create 16 }

type context = {
  pdf : Pdf.t;
  cache : cache;
  canvas : Pdf_canvas.t;
  options : options;
  base : Affine.t; (* the page's points to pixels: what a pattern is placed by *)
  stroke_glyph : int -> (float * float) list list * float;
  (* each glyph shown: where (the page's pixels), how big, what it reads as *)
  mutable shown : (float * float * float * float * int list) list;
}

(* our stroke font's letter: the pen's paths in an em of 1 from the
 * baseline up, and how far the pen moves after it (ASCII: Hershey's) *)
let hershey (code : int) : (float * float) list list * float =
  let g = Hershey.glyph (if code >= 32 && code < 127 then Char.chr code else '?') and em = Hershey.units_per_em in
  (List.map (List.map (fun (x, y) -> (float_of_int (x - g.left) /. em, float_of_int (9 - y) /. em))) g.strokes, float_of_int (g.right - g.left) /. em)

let matrix (l : float list) : Affine.t = match l with [ a; b; c; d; tx; ty ] -> { a; b; c; d; tx; ty } | _ -> Affine.identity

let rec run (cx : context) (resources : Pdf_object.t) (content : string) (st : state) ~(depth : int) : unit =
  let pdf = cx.pdf in
  let resource (kind : string) (name : string) : Pdf_object.t = Pdf.get pdf (Pdf.dict pdf (Pdf.get pdf (Pdf.dict pdf resources) kind)) name in
  let st = ref st and saved = ref [] and operands = ref [] in
  (* the path being built, in the page's pixels: its finished parts, and the one the pen is in *)
  let done_ = ref [] and current = ref [] and start = ref (0., 0.) and at = ref (0., 0.) and clip_wanted = ref None in
  let tm = ref Affine.identity and line_tm = ref Affine.identity and colorless = ref false in
  let device p = Affine.apply !st.ctm p in
  let finish () = if !current <> [] then (done_ := List.rev !current :: !done_; current := []) in
  let move p = finish (); start := p; at := p; current := [ device p ] in
  let line p = if !current = [] then current := [ device !at ]; at := p; current := device p :: !current in
  let curve c1 c2 p =
    if !current = [] then current := [ device !at ];
    (match Curve.flatten ~tolerance:0.1 (device !at) (device c1) (device c2) (device p) with _ :: points -> current := List.rev_append points !current | [] -> ());
    at := p
  in
  let close () = if !current <> [] then (current := device !start :: !current; finish (); at := !start) in
  let scale () = Float.sqrt (Float.abs ((!st.ctm.a *. !st.ctm.d) -. (!st.ctm.b *. !st.ctm.c))) in
  let paint ~(fill : bool option) ~(stroke : bool) =
    finish ();
    let polygons = List.rev !done_ in
    (match (fill, !st.fill_shading) with
     | Some even_odd, Some (sh, m) ->
         Pdf_shading.paint pdf (cx.canvas, Pdf_canvas.clip_shape cx.canvas !st.clip ~even_odd polygons) ~resources ~alpha:!st.fill_alpha ~flat:(not cx.options.gradients) sh m
     | Some even_odd, None -> Pdf_canvas.fill cx.canvas !st.clip ~even_odd polygons !st.fill !st.fill_alpha
     | None, _ -> ());
    if stroke then Pdf_canvas.fill cx.canvas !st.clip ~even_odd:false (Stroke.contours polygons ~width:(Float.max 1. (!st.line_width *. scale ()))) !st.stroke !st.stroke_alpha;
    (match if cx.options.clips then !clip_wanted else None with
     | Some even_odd ->
         let clip =
           match polygons with
           (* a rectangle along the axes: a box *)
           | [ ((x0, y0) :: (x1, y1) :: (x2, y2) :: (x3, y3) :: _ as r) ] when List.length r <= 5 && ((x0 = x1 && y1 = y2 && x2 = x3 && y3 = y0) || (y0 = y1 && x1 = x2 && y2 = y3 && x3 = x0)) ->
               Pdf_canvas.clip_box !st.clip (Float.min x0 x2) (Float.min y0 y2) (Float.max x0 x2) (Float.max y0 y2)
           | _ -> Pdf_canvas.clip_shape cx.canvas !st.clip ~even_odd polygons
         in
         st := { !st with clip }
     | None -> ());
    clip_wanted := None;
    done_ := []
  in
  let font_of (v : Pdf_object.t) : Pdf_font.t option =
    let load () = try Some (Pdf_font.load pdf v) with _ -> None in
    match v with
    | Ref n -> ( match Hashtbl.find_opt cx.cache.fonts n with Some f -> Some f | None -> let f = load () in Option.iter (Hashtbl.replace cx.cache.fonts n) f; f)
    | Null -> None
    | _ -> load ()
  in
  (* a string shown: each code's glyph where the text matrix has the pen, the pen moved by its width *)
  let show (s : string) =
    match !st.font with
    | None -> ()
    | Some font ->
        let n = String.length s in
        let i = ref 0 in
        while !i < n do
          let code = if font.wide && !i + 1 < n then (Char.code s.[!i] lsl 8) lor Char.code s.[!i + 1] else Char.code s.[!i] in
          i := !i + if font.wide then 2 else 1;
          let trm = Affine.compose !st.ctm (Affine.compose !tm { a = !st.size *. !st.stretch; b = 0.; c = 0.; d = !st.size; tx = 0.; ty = !st.rise }) in
          let chars = font.unicode code in
          let known = font.width code in
          let strokes () =
            (* our own letters, each as wide as the page wants its glyph *)
            (* a ligature is its letters *)
            let apart u = match u with 0xfb00 -> [ 102; 102 ] | 0xfb01 -> [ 102; 105 ] | 0xfb02 -> [ 102; 108 ] | 0xfb03 -> [ 102; 102; 105 ] | 0xfb04 -> [ 102; 102; 108 ] | u -> [ u ] in
            let glyphs = List.map cx.stroke_glyph (if chars = [] then [ code ] else List.concat_map apart chars) in
            let own = List.fold_left (fun w (_, a) -> w +. a) 0. glyphs in
            let fit = if known > 0. && own > 0. then known /. own else 1. in
            let pen = Float.max 1. (0.07 *. Float.sqrt (Float.abs ((trm.a *. trm.d) -. (trm.b *. trm.c)))) and x = ref 0. in
            List.iter
              (fun (paths, advance) ->
                let lines = List.filter (fun l -> List.length l > 1) (List.map (List.map (fun (px, py) -> Affine.apply trm ((!x +. px) *. fit, py))) paths) in
                if lines <> [] && !st.mode <> 3 then Pdf_canvas.fill cx.canvas !st.clip ~even_odd:false (Stroke.contours lines ~width:pen) !st.fill !st.fill_alpha;
                x := !x +. advance)
              glyphs;
            if known > 0. then known else own
          in
          let width =
            match (cx.options.letters, font.glyph code) with
            | _, Program p ->
                let m = Affine.compose trm (matrix font.matrix) in
                (try run cx (if font.resources = Null then resources else font.resources) p { !st with ctm = m } ~depth:(depth + 1) with _ -> ());
                known
            | Outlines, Shape o ->
                if o <> [] && !st.mode <> 3 then (
                  let polygons = Outline.polygons ~tolerance:0.2 (Affine.apply trm) o in
                  if !st.mode <> 1 then Pdf_canvas.fill cx.canvas !st.clip ~even_odd:false polygons !st.fill !st.fill_alpha;
                  if !st.mode = 1 || !st.mode = 2 then
                    Pdf_canvas.fill cx.canvas !st.clip ~even_odd:false (Stroke.contours (List.map (fun p -> p @ [ List.hd p ]) polygons) ~width:(Float.max 1. (!st.line_width *. scale ()))) !st.stroke !st.stroke_alpha);
                if known < 0. then 0.5 else known
            | Strokes, Shape _ | _, Missing -> strokes ()
          in
          let x, y = Affine.apply trm (0., 0.) and after, _ = Affine.apply trm (Float.max 0. width, 0.) in
          cx.shown <- (x, after, y, Float.sqrt (Float.abs ((trm.a *. trm.d) -. (trm.b *. trm.c))), chars) :: cx.shown;
          let tx = ((width *. !st.size) +. !st.char_space +. if code = 32 && not font.wide then !st.word_space else 0.) *. !st.stretch in
          tm := Affine.compose !tm (Affine.translate tx 0.)
        done
  in
  let picture d raw = Pdf_image.paint pdf (cx.canvas, !st.clip) !st.ctm ~resources (!st.fill, !st.fill_alpha, cx.options.pictures) d raw in
  let next_line tx ty = line_tm := Affine.compose !line_tm (Affine.translate tx ty); tm := !line_tm in
  let set_color (fill : bool) (v : Pdf_object.t list) =
    if not !colorless then (
      let numbers = List.filter_map (fun v -> match v with Int _ | Real _ -> Some (to_float v) | _ -> None) v in
      let sp = if fill then !st.fill_space else !st.stroke_space in
      (* a pattern by its name: a gradient is kept to fill with; a tiling is grey *)
      (if fill then
         let named = List.find_map (fun v -> match v with Name n -> Some n | _ -> None) v in
         let found =
           Option.bind named (fun n ->
               let pattern = Pdf.dict pdf (resource "Pattern" n) in
               match Pdf.get pdf pattern "Shading" with
               | Null -> None
               | sh -> Some (sh, match Pdf.get pdf pattern "Matrix" with Array l -> Affine.compose cx.base (matrix (List.map (fun v -> to_float (Pdf.resolve pdf v)) l)) | _ -> cx.base))
         in
         st := { !st with fill_shading = found });
      let c = if List.exists (fun v -> match v with Name _ -> true | _ -> false) v then (128., 128., 128.) else Pdf_color.color (match (sp, List.length numbers) with (Gray | Pattern), 3 -> Pdf_color.Rgb | (Gray | Pattern), 4 -> Cmyk | _ -> sp) numbers in
      st := if fill then { !st with fill = c } else { !st with stroke = c })
  in
  let device_color (fill : bool) (sp : Pdf_color.space) (v : Pdf_object.t list) =
    if not !colorless then (st := if fill then { !st with fill_space = sp } else { !st with stroke_space = sp });
    set_color fill v
  in
  let n = String.length content and i = ref 0 in
  while Pdf_object.skip content !i < n do
    let v, j = parse content !i in
    i := max j (!i + 1);
    match keyword v with
    | None -> operands := v :: !operands
    | Some op ->
        let args = List.rev !operands in
        operands := [];
        let f k = match List.nth_opt args k with Some v -> to_float v | None -> 0. in
        (match op with
         | "q" -> saved := !st :: !saved
         | "Q" -> ( match !saved with s :: rest -> st := s; saved := rest | [] -> ())
         | "cm" -> st := { !st with ctm = Affine.compose !st.ctm (matrix (List.map to_float args)) }
         | "w" -> st := { !st with line_width = f 0 }
         | "m" -> move (f 0, f 1)
         | "l" -> line (f 0, f 1)
         | "c" -> curve (f 0, f 1) (f 2, f 3) (f 4, f 5)
         | "v" -> curve !at (f 0, f 1) (f 2, f 3)
         | "y" -> curve (f 0, f 1) (f 2, f 3) (f 2, f 3)
         | "h" -> close ()
         | "re" ->
             let x = f 0 and y = f 1 and w = f 2 and h = f 3 in
             move (x, y); line (x +. w, y); line (x +. w, y +. h); line (x, y +. h); close ()
         | "S" -> paint ~fill:None ~stroke:true
         | "s" -> close (); paint ~fill:None ~stroke:true
         | "f" | "F" -> paint ~fill:(Some false) ~stroke:false
         | "f*" -> paint ~fill:(Some true) ~stroke:false
         | "B" -> paint ~fill:(Some false) ~stroke:true
         | "B*" -> paint ~fill:(Some true) ~stroke:true
         | "b" -> close (); paint ~fill:(Some false) ~stroke:true
         | "b*" -> close (); paint ~fill:(Some true) ~stroke:true
         | "n" -> paint ~fill:None ~stroke:false
         | "W" -> clip_wanted := Some false
         | "W*" -> clip_wanted := Some true
         | "g" -> device_color true Gray args
         | "G" -> device_color false Gray args
         | "rg" -> device_color true Rgb args
         | "RG" -> device_color false Rgb args
         | "k" -> device_color true Cmyk args
         | "K" -> device_color false Cmyk args
         | "cs" -> ( match args with v :: _ -> st := { !st with fill_space = Pdf_color.space pdf resources v } | [] -> ())
         | "CS" -> ( match args with v :: _ -> st := { !st with stroke_space = Pdf_color.space pdf resources v } | [] -> ())
         | "sc" | "scn" -> set_color true args
         | "SC" | "SCN" -> set_color false args
         | "gs" -> (
             match args with
             | Name name :: _ ->
                 let g = Pdf.dict pdf (resource "ExtGState" name) in
                 let number key default = match Pdf.get pdf g key with Null -> default | v -> to_float v in
                 let alpha key now = if cx.options.transparency then number key now else 1. in
                 st := { !st with fill_alpha = alpha "ca" !st.fill_alpha; stroke_alpha = alpha "CA" !st.stroke_alpha; line_width = number "LW" !st.line_width }
             | _ -> ())
         | "BT" -> tm := Affine.identity; line_tm := Affine.identity
         | "Tf" -> ( match args with Name name :: _ -> st := { !st with font = font_of (match Pdf.dict pdf (Pdf.get pdf (Pdf.dict pdf resources) "Font") |> List.assoc_opt name with Some v -> v | None -> Null); size = f 1 } | _ -> ())
         | "Td" -> next_line (f 0) (f 1)
         | "TD" -> st := { !st with leading = -.f 1 }; next_line (f 0) (f 1)
         | "Tm" -> line_tm := matrix (List.map to_float args); tm := !line_tm
         | "T*" -> next_line 0. (-. !st.leading)
         | "Tc" -> st := { !st with char_space = f 0 }
         | "Tw" -> st := { !st with word_space = f 0 }
         | "Tz" -> st := { !st with stretch = f 0 /. 100. }
         | "TL" -> st := { !st with leading = f 0 }
         | "Ts" -> st := { !st with rise = f 0 }
         | "Tr" -> st := { !st with mode = int_of_float (f 0) land 3 }
         | "Tj" -> ( match args with String s :: _ -> show s | _ -> ())
         | "'" -> next_line 0. (-. !st.leading); ( match args with String s :: _ -> show s | _ -> ())
         | "\"" -> st := { !st with word_space = f 0; char_space = f 1 }; next_line 0. (-. !st.leading); ( match args with [ _; _; String s ] -> show s | _ -> ())
         | "TJ" -> (
             match args with
             | Array parts :: _ ->
                 List.iter (fun p -> match p with String s -> show s | Int _ | Real _ -> tm := Affine.compose !tm (Affine.translate (-.to_float p /. 1000. *. !st.size *. !st.stretch) 0.) | _ -> ()) parts
             | _ -> ())
         (* a gradient over all that the clip allows: nothing, when clips are not done *)
         | "sh" when cx.options.clips -> (
             match args with
             | Name name :: _ -> ( try Pdf_shading.paint pdf (cx.canvas, !st.clip) ~resources ~alpha:!st.fill_alpha ~flat:(not cx.options.gradients) (resource "Shading" name) !st.ctm with _ -> ())
             | _ -> ())
         | "d1" -> colorless := true
         | "Do" when depth < 12 -> (
             match args with
             | Name name :: _ -> (
                 match resource "XObject" name with
                 | Stream (d, raw) as x -> (
                     match Pdf.get pdf d "Subtype" with
                     | Name "Image" -> picture d raw
                     | Name "Form" ->
                         let inner = { !st with ctm = (match Pdf.get pdf d "Matrix" with Array m -> Affine.compose !st.ctm (matrix (List.map (fun v -> to_float (Pdf.resolve pdf v)) m)) | _ -> !st.ctm) } in
                         let inner =
                           match Pdf.get pdf d "BBox" with
                           | Array [ a; b; c; e ] ->
                               let v x = to_float (Pdf.resolve pdf x) in
                               { inner with clip = Pdf_canvas.clip_shape cx.canvas inner.clip ~even_odd:false [ List.map (Affine.apply inner.ctm) [ (v a, v b); (v c, v b); (v c, v e); (v a, v e) ] ] }
                           | _ -> inner
                         in
                         run cx (match Pdf.get pdf d "Resources" with Null -> resources | r -> r) (Pdf.data pdf x) inner ~depth:(depth + 1)
                     | _ -> ())
                 | _ -> ())
             | _ -> ())
         | "BI" ->
             (* a picture in the content itself: its dictionary to ID, its bytes to EI *)
             let rec entries acc =
               let v, j = parse content !i in
               i := max j (!i + 1);
               if keyword v = Some "ID" || !i >= n then List.rev acc
               else match v with Name key -> let value, j = parse content !i in i := j; entries ((key, value) :: acc) | _ -> entries acc
             in
             let d = entries [] in
             let from = !i + 1 in
             let is_end k = k + 2 <= n && content.[k] = 'E' && content.[k + 1] = 'I' && k > 0 && is_space content.[k - 1] && (k + 2 >= n || not (is_regular content.[k + 2])) in
             let rec find k = if k >= n then n else if is_end k then k else find (k + 1) in
             let stop = find from in
             (try picture d (String.sub content (min from n) (max 0 (stop - 1 - from))) with _ -> ());
             i := min n (stop + 2)
         | _ -> ())
  done

(* a page's size once turned, in points *)
let size (p : Pdf.page) : float * float =
  let x0, y0, x1, y1 = p.box in
  if p.rotate = 90 || p.rotate = 270 then (y1 -. y0, x1 -. x0) else (x1 -. x0, y1 -. y0)

let draw ~(options : options) ~(stroke_glyph : int -> (float * float) list list * float) (pdf : Pdf.t) (cache : cache) (p : Pdf.page) ~(scale : float) : context =
  let w, h = size p and x0, y0, x1, y1 = p.box and s = scale in
  let canvas = Pdf_canvas.create ~width:(max 1 (int_of_float (Float.ceil (w *. s)))) ~height:(max 1 (int_of_float (Float.ceil (h *. s)))) in
  (* the page's points, y up, to pixels, y down; turned as it says *)
  let ctm : Affine.t =
    match p.rotate with
    | 90 -> { a = 0.; b = s; c = s; d = 0.; tx = -.y0 *. s; ty = -.x0 *. s }
    | 180 -> { a = -.s; b = 0.; c = 0.; d = s; tx = x1 *. s; ty = -.y0 *. s }
    | 270 -> { a = 0.; b = -.s; c = -.s; d = 0.; tx = y1 *. s; ty = x1 *. s }
    | _ -> { a = s; b = 0.; c = 0.; d = -.s; tx = -.x0 *. s; ty = y1 *. s }
  in
  let cx = { pdf; cache; canvas; options; base = ctm; stroke_glyph; shown = [] } in
  let black = (0., 0., 0.) in
  (try
     run cx p.resources (Pdf.content pdf p)
       { ctm; clip = Pdf_canvas.everywhere canvas; fill = black; stroke = black; fill_alpha = 1.; stroke_alpha = 1.; fill_space = Gray; stroke_space = Gray; line_width = 1.; font = None; size = 0.;
         char_space = 0.; word_space = 0.; stretch = 1.; leading = 0.; rise = 0.; mode = 0; fill_shading = None }
       ~depth:0
   with _ -> ());
  cx

let render ~(options : options) ~(stroke_glyph : int -> (float * float) list list * float) (pdf : Pdf.t) (cache : cache) (p : Pdf.page) ~(scale : float) : Rgba_image.t =
  Pdf_canvas.to_image (draw ~options ~stroke_glyph pdf cache p ~scale).canvas

(* a page's words, as they are shown: a new line where the pen goes
 * down, a space where it jumps *)
let text (pdf : Pdf.t) (cache : cache) (p : Pdf.page) : string =
  let cx = draw ~options:plain ~stroke_glyph:(fun _ -> ([], 0.5)) pdf cache p ~scale:1. in
  let b = Buffer.create 256 and last = ref None in
  List.iter
    (fun (x, after, y, size, chars) ->
      (match !last with
       | Some (lx, ly, lsize) ->
           if Float.abs (y -. ly) > 0.5 *. Float.max size lsize then Buffer.add_char b '\n'
           else if x -. lx > 0.15 *. size || x < lx -. size then Buffer.add_char b ' '
       | None -> ());
      List.iter (fun u -> if u = 32 || u = 0xa0 then (if Buffer.length b > 0 && Buffer.nth b (Buffer.length b - 1) <> ' ' && Buffer.nth b (Buffer.length b - 1) <> '\n' then Buffer.add_char b ' ') else Buffer.add_utf_8_uchar b (if Uchar.is_valid u then Uchar.of_int u else Uchar.rep)) chars;
      last := Some (after, y, size))
    (List.rev cx.shown);
  Buffer.contents b
