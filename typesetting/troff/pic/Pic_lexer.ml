(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Pic_lexer.mli *)

open Pic_parser

let is_digit (c : char) = c >= '0' && c <= '9'
let is_letter (c : char) = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c = '_'

let corners = [ "n"; "s"; "e"; "w"; "ne"; "nw"; "se"; "sw"; "c"; "center"; "start"; "end"; "t"; "top"; "b"; "bot"; "bottom"; "l"; "left"; "r"; "right"; "north"; "south"; "east"; "west" ]

let corner (s : string) : string =
  match s with
  | "center" -> "c" | "t" | "top" | "north" -> "n" | "b" | "bot" | "bottom" | "south" -> "s"
  | "l" | "left" | "west" -> "w" | "r" | "right" | "east" -> "e" | _ -> s

let word (s : string) : token =
  match s with
  | "box" | "circle" | "ellipse" | "line" | "arrow" | "arc" | "spline" | "move" -> PRIM s
  | "up" | "down" | "left" | "right" -> DIR s
  | "wid" | "width" -> WID
  | "ht" | "height" -> HT
  | "rad" | "radius" -> RAD
  | "from" -> FROM | "to" -> TO | "at" -> AT | "with" -> WITH | "then" -> THEN
  | "dashed" -> DASHED | "dotted" -> DOTTED | "invis" | "invisible" -> INVIS | "fill" | "filled" -> FILL
  | "same" -> SAME | "chop" -> CHOP | "cw" -> CW | "ccw" -> CCW | "last" -> LAST | "Here" | "here" -> HERE
  | "ljust" | "rjust" | "above" | "below" -> JUST s
  | _ -> if s.[0] >= 'A' && s.[0] <= 'Z' then LABEL s else VAR s

(* a macro's arguments: what is between its parentheses, cut at the
 * commas that are in no parentheses and no string; and where the text
 * goes on *)
let arguments (s : string) (i : int) : string list * int =
  let n = String.length s in
  let b = Buffer.create 16 in
  let rec go j (depth : int) (quoted : bool) (acc : string list) : string list * int =
    if j >= n then (List.rev (String.trim (Buffer.contents b) :: acc), j)
    else
      let c = s.[j] in
      if quoted then begin Buffer.add_char b c; go (j + 1) depth (c <> '"') acc end
      else if c = '"' then begin Buffer.add_char b c; go (j + 1) depth true acc end
      else if c = '(' then begin Buffer.add_char b c; go (j + 1) (depth + 1) false acc end
      else if c = ')' && depth = 0 then (List.rev (String.trim (Buffer.contents b) :: acc), j + 1)
      else if c = ')' then begin Buffer.add_char b c; go (j + 1) (depth - 1) false acc end
      else if c = ',' && depth = 0 then begin let a = String.trim (Buffer.contents b) in Buffer.clear b; go (j + 1) depth false (a :: acc) end
      else begin Buffer.add_char b c; go (j + 1) depth false acc end in
  go i 0 false []

