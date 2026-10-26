(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyOfficeFile.mli *)
open TinyOfficeModel
open TinyOfficeText
open TinyOfficeSheet

(*****************************************************************************)
(* The file *)
(*****************************************************************************)

(* A page's file is a document in mini-troff's format
 * (plan_typesetting.md): Markdown's lines, and \name[options]{text}
 * for what Markdown has not. Each object is a \box at its place (x, y,
 * width, height), its content the lines up to one that is a } alone:
 *
 *     \box[20 40 200 84]{
 *     # Tiny office
 *
 *     A page of **boxes**, *styled*, \u{underlined}.
 *     }
 *
 *     \box[300 40 282 114]{
 *     | a     | b      |
 *     |-------|--------|
 *     | Rent  | 500    |
 *     | Total | =b1+b2 |
 *     }
 *
 * The kind is in the content: a table is a sheet (its header the
 * columns' letters, then a row a line, what was typed in each cell;
 * its name after its box's numbers), a fence ```drawing, ```paint or
 * ```chart is that (its lines as they are), the rest text. A text's
 * styles are Markdown's, **bold**, *italic*, a line
 * "# " large, and \u{} underlined, \large{} large in a line; \ before a
 * character that would be read otherwise. So emacs edits a page as any
 * text (no count of bytes to keep right), and a Markdown file, with no
 * \box, is opened as one text box. *)

(* a text's line as Markdown, from its characters and their styles *)
let md_of_line (t : string) (st : string) : string =
  let n = String.length t in
  let all_large =
    n > 0 && String.for_all (fun c -> Char.code c land 8 <> 0) st in
  let base = if all_large then 8 else 0 in
  let stars k =
    if k = 1 then "**" else if k = 2 then "*" else if k = 3 then "***"
    else "" in
  let opens k =
    (if k land 8 <> 0 then "\\large{" else "")
    ^ (if k land 4 <> 0 then "\\u{" else "") ^ stars (k land 3) in
  let closes k =
    stars (k land 3) ^ (if k land 4 <> 0 then "}" else "")
    ^ (if k land 8 <> 0 then "}" else "") in
  let one i c =
    if c = '\\' || c = '*' || c = '{' || c = '}'
       || (i = 0 && (c = '#' || c = '|' || c = '`')) then
      "\\" ^ String.make 1 c
    else String.make 1 c in
  let rec go i was acc =
    if i >= n then String.concat "" (List.rev (closes was :: acc))
    else begin
      let k = Char.code st.[i] land lnot base in
      go (i + 1) k
        (one i t.[i]
         :: (if k <> was then opens k :: closes was :: acc else acc))
    end in
  (if all_large then "# " else "") ^ go 0 0 []

(* a Markdown line as characters and their styles: stars toggle italic
 * (one), bold (two), both (three); \u{ and \large{ open a style that
 * the next } closes; \ takes the next character as it is *)
let line_of_md (l : string) : string * string =
  let n = String.length l in
  let base, start =
    if n >= 2 && String.sub l 0 2 = "# " then 8, 2 else 0, 0 in
  let starts i w =
    i + String.length w <= n && String.sub l i (String.length w) = w in
  let rec any l = match l with k :: rest -> k lor any rest | [] -> 0 in
  let rec go i opened stars chars styles =
    let add c =
      go (i + 1) opened stars (String.make 1 c :: chars)
        (String.make 1 (Char.chr (base lor stars lor any opened)) :: styles) in
    if i >= n then
      (String.concat "" (List.rev chars), String.concat "" (List.rev styles))
    else if starts i "\\u{" then go (i + 3) (4 :: opened) stars chars styles
    else if starts i "\\large{" then
      go (i + 7) (8 :: opened) stars chars styles
    else if l.[i] = '\\' && i + 1 < n then
      go (i + 2) opened stars (String.make 1 l.[i + 1] :: chars)
        (String.make 1 (Char.chr (base lor stars lor any opened)) :: styles)
    else if l.[i] = '}' && opened <> [] then
      go (i + 1) (match opened with _ :: rest -> rest | [] -> []) stars chars
        styles
    else if l.[i] = '*' then begin
      let k = if starts i "***" then 3 else if starts i "**" then 2 else 1 in
      go (i + k) opened
        (stars lxor (if k = 1 then 2 else if k = 2 then 1 else 3)) chars styles
    end
    else add l.[i] in
  go start [] 0 [] []

(* a text box's data as Markdown's lines, and back *)
let md_of_text (data : string) : string list =
  let (t, st) = decode data in
  let rec lines i =
    match String.index_from_opt t i '\n' with
    | Some e ->
      md_of_line (String.sub t i (e - i)) (String.sub st i (e - i))
      :: lines (e + 1)
    | None ->
      [ md_of_line (String.sub t i (String.length t - i))
          (String.sub st i (String.length t - i)) ] in
  if t = "" then [] else lines 0

let text_of_md (ls : string list) : string =
  let read = List.map line_of_md ls in
  encode
    (String.concat ""
       (List.mapi (fun k (t, _) -> if k = 0 then t else "\n" ^ t) read))
    (String.concat ""
       (List.mapi (fun k (_, st) -> if k = 0 then st else "\000" ^ st) read))

(* A sheet as a table, its columns as wide as their widest cell, and
 * back (a | in a cell is \|) *)
let md_of_sheet (data : string) : string list =
  let cs = cells data in
  let col n = Char.code n.[0] - 97
  and row n =
    (match int_of_string_opt (String.sub n 1 (String.length n - 1)) with
     | Some r -> r
     | None -> 1) - 1 in
  let ncols = List.fold_left (fun m (n, _) -> max m (col n + 1)) 1 cs
  and nrows = List.fold_left (fun m (n, _) -> max m (row n + 1)) 0 cs in
  let esc s =
    String.concat ""
      (List.map (fun c -> if c = '|' then "\\|" else String.make 1 c)
         (List.init (String.length s) (fun i -> s.[i]))) in
  let cell c r = esc (typed_in data (name c r)) in
  let wide =
    List.init ncols (fun c ->
      List.fold_left (fun m r -> max m (String.length (cell c r))) 1
        (List.init nrows (fun r -> r))) in
  let pad s w = s ^ String.make (w - String.length s) ' ' in
  let line f =
    "|" ^ String.concat ""
            (List.mapi (fun c w -> " " ^ pad (f c) w ^ " |") wide) in
  line (fun c -> String.make 1 (Char.chr (97 + c)))
  :: ("|" ^ String.concat ""
              (List.map (fun w -> String.make (w + 2) '-' ^ "|") wide))
  :: List.init nrows (fun r -> line (fun c -> cell c r))

(* a table's line, its cells: between the |, trimmed, \| a | *)
let table_cells (l : string) : string list =
  let n = String.length l in
  let rec go i cur acc =
    if i >= n then List.rev acc
    else if l.[i] = '\\' && i + 1 < n && l.[i + 1] = '|' then
      go (i + 2) (cur ^ "|") acc
    else if l.[i] = '|' then go (i + 1) "" (String.trim cur :: acc)
    else go (i + 1) (cur ^ String.make 1 l.[i]) acc in
  match go 0 "" [] with _ :: cells -> cells | [] -> []

let sheet_of_md (ls : string list) : string =
  match ls with
  | _ :: _ :: rows ->
      String.concat ""
        (List.concat
           (List.mapi (fun r l ->
              List.concat
                (List.mapi (fun c t ->
                   if t = "" then [] else [ name c r ^ " " ^ t ^ "\n" ])
                   (table_cells l))) rows))
  | _ -> ""

(* a box's lines in the file *)
let box_lines (b : obj) : string list =
  let content =
    if b.kind = "sheet" then md_of_sheet b.data
    else if b.kind = "drawing" || b.kind = "paint" || b.kind = "chart" then
      (* (its lines as they are, a paint's empty rows too; not the empty
       * one after the last newline) *)
      [ "```" ^ b.kind ]
      @ (match List.rev (String.split_on_char '\n' b.data) with
         | "" :: r -> List.rev r
         | l -> List.rev l)
      @ [ "```" ]
    else md_of_text b.data in
  ("\\box[" ^ string_of_int b.x ^ " " ^ string_of_int b.y ^ " "
   ^ string_of_int b.w ^ " " ^ string_of_int b.h
   ^ (if b.called = "" then "" else " " ^ b.called) ^ "]{")
  :: content @ [ "}" ]

(* the file of a document: each page's boxes, a line \newpage between
 * two pages (LaTeX's), an empty line between two boxes *)
let text (o : office) : string =
  let page p =
    List.map box_lines (List.filter (fun (b : obj) -> b.page_no = p) o.page) in
  let blocks =
    List.concat
      (List.init o.where.pages (fun p ->
         (if p = 0 then [] else [ [ "\\newpage" ] ]) @ page p)) in
  String.concat ""
    (List.mapi (fun k ls ->
       (if k = 0 then "" else "\n")
       ^ String.concat "" (List.map (fun l -> l ^ "\n") ls)) blocks)

let obj_of (page_no : int) (x : int) (y : int) (w : int) (h : int)
    (called : string) (ls : string list) : obj =
  let lines_data l = String.concat "" (List.map (fun s -> s ^ "\n") l) in
  match ls with
  | first :: _ when String.length first > 0 && first.[0] = '|' ->
    { kind = "sheet"; x; y; w; h; data = sheet_of_md ls; called; page_no }
  | first :: rest
    when first = "```drawing" || first = "```paint" || first = "```chart" ->
      { kind = String.sub first 3 (String.length first - 3); x; y; w; h;
        data = lines_data (List.filter (fun l -> l <> "```") rest);
        called = ""; page_no }
  | _ ->
    { kind = "text"; x; y; w; h; data = text_of_md ls; called = ""; page_no }

let parse (width : int) (height : int) (s : string) : obj list =
  let is_box l =
    String.length l > 6 && String.sub l 0 5 = "\\box["
    && String.sub l (String.length l - 2) 2 = "]{" in
  let rec go p ls =
    match ls with
    | "\\newpage" :: rest -> go (p + 1) rest
    | l :: rest when is_box l ->
        let words =
          String.split_on_char ' ' (String.sub l 5 (String.length l - 7)) in
        let num v = match int_of_string_opt v with Some k -> k | None -> 0 in
        let rec content acc ls =
          match ls with
          | "}" :: rest -> List.rev acc, rest
          | x :: rest -> content (x :: acc) rest
          | [] -> List.rev acc, [] in
        let (inside, rest) = content [] rest in
        (match words with
         | [ x; y; w; h ] ->
           obj_of p (num x) (num y) (num w) (num h) "" inside :: go p rest
         | [ x; y; w; h; called ] ->
           obj_of p (num x) (num y) (num w) (num h) called inside :: go p rest
         | _ -> go p rest)
    | _ :: rest -> go p rest
    | [] -> [] in
  let ls = String.split_on_char '\n' s in
  if s = "" then []
  else if List.exists is_box ls then go 0 ls
  else
    [ obj_of 0 16 40 (width - 32) (height - 80) ""
        (match List.rev ls with "" :: r -> List.rev r | _ -> ls) ]

(* how many pages a document's file has: one, and one more a \newpage *)
let pages_in (s : string) =
  1 + List.length
        (List.filter (fun l -> l = "\\newpage") (String.split_on_char '\n' s))

(* the pages counted again, after a change: as many as its objects are
 * on, at least *)
let fit_pages (o : office) =
  o.where.pages <-
    List.fold_left (fun m (b : obj) -> max m (b.page_no + 1)) o.where.pages
      o.page
