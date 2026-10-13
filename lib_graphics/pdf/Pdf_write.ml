(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)

(* See Pdf_write.mli *)

(*****************************************************************************)
(* Numbers *)
(*****************************************************************************)

(* a number with at most [digits] decimals, its last zeros not written:
 * 12, 0.5, -3.25. By integers: OCaml's and mini-ml's Printf need not
 * round a float the same way *)
let fixed (digits : int) (x : float) : string =
  let unit = if digits = 2 then 100 else 100000 in
  let n = int_of_float (Float.round (x *. float unit)) in
  let sign = if n < 0 then "-" else "" and n = abs n in
  let frac = ref (string_of_int (unit + (n mod unit))) in
  (* "100025" for .00025: the first character is the unit's *)
  while String.length !frac > 1 && !frac.[String.length !frac - 1] = '0' do
    frac := String.sub !frac 0 (String.length !frac - 1)
  done;
  let frac = String.sub !frac 1 (String.length !frac - 1) in
  sign ^ string_of_int (n / unit) ^ (if frac = "" then "" else "." ^ frac)

(* a length or a place, in points: hundredths *)
let num (x : float) : string = fixed 2 x

(* a transform's or a colour's: finer *)
let fine (x : float) : string = fixed 5 x

(*****************************************************************************)
(* The file *)
(*****************************************************************************)

(* the three objects every file has, written last *)
let catalog = 1
let tree = 2
let resources = 3

type t = {
  compress : bool;
  (* each object's number and text, the last added first *)
  mutable objects : (int * string) list;
  mutable last : int;
  (* the pages' objects, the last first *)
  mutable pages : int list;
  (* what the contents name: opacities in hundredths, pictures and
   * forms by their object *)
  mutable opacities : int list;
  mutable named : int list;
  (* the fonts named and each one's object, the last first: the first
   * is /F1 *)
  mutable fonts : (string * int) list;
}

let create ~(compress : bool) : t = { compress; objects = []; last = resources; pages = []; opacities = []; named = []; fonts = [] }

let add (t : t) (text : string) : int =
  t.last <- t.last + 1;
  t.objects <- (t.last, text) :: t.objects;
  t.last

let reference (n : int) : string = string_of_int n ^ " 0 R"

(* an object that is bytes after a dictionary's entries *)
let stream (t : t) (entries : string) (bytes : string) : int =
  let filter, bytes = if t.compress then (" /Filter /FlateDecode", Zlib.deflate bytes) else ("", bytes) in
  add t (Printf.sprintf "<< %s/Length %d%s >>\nstream\n%s\nendstream" entries (String.length bytes) filter bytes)

let to_string (t : t) : string =
  let kids = String.concat " " (List.rev_map reference t.pages) in
  let opacities =
    String.concat " "
      (List.rev_map (fun (a : int) -> let v = fixed 2 (float a /. 100.) in Printf.sprintf "/A%d << /ca %s /CA %s >>" a v v) t.opacities)
  in
  let named = String.concat " " (List.rev_map (fun (n : int) -> Printf.sprintf "/X%d %s" n (reference n)) t.named) in
  let fonts = String.concat " " (List.mapi (fun (k : int) ((_, n) : string * int) -> Printf.sprintf "/F%d %s" (k + 1) (reference n)) (List.rev t.fonts)) in
  let objects =
    (catalog, Printf.sprintf "<< /Type /Catalog /Pages %s >>" (reference tree))
    :: (tree, Printf.sprintf "<< /Type /Pages /Kids [%s] /Count %d >>" kids (List.length t.pages))
    :: (resources, Printf.sprintf "<< /ExtGState << %s >> /XObject << %s >>%s >>" opacities named (if fonts = "" then "" else " /Font << " ^ fonts ^ " >>"))
    :: List.rev t.objects
  in
  let b = Buffer.create 65536 in
  (* the second line: four bytes over 127, by which a program takes the
   * file for bytes and not text *)
  Buffer.add_string b "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n";
  let starts = Array.make (t.last + 1) 0 in
  List.iter
    (fun ((n, text) : int * string) ->
      starts.(n) <- Buffer.length b;
      Buffer.add_string b (Printf.sprintf "%d 0 obj\n%s\nendobj\n" n text))
    objects;
  let table = Buffer.length b in
  (* the table: a line of 20 bytes an object, its start in ten digits;
   * the first line is object 0's, which is no object *)
  Buffer.add_string b (Printf.sprintf "xref\n0 %d\n0000000000 65535 f \n" (t.last + 1));
  for n = 1 to t.last do
    let s = string_of_int starts.(n) in
    Buffer.add_string b (String.make (10 - String.length s) '0' ^ s ^ " 00000 n \n")
  done;
  Buffer.add_string b (Printf.sprintf "trailer\n<< /Size %d /Root %s >>\nstartxref\n%d\n%%%%EOF\n" (t.last + 1) (reference catalog) table);
  Buffer.contents b

(*****************************************************************************)
(* A content *)
(*****************************************************************************)

type content = Buffer.t

let content () : content = Buffer.create 4096
let save (c : content) : unit = Buffer.add_string c "q\n"
let restore (c : content) : unit = Buffer.add_string c "Q\n"

let transform (c : content) (m : Affine.t) : unit =
  Buffer.add_string c (String.concat " " [ fine m.a; fine m.b; fine m.c; fine m.d; num m.tx; num m.ty; "cm\n" ])

(* 0xRRGGBB as three numbers from 0 to 1 *)
let color (rgb : int) : string =
  let part (shift : int) = fixed 5 (float ((rgb lsr shift) land 255) /. 255.) in
  String.concat " " [ part 16; part 8; part 0 ]

let fill_color (c : content) (rgb : int) : unit = Buffer.add_string c (color rgb ^ " rg\n")
let stroke_color (c : content) (rgb : int) : unit = Buffer.add_string c (color rgb ^ " RG\n")
let pen (c : content) (width : float) : unit = Buffer.add_string c (num width ^ " w 1 J 1 j\n")

let opacity (t : t) (c : content) (alpha : float) : unit =
  let a = max 0 (min 100 (int_of_float (Float.round (alpha *. 100.)))) in
  if not (List.mem a t.opacities) then t.opacities <- a :: t.opacities;
  Buffer.add_string c (Printf.sprintf "/A%d gs\n" a)

let point (c : content) ((x, y) : float * float) (operator : string) : unit =
  Buffer.add_string c (num x);
  Buffer.add_char c ' ';
  Buffer.add_string c (num y);
  Buffer.add_string c operator

let polyline (c : content) (points : (float * float) list) : unit =
  match points with
  | [] -> ()
  | [ p ] ->
      point c p " m ";
      point c p " l\n"
  | p :: rest ->
      point c p " m ";
      List.iter (fun (q : float * float) -> point c q " l ") rest;
      Buffer.add_char c '\n'

let polygon (c : content) (points : (float * float) list) : unit =
  match points with
  | [] -> ()
  | p :: rest ->
      point c p " m ";
      List.iter (fun (q : float * float) -> point c q " l ") rest;
      Buffer.add_string c "h\n"

(* a quarter of a circle is nearly a cubic curve whose two control
 * points are 0.5523 of the radius along the tangents at its ends
 * (4/3 (sqrt 2 - 1): the curve's middle is then on the circle) *)
let ellipse (c : content) (m : Affine.t) ~(rx : float) ~(ry : float) : unit =
  let k = 0.5523 in
  let at (x : float) (y : float) = Affine.apply m (x *. rx, y *. ry) in
  let curve (x1, y1) (x2, y2) (x3, y3) =
    point c (at x1 y1) " ";
    point c (at x2 y2) " ";
    point c (at x3 y3) " c "
  in
  point c (at 1. 0.) " m ";
  curve (1., k) (k, 1.) (0., 1.);
  curve (-.k, 1.) (-1., k) (-1., 0.);
  curve (-1., -.k) (-.k, -1.) (0., -1.);
  curve (k, -1.) (1., -.k) (1., 0.);
  Buffer.add_string c "h\n"

let fill (c : content) : unit = Buffer.add_string c "f\n"
let stroke (c : content) : unit = Buffer.add_string c "S\n"

(*****************************************************************************)
(* Text *)
(*****************************************************************************)

(* a character's code in Windows' encoding, by its number: the table
 * the other way round, made once *)
let codes : (int, int) Hashtbl.t = Hashtbl.create 256

let code (rune : int) : int option =
  if Hashtbl.length codes = 0 then Array.iteri (fun (c : int) (r : int) -> if r <> 0 && not (Hashtbl.mem codes r) then Hashtbl.add codes r c) Glyph_names.win_ansi;
  Hashtbl.find_opt codes rune

let writes (rune : int) : bool = code rune <> None

(* which /F a font is, named now if it was not *)
let font_number (t : t) (name : string) : int =
  let rec find (k : int) (l : (string * int) list) = match l with [] -> 0 | (f, _) :: rest -> if f = name then k else find (k - 1) rest in
  match find (List.length t.fonts) t.fonts with
  | 0 ->
      (* a font is a name: the reader has it, and its letters are the
       * 256 of Windows' encoding *)
      let n = add t (Printf.sprintf "<< /Type /Font /Subtype /Type1 /BaseFont /%s /Encoding /WinAnsiEncoding >>" name) in
      t.fonts <- (name, n) :: t.fonts; List.length t.fonts
  | k -> k

let text (t : t) (c : content) ~(font : string) ~(size : float) ((x, y) : float * float) (s : string) : unit =
  let b = Buffer.create (String.length s + 8) in
  let rec go (i : int) =
    if i < String.length s then begin
      let d = String.get_utf_8_uchar s i in
      let rune = Uchar.to_int (Uchar.utf_decode_uchar d) and n = Uchar.utf_decode_length d in
      (match code rune with
       | Some k ->
           (* (a string is between parentheses: those of its own after a
            * backslash, and a byte that is not ASCII by its number) *)
           if k = 0x28 || k = 0x29 || k = 0x5c then begin Buffer.add_char b '\\'; Buffer.add_char b (Char.chr k) end
           else if k < 0x20 || k > 0x7e then Buffer.add_string b (Printf.sprintf "\\%03o" k)
           else Buffer.add_char b (Char.chr k)
       | None -> Buffer.add_char b '?');
      go (i + n)
    end in
  go 0;
  Buffer.add_string c (Printf.sprintf "BT /F%d %s Tf %s %s Td (%s) Tj ET\n" (font_number t font) (num size) (num x) (num y) (Buffer.contents b))

(*****************************************************************************)
(* Pictures and forms *)
(*****************************************************************************)

type named = int

let name (t : t) (n : int) : named =
  t.named <- n :: t.named;
  n

(* a picture: its colours three bytes a pixel, the top row first; and,
 * if a pixel is not opaque, its opacities a byte a pixel in an object
 * of their own (a "soft mask") *)
let picture (t : t) (img : Rgba_image.t) : named =
  let n = img.width * img.height in
  let colours = Bytes.create (3 * n) and mask = Bytes.create n and opaque = ref true in
  for i = 0 to n - 1 do
    Bytes.blit img.rgba (4 * i) colours (3 * i) 3;
    let a = Bytes.get img.rgba ((4 * i) + 3) in
    Bytes.set mask i a;
    if a <> '\255' then opaque := false
  done;
  let entries (space : string) = Printf.sprintf "/Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /%s /BitsPerComponent 8 " img.width img.height space in
  let soft = if !opaque then "" else Printf.sprintf "/SMask %s " (reference (stream t (entries "DeviceGray") (Bytes.to_string mask))) in
  name t (stream t (entries "DeviceRGB" ^ soft) (Bytes.to_string colours))

let form (t : t) ((x0, y0, x1, y1) : float * float * float * float) (c : content) : named =
  let entries = Printf.sprintf "/Type /XObject /Subtype /Form /BBox [%s %s %s %s] /Resources %s " (num x0) (num y0) (num x1) (num y1) (reference resources) in
  name t (stream t entries (Buffer.contents c))

let draw (c : content) (n : named) : unit = Buffer.add_string c (Printf.sprintf "/X%d Do\n" n)

(*****************************************************************************)
(* Pages *)
(*****************************************************************************)

let page (t : t) ~(width : float) ~(height : float) (c : content) : unit =
  let contents = stream t "" (Buffer.contents c) in
  let p =
    add t
      (Printf.sprintf "<< /Type /Page /Parent %s /MediaBox [0 0 %s %s] /Resources %s /Contents %s >>" (reference tree) (num width) (num height)
         (reference resources) (reference contents))
  in
  t.pages <- p :: t.pages
