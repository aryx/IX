(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: mini-chrome's libs/fonts/Type1.ml; of_string's clear is said (0: not known), where it was optional; glyph's depth, which only glyph gave itself, is glyph_at's (docs/plans/plan_pdf.md) *)

(* See Type1.mli *)

type t = {
  charstrings : (string, string) Hashtbl.t; (* a glyph's program, by its name *)
  subrs : (int, string) Hashtbl.t;
  encoding : string array; (* a code's glyph *)
  matrix : float list;
}

(* Adobe's cipher: each byte with the high byte of a key that the
 * byte then changes; the first bytes are noise *)
let decrypt (key : int) (skip : int) (s : string) : string =
  let r = ref key in
  let out = String.map (fun c -> let plain = Char.code c lxor (!r lsr 8) in r := ((Char.code c + !r) * 52845 + 22719) land 0xffff; Char.chr plain) s in
  if String.length out > skip then String.sub out skip (String.length out - skip) else ""

let find (s : string) (what : string) (from : int) : int option =
  let n = String.length what in
  let rec go i = if i + n > String.length s then None else if String.sub s i n = what then Some i else go (i + 1) in
  go from

let is_space (c : char) : bool = c = ' ' || c = '\n' || c = '\r' || c = '\t'

(* the next word from i: its text and where it ends *)
let token (s : string) (i : int) : string * int =
  let n = String.length s in
  let i = ref i in
  while !i < n && is_space s.[!i] do incr i done;
  let start = !i in
  if !i < n && s.[!i] = '/' then incr i;
  while !i < n && (not (is_space s.[!i])) && s.[!i] <> '/' && s.[!i] <> '[' && s.[!i] <> ']' && s.[!i] <> '{' && s.[!i] <> '}' do incr i done;
  if !i = start && !i < n then incr i;
  (String.sub s start (!i - start), !i)

(* [of_string ~clear bytes]: a font's file; its first [clear] bytes are
 * plain PostScript (found by "eexec" if 0), the rest ciphered *)
let of_string ~(clear : int) (bytes : string) : t =
  (* a file of its own (.pfb) is in segments, each led by 6 bytes *)
  let bytes =
    if String.length bytes > 6 && bytes.[0] = '\128' then (
      let b = Buffer.create (String.length bytes) and i = ref 0 in
      while !i + 6 <= String.length bytes && bytes.[!i] = '\128' && bytes.[!i + 1] <> '\003' do
        let len = Int32.to_int (String.get_int32_le bytes (!i + 2)) in
        Buffer.add_string b (String.sub bytes (!i + 6) (min len (String.length bytes - !i - 6)));
        i := !i + 6 + len
      done;
      Buffer.contents b)
    else bytes
  in
  let clear =
    match clear with
    | c when c > 0 && c <= String.length bytes -> c
    | _ -> ( match find bytes "eexec" 0 with Some i -> let j = ref (i + 5) in while !j < String.length bytes && is_space bytes.[!j] do incr j done; !j | None -> String.length bytes)
  in
  let head = String.sub bytes 0 clear and body = String.sub bytes clear (String.length bytes - clear) in
  (* the ciphered part as it is, or written in hexadecimal *)
  let body =
    let is_hex c = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F') in
    if String.length body >= 4 && String.for_all (fun c -> is_hex c || is_space c) (String.sub body 0 4) then (
      let b = Buffer.create (String.length body / 2) and high = ref (-1) in
      String.iter (fun c -> if is_hex c then (let v = (match c with '0' .. '9' -> Char.code c - 48 | 'a' .. 'f' -> Char.code c - 87 | _ -> Char.code c - 55) in if !high < 0 then high := v else (Buffer.add_char b (Char.chr ((!high * 16) + v)); high := -1))) body;
      Buffer.contents b)
    else body
  in
  let plain = decrypt 55665 4 body in
  let noise =
    match find plain "/lenIV" 0 with Some i -> ( match int_of_string_opt (fst (token plain (i + 6))) with Some n -> n | None -> 4) | None -> 4
  in
  let t = { charstrings = Hashtbl.create 256; subrs = Hashtbl.create 64; encoding = Array.make 256 ""; matrix = [ 0.001; 0.; 0.; 0.001; 0.; 0. ] } in
  (* "len RD " and then len bytes, ciphered again *)
  let program (i : int) : (string * int) option =
    let len, i = token plain i in
    let _, i = token plain i in
    match int_of_string_opt len with
    | Some len when len >= 0 && i + 1 + len <= String.length plain -> Some (decrypt 4330 noise (String.sub plain (i + 1) len), i + 1 + len)
    | _ -> None
  in
  (match find plain "/Subrs" 0 with
   | Some i ->
       let stop = match find plain "/CharStrings" i with Some j -> j | None -> String.length plain in
       let rec go i =
         match find plain "dup" i with
         | Some i when i < stop -> (
             let number, j = token plain (i + 3) in
             match (int_of_string_opt number, program j) with
             | Some n, Some (p, j) -> Hashtbl.replace t.subrs n p; go j
             | _ -> go (i + 3))
         | _ -> ()
       in
       go i
   | None -> ());
  (match find plain "/CharStrings" 0 with
   | Some i ->
       let rec go i =
         match String.index_from_opt plain i '/' with
         | Some i -> (
             let name, j = token plain i in
             match program j with
             | Some (p, j) -> Hashtbl.replace t.charstrings (String.sub name 1 (String.length name - 1)) p; go j
             | None -> if j < String.length plain then go j)
         | None -> ()
       in
       go (i + 12)
   | None -> ());
  (* the plain part: which glyph each code is ("dup 65 /A put"), the em *)
  let encoding =
    match find head "/Encoding" 0 with
    | Some i when fst (token head (i + 9)) = "StandardEncoding" -> Array.copy Glyph_names.standard_encoding
    | Some i ->
        let stop = match find head "readonly def" i with Some j -> j | None -> String.length head in
        let rec go i =
          match find head "dup" i with
          | Some i when i < stop ->
              let code, j = token head (i + 3) in
              let name, j = token head j in
              (match int_of_string_opt code with Some c when c >= 0 && c < 256 && String.length name > 1 && name.[0] = '/' -> t.encoding.(c) <- String.sub name 1 (String.length name - 1) | _ -> ());
              go j
          | _ -> ()
        in
        go i;
        t.encoding
    | None -> Array.copy Glyph_names.standard_encoding
  in
  let matrix =
    match find head "/FontMatrix" 0 with
    | Some i -> (
        let rec numbers i acc = if List.length acc = 6 then List.rev acc else let w, j = token head i in if j >= String.length head then List.rev acc else numbers j (match float_of_string_opt w with Some f -> f :: acc | None -> acc) in
        match numbers (i + 11) [] with [ _; _; _; _; _; _ ] as m -> m | _ -> t.matrix)
    | None -> t.matrix
  in
  { t with encoding; matrix }

let encoding (t : t) : string array = t.encoding
let matrix (t : t) : float list = t.matrix
let has (t : t) (name : string) : bool = Hashtbl.mem t.charstrings name

(* a glyph's program run: its outline and how far the pen moves after it *)
let rec glyph_at (depth : int) (t : t) (name : string) : Outline.t * float =
  match Hashtbl.find_opt t.charstrings name with
  | None -> ([], 0.)
  | Some program ->
      let pen = Outline.pen () in
      let stack = ref [] and postscript = ref [] and width = ref 0. and bearing = ref 0. and ended = ref false in
      (* a flex: seven moves that are the points of two curves *)
      let flex = ref None and extra = ref [] in
      let args () = let a = Array.of_list (List.rev !stack) in stack := []; a in
      let move dx dy = match !flex with Some points -> pen.x <- pen.x +. dx; pen.y <- pen.y +. dy; flex := Some ((pen.x, pen.y) :: points) | None -> Outline.move pen dx dy in
      let rec run (s : string) (level : int) : unit =
        let i = ref 0 and n = String.length s in
        while (not !ended) && !i < n do
          let b = Char.code s.[!i] in
          incr i;
          let byte k = if !i + k < n then Char.code s.[!i + k] else 0 in
          if b >= 32 then
            if b <= 246 then stack := float_of_int (b - 139) :: !stack
            else if b <= 250 then (stack := float_of_int (((b - 247) * 256) + byte 0 + 108) :: !stack; incr i)
            else if b <= 254 then (stack := float_of_int ((-(b - 251) * 256) - byte 0 - 108) :: !stack; incr i)
            else (
              let v = (byte 0 lsl 24) lor (byte 1 lsl 16) lor (byte 2 lsl 8) lor byte 3 in
              stack := float_of_int (if v >= 0x80000000 then v - 0x100000000 else v) :: !stack;
              i := !i + 4)
          else
            match b with
            | 13 -> let a = args () in if Array.length a >= 2 then (bearing := a.(0); width := a.(1); pen.x <- a.(0); pen.y <- 0.)
            | 21 -> let a = args () in if Array.length a >= 2 then move a.(0) a.(1)
            | 22 -> let a = args () in if Array.length a >= 1 then move a.(0) 0.
            | 4 -> let a = args () in if Array.length a >= 1 then move 0. a.(0)
            | 5 -> let a = args () in if Array.length a >= 2 then Outline.line pen a.(0) a.(1)
            | 6 -> let a = args () in if Array.length a >= 1 then Outline.line pen a.(0) 0.
            | 7 -> let a = args () in if Array.length a >= 1 then Outline.line pen 0. a.(0)
            | 8 -> let a = args () in if Array.length a >= 6 then Outline.curve pen a.(0) a.(1) a.(2) a.(3) a.(4) a.(5)
            | 30 -> let a = args () in if Array.length a >= 4 then Outline.curve pen 0. a.(0) a.(1) a.(2) a.(3) 0.
            | 31 -> let a = args () in if Array.length a >= 4 then Outline.curve pen a.(0) 0. a.(1) a.(2) 0. a.(3)
            | 9 -> let x = pen.x and y = pen.y in Outline.close pen; pen.x <- x; pen.y <- y; stack := []
            | 10 -> (
                match !stack with
                | k :: rest ->
                    stack := rest;
                    (match Hashtbl.find_opt t.subrs (int_of_float k) with Some p when level < 10 -> run p (level + 1) | _ -> ())
                | [] -> ())
            | 11 -> i := n
            | 14 -> ended := true
            | 12 -> (
                let op = byte 0 in
                incr i;
                match op with
                | 7 -> let a = args () in if Array.length a >= 4 then (bearing := a.(0); width := a.(2); pen.x <- a.(0); pen.y <- a.(1))
                | 12 -> ( match !stack with d :: m :: rest -> stack := (m /. d) :: rest | _ -> ())
                | 6 ->
                    (* an accented letter: two glyphs of the standard encoding, the accent moved *)
                    let a = args () in
                    if Array.length a >= 5 && depth < 2 then (
                      let part code = let c = int_of_float code in if c >= 0 && c < 256 then fst (glyph_at (depth + 1) t Glyph_names.standard_encoding.(c)) else [] in
                      let shift dx dy (o : Outline.t) =
                        let m (x, y) = (x +. dx, y +. dy) in
                        List.map (fun (c : Outline.contour) -> { Outline.start = m c.start; segments = List.map (fun (sg : Outline.segment) -> match sg with Line p -> Outline.Line (m p) | Quadratic (c, p) -> Quadratic (m c, m p) | Cubic (c1, c2, p) -> Cubic (m c1, m c2, m p)) c.segments }) o
                      in
                      extra := part a.(3) @ shift (!bearing +. a.(1) -. a.(0)) a.(2) (part a.(4)));
                    ended := true
                | 16 -> (
                    (* a routine of PostScript's, by its number: 1 starts a flex, 2 marks a point, 0 ends it; the others only hand their numbers back *)
                    match !stack with
                    | which :: count :: rest ->
                        let count = int_of_float count in
                        let given = List.filteri (fun k _ -> k < count) rest in
                        stack := List.filteri (fun k _ -> k >= count) rest;
                        (match int_of_float which with
                         | 1 -> flex := Some []
                         | 2 -> ()
                         | 0 ->
                             (match Option.map List.rev !flex with
                              | Some [ _; (x1, y1); (x2, y2); (x3, y3); (x4, y4); (x5, y5); (x6, y6) ] ->
                                  (* back to where the flex started, then its two curves *)
                                  let add c1 c2 p = Outline.add pen (Cubic (c1, c2, p)) in
                                  add (x1, y1) (x2, y2) (x3, y3);
                                  add (x4, y4) (x5, y5) (x6, y6)
                              | _ -> ());
                             flex := None;
                             postscript := [ pen.x; pen.y ]
                         | _ -> postscript := List.rev given @ !postscript)
                    | _ -> ())
                | 17 -> ( match !postscript with v :: rest -> postscript := rest; stack := v :: !stack | [] -> stack := 0. :: !stack)
                | 33 -> stack := []
                | _ -> stack := [])
            | _ -> stack := []
        done
      in
      run program 0;
      (Outline.drawn pen @ !extra, !width)

let glyph (t : t) (name : string) : Outline.t * float = glyph_at 0 t name