(* a macro's body with $1 ... $9 put in *)
let with_arguments (args : string list) (body : string) : string =
  let n = String.length body and out = Buffer.create (String.length body) in
  let rec go i =
    if i < n then
      if body.[i] = '$' && i + 1 < n && is_digit body.[i + 1] then begin
        (match List.nth_opt args (Char.code body.[i + 1] - Char.code '1') with Some a -> Buffer.add_string out a | None -> ());
        go (i + 2)
      end
      else begin Buffer.add_char out body.[i]; go (i + 1) end in
  go 0; Buffer.contents out

let tokens (load : string -> string option) (text : string) : token list =
  (* troff's requests in the picture, and comments, are not pic's *)
  let lines = List.filter (fun l -> not (String.length l > 0 && l.[0] = '.')) (String.split_on_char '\n' text) in
  let lines = List.map (fun l -> match String.index_opt l '#' with Some i when not (String.contains l '"') -> String.sub l 0 i | _ -> l) lines in
  let macros : (string, string) Hashtbl.t = Hashtbl.create 8 in
  let out = ref [] in
  let emit (t : token) = out := t :: !out in
  (* the end of a statement, once: not after another *)
  let eol () = match !out with EOL :: _ | COLON :: _ | LBRACK :: _ | [] -> () | _ -> emit EOL in
  (* how many times a macro's text was put back: a macro that calls
   * itself has no end *)
  let depth = ref 0 in
  let rec go (s : string) (i : int) =
    let n = String.length s in
    if i < n then
      let c = s.[i] in
      if c = ' ' || c = '\t' || c = '{' || c = '}' then go s (i + 1)
      else if c = '\n' || c = ';' then begin eol (); go s (i + 1) end
      else if c = '\\' && i + 1 < n && s.[i + 1] = '\n' then go s (i + 2)
      else if c = '"' then begin
        let j = ref (i + 1) in
        while !j < n && s.[!j] <> '"' do incr j done;
        emit (STRING (String.sub s (i + 1) (!j - i - 1))); go s (!j + 1)
      end
      else if is_digit c || (c = '.' && i + 1 < n && is_digit s.[i + 1]) then begin
        let j = ref i in
        while !j < n && (is_digit s.[!j] || s.[!j] = '.') do incr j done;
        let v = match float_of_string_opt (String.sub s i (!j - i)) with Some v -> v | None -> 0. in
        (* 2nd, 3rd: which one; 1.5i: inches, which is what a number is *)
        if !j + 1 < n && List.mem (String.sub s !j 2) [ "st"; "nd"; "rd"; "th" ] then begin emit (ORD (int_of_float v)); go s (!j + 2) end
        else begin emit (NUMBER v); go s (if !j < n && s.[!j] = 'i' && not (!j + 1 < n && is_letter s.[!j + 1]) then !j + 1 else !j) end
      end
      else if c = '.' then begin
        let j = ref (i + 1) in
        while !j < n && (is_letter s.[!j] || is_digit s.[!j]) do incr j done;
        let name = String.sub s (i + 1) (!j - i - 1) in
        if List.mem name corners then begin emit (CORNER (corner name)); go s !j end
        else begin emit DOT; go s (i + 1) end
      end
      else if is_letter c then begin
        let j = ref i in
        while !j < n && (is_letter s.[!j] || is_digit s.[!j]) do incr j done;
        let name = String.sub s i (!j - i) in
        (* "end of last line": a corner said before its object *)
        let of_ =
          let k = ref !j in
          while !k < n && (s.[!k] = ' ' || s.[!k] = '\t') do incr k done;
          if !k + 2 < n && String.sub s !k 2 = "of" && not (is_letter s.[!k + 2]) then Some (!k + 2) else None in
        if List.mem name corners && of_ <> None then begin
          emit (CORNEROF (corner name));
          go s (match of_ with Some k -> k | None -> !j)
        end
        else if name = "define" then begin
          (* define name X body X, or { body } *)
          let k = ref !j in
          while !k < n && (s.[!k] = ' ' || s.[!k] = '\t') do incr k done;
          let m = ref !k in
          while !m < n && (is_letter s.[!m] || is_digit s.[!m]) do incr m done;
          let macro = String.sub s !k (!m - !k) in
          while !m < n && (s.[!m] = ' ' || s.[!m] = '\t' || s.[!m] = '\n') do incr m done;
          if !m < n then begin
            let close = if s.[!m] = '{' then '}' else s.[!m] in
            (* (a brace's own braces are counted) *)
            let rec find (p : int) (d : int) : int =
              if p >= n then n
              else if s.[p] = close && d = 0 then p
              else if close = '}' && s.[p] = '{' then find (p + 1) (d + 1)
              else if close = '}' && s.[p] = '}' then find (p + 1) (d - 1)
              else find (p + 1) d in
            let stop = find (!m + 1) 0 in
            Hashtbl.replace macros macro (String.sub s (!m + 1) (stop - !m - 1));
            go s (min n (stop + 1))
          end
        end
        else if name = "copy" then begin
          let k = ref !j in
          while !k < n && s.[!k] <> '"' && s.[!k] <> '\n' do incr k done;
          if !k < n && s.[!k] = '"' then begin
            let e = match String.index_from_opt s (!k + 1) '"' with Some e -> e | None -> n in
            let file = String.sub s (!k + 1) (e - !k - 1) in
            let body = match load file with Some t -> String.concat "\n" (List.filter (fun l -> not (String.length l > 0 && l.[0] = '.')) (String.split_on_char '\n' t)) | None -> "" in
            go (body ^ "\n" ^ String.sub s (min n (e + 1)) (n - min n (e + 1))) 0
          end
          else go s !k
        end
        else
          match Hashtbl.find_opt macros name with
          | Some body when !depth < 1000 ->
              incr depth;
              let args, after = if !j < n && s.[!j] = '(' then arguments s (!j + 1) else ([], !j) in
              go (with_arguments args body ^ " " ^ String.sub s after (n - after)) 0
          | _ -> emit (word name); go s !j
      end
      else begin
        let two = if i + 1 < n then String.sub s i 2 else "" and three = if i + 2 < n then String.sub s i 3 else "" in
        if three = "<->" then begin emit HEAD_BOTH; go s (i + 3) end
        else if two = "->" then begin emit HEAD_END; go s (i + 2) end
        else if two = "<-" then begin emit HEAD_START; go s (i + 2) end
        else begin
          (match c with
           | ':' -> emit COLON | '[' -> emit LBRACK | ']' -> eol (); emit RBRACK
           | '(' -> emit LPAREN | ')' -> emit RPAREN | ',' -> emit COMMA
           | '+' -> emit PLUS | '-' -> emit MINUS | '*' -> emit STAR | '/' -> emit SLASH
           | '<' -> emit LT | '>' -> emit GT | '=' -> emit EQ
           | _ -> ());
          go s (i + 1)
        end
      end in
  go (String.concat "\n" lines) 0;
  eol ();
  List.rev (EOF :: !out)
