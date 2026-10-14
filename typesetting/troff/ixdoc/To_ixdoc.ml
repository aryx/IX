(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See To_ixdoc.mli *)

open Ixdoc_syntax

let mono : Doc.style = { font = Doc.Mono; size = 0; shift = 0 }
let bold : Doc.style = { font = Doc.Bold; size = 0; shift = 0 }

(* a text with a backslash before what would be read as a mark *)
let escape (s : string) : string =
  let b = Buffer.create (String.length s + 8) and n = String.length s in
  String.iteri (fun i c ->
    let next = if i + 1 < n then s.[i + 1] else ' ' in
    let marks =
      match c with
      | '\\' | '*' | '[' | '{' | '}' | '`' -> true
      | '_' -> i = 0 || not (is_alnum s.[i - 1])
      | '$' -> next <> ' '
      | '<' -> next = 'h'
      | _ -> false in
    if marks then Buffer.add_char b '\\';
    Buffer.add_char b c) s;
  Buffer.contents b

let rec repeat (k : int) (name : string) (s : string) : string = if k <= 0 then s else repeat (k - 1) name ("\\" ^ name ^ "{" ^ s ^ "}")

(* a text's words with their marks, [base] being the style of what is
 * around them (bold, in a heading) *)
let text_of (base : Doc.style) (l : Doc.inline list) : string =
  let b = Buffer.create 256 in
  (* (two texts of one style are one, with one pair of marks) *)
  let rec merge (l : Doc.inline list) : Doc.inline list =
    match l with
    | Doc.Text (s1, a) :: Doc.Text (s2, c) :: rest when s1 = s2 -> merge (Doc.Text (s1, a ^ c) :: rest)
    | Doc.Text (_, "") :: rest -> merge rest
    | x :: rest -> x :: merge rest
    | [] -> [] in
  (* the text before ended with a mark of stars: stars again would be
   * read with them *)
  let starred = ref false in
  List.iter (fun (i : Doc.inline) ->
    match i with
    | Doc.Break -> Buffer.add_string b "\\\n"; starred := false
    | Doc.Text (style, s) | Doc.Page (style, _, s) ->
        let n = String.length s in
        let lead = indent_of s in
        let tail = ref n in
        while !tail > lead && s.[!tail - 1] = ' ' do decr tail done;
        let core = String.sub s lead (!tail - lead) in
        if core = "" then begin Buffer.add_string b s; starred := false end
        else begin
          let stars (k : int) (name : string) : string =
            if !starred && lead = 0 then "\\" ^ name ^ "{" ^ escape core ^ "}"
            else String.make k '*' ^ escape core ^ String.make k '*' in
          let marked =
            if style.font = base.font then escape core
            else match style.font with
              | Doc.Mono -> if String.contains core '`' || String.contains core '\n' then "\\code{" ^ escape core ^ "}" else "`" ^ core ^ "`"
              | Doc.Italic -> stars 1 "emph"
              | Doc.Bold -> stars 2 "strong"
              | Doc.Roman -> "\\roman{" ^ escape core ^ "}" in
          let used = style.font <> base.font && (style.font = Doc.Italic || style.font = Doc.Bold) in
          let marked = repeat (style.size - base.size) "big" (repeat (base.size - style.size) "small" marked) in
          let marked = repeat (style.shift - base.shift) "up" (repeat (base.shift - style.shift) "down" marked) in
          Buffer.add_string b (String.sub s 0 lead); Buffer.add_string b marked; Buffer.add_string b (drop s !tail);
          starred := used && !tail = n && style.size = base.size && style.shift = base.shift
        end) (merge l);
  Buffer.contents b

(* a line that would be read as something else than words: a
 * backslash before its first character *)
let guard (s : string) : string = match classify s with Words | Blank -> s | _ -> let ind = indent_of s in String.make ind ' ' ^ "\\" ^ drop s ind

(* a paragraph's text on lines of 72 letters or less, cut at a space
 * that is alone *)
let wrap (s : string) : string list =
  List.concat_map (fun part ->
    (* (a backslash that ends the line, the break said: put back after) *)
    let broken = ends_with part '\\' && not (String.length part > 1 && part.[String.length part - 2] = '\\') in
    let part = if broken then String.sub part 0 (String.length part - 1) else part in
    let n = String.length part in
    let out = ref [] and start = ref 0 and last = ref (-1) and width = ref 0 in
    (* (not between two back quotes: what starts the next line there
     * could not be guarded) *)
    let code = ref false in
    for i = 0 to n - 1 do
      if Char.code part.[i] land 0xc0 <> 0x80 then incr width;
      if part.[i] = '`' && (i = 0 || part.[i - 1] <> '\\') then code := not !code;
      if part.[i] = ' ' && not !code && i > !start && i + 1 < n && part.[i - 1] <> ' ' && part.[i + 1] <> ' ' && part.[i - 1] <> '\\' then begin
        if !width > 72 && !last >= 0 then begin
          out := String.sub part !start (!last - !start) :: !out;
          start := !last + 1; width := Utf8.length (String.sub part !start (i - !start + 1))
        end;
        last := i
      end
    done;
    if !width > 72 && !last >= !start then begin out := String.sub part !start (!last - !start) :: !out; start := !last + 1 end;
    let ls = List.rev_map guard (drop part !start :: !out) in
    if not broken then ls else List.mapi (fun k l -> if k = List.length ls - 1 then l ^ "\\" else l) ls) (String.split_on_char '\n' s)

let number (v : float) : string =
  let r = Float.round v in
  if Float.abs (v -. r) < 0.005 then string_of_int (int_of_float r) else Printf.sprintf "%.2f" v

let print (paper : bool) (d : Doc.t) : string =
  let columns (ens : float) : float = if paper then ens /. 1.44 else ens in
  let prefixed (first : string) (others : string) (ls : string list) : string list =
    List.mapi (fun k l -> if k = 0 then first ^ l else if l = "" then "" else others ^ l) ls in
  let rec blocks (bs : Doc.block list) : string list =
    let out = ref [] and space = ref false and before = ref None in
    let put (b : Doc.block) (ls : string list) =
      if !space && !out <> [] then out := "" :: !out;
      (* two paragraphs with no space between: the first one's last
       * line ends with a backslash, and the second starts a line *)
      (match (!before, b, !out) with
       | Some (Doc.Para p1), Doc.Para p2, last :: rest when p1.fill && p2.fill && not !space && not p1.center && not p2.center && not (ends_with last '\\') -> out := (last ^ "\\") :: rest
       | _ -> ());
      space := false; before := Some b; out := List.rev_append ls !out in
    List.iter (fun (b : Doc.block) ->
      match b with
      | Doc.Space _ -> space := true
      (* (the format has no sheets: a page's number is the text it has
       * without them) *)
      | Doc.Anchor _ -> ()
      | Doc.Heading (level, text) ->
          let s = String.concat " " (String.split_on_char '\n' (text_of bold (List.filter (fun (i : Doc.inline) -> i <> Doc.Break) text))) in
          put b [ String.make (max 1 (min 6 level)) '#' ^ (if s = "" then "" else " " ^ s) ]
      | Doc.Para p when p.fill ->
          (* (spaces before its first word are the line's own: written
           * as spaces that are not Markdown's) *)
          let text = text_of Doc.plain p.body in
          let lead = indent_of text in
          let ls = wrap (String.concat "" (List.init lead (fun _ -> "\xc2\xa0")) ^ drop text lead) in
          (* (a paragraph of nothing, a line left empty: a backslash alone) *)
          let ls = if p.body = [] then [ "\\" ] else ls in
          put b (if p.center then ("\\center{" :: ls) @ [ "}" ] else ls)
      | Doc.Para p ->
          (* lines as they are: a program's, all in the font of what
           * is typed, or lines with their marks *)
          let rec split (acc : Doc.inline list) (l : Doc.inline list) : Doc.inline list list =
            match l with
            | [] -> [ List.rev acc ]
            | Doc.Break :: rest -> List.rev acc :: split [] rest
            | x :: rest -> split (x :: acc) rest in
          let ls = split [] p.body in
          let plain = List.for_all (fun (i : Doc.inline) -> match i with Doc.Text (s, _) | Doc.Page (s, _, _) -> s = mono | Doc.Break -> true) p.body in
          let ls = List.map (fun l -> if plain then String.concat "" (List.map (fun (i : Doc.inline) -> match i with Doc.Text (_, s) | Doc.Page (_, _, s) -> s | Doc.Break -> "") l) else text_of Doc.plain l) ls in
          let ticks = if List.exists (fun l -> String.length (String.trim l) >= 3 && String.sub (String.trim l) 0 3 = "```") ls then "``````" else "```" in
          put b (((ticks ^ if plain then "" else "lines") :: ls) @ [ ticks ])
      | Doc.Tagged { tag; width; body } ->
          let w = int_of_float (Float.round (columns width)) in
          let inner = blocks body in
          let mark = Doc.words tag in
          let numbered = String.length mark >= 2 && (ends_with mark '.' || ends_with mark ')') && String.for_all is_digit (String.sub mark 0 (String.length mark - 1)) in
          if mark = "\xe2\x80\xa2" || numbered then begin
            let m = if numbered then mark else "-" in
            let w = max w (String.length m + 1) in
            put b (prefixed (m ^ String.make (w - String.length m) ' ') (String.make w ' ') (if inner = [] then [ "" ] else inner))
          end
          else if String.trim mark = "" then put b (("\\indent[" ^ number (columns width) ^ "]{") :: inner @ [ "}" ])
          else begin
            let w = max w 2 in
            let term = guard (String.trim (String.concat " " (String.split_on_char '\n' (text_of Doc.plain (List.filter (fun (i : Doc.inline) -> i <> Doc.Break) tag))))) in
            put b (term :: (if inner = [] then [ ":" ] else prefixed (":" ^ String.make (w - 1) ' ') (String.make w ' ') inner))
          end
      | Doc.Indent (by, inner) ->
          let c = columns by in
          if Float.abs (c -. 5.) < 0.01 then put b (List.map (fun l -> if l = "" then ">" else "> " ^ l) (blocks inner))
          else put b (("\\indent[" ^ number c ^ "]{") :: blocks inner @ [ "}" ])
      | Doc.Footnote inner -> put b ("\\footnote{" :: blocks inner @ [ "}" ])
      | Doc.Keep inner -> put b ("\\keep{" :: blocks inner @ [ "}" ])
      | Doc.Table t ->
          (* a cell's text (a bar in it guarded), and nothing for each
           * column more that it goes across *)
          let cell (base : Doc.style) (c : Doc.cell) : string list =
            let s = String.trim (String.concat " " (String.split_on_char '\n' (text_of base (List.filter (fun (i : Doc.inline) -> i <> Doc.Break) c.body)))) in
            String.concat "\\|" (String.split_on_char '|' s) :: List.init (max 0 (c.span - 1)) (fun _ -> "") in
          let head, data = match t.rows with Doc.Cells h :: Doc.Rule :: rest -> (Some h, rest) | rows -> (None, rows) in
          let first = match (head, List.find_opt (fun (r : Doc.table_row) -> r <> Doc.Rule) data) with Some h, _ -> h | None, Some (Doc.Cells cs) -> cs | _ -> [] in
          let sides = List.concat_map (fun (c : Doc.cell) -> c.align :: List.init (max 0 (c.span - 1)) (fun _ -> Doc.Left)) first in
          let rows = (match head with Some h -> List.concat_map (cell bold) h | None -> List.map (fun _ -> "") sides)
                     :: List.filter_map (fun (r : Doc.table_row) -> match r with Doc.Cells cs -> Some (List.concat_map (cell Doc.plain) cs) | Doc.Rule -> None) data in
          (* each column as wide as its widest cell, the bars one under
           * the other *)
          let count = List.fold_left (fun n r -> max n (List.length r)) (List.length sides) rows in
          let widths = Array.make (max 1 count) 3 in
          List.iter (fun r -> List.iteri (fun k c -> widths.(k) <- max widths.(k) (Utf8.length c)) r) rows;
          let side (k : int) : Doc.align = match List.nth_opt sides k with Some a -> a | None -> Doc.Left in
          let line (r : string list) : string =
            "| " ^ String.concat " | " (List.init count (fun k ->
              let c = match List.nth_opt r k with Some c -> c | None -> "" in
              let pad = String.make (widths.(k) - Utf8.length c) ' ' in
              match side k with Doc.Right | Doc.Numeric -> pad ^ c | _ -> c ^ pad)) ^ " |" in
          let rule = "|" ^ String.concat "|" (List.init count (fun k ->
            let dashes = String.make widths.(k) '-' in
            match side k with Doc.Left -> ":" ^ dashes ^ "-" | Doc.Center -> ":" ^ dashes ^ ":" | Doc.Right | Doc.Numeric -> "-" ^ dashes ^ ":")) ^ "|" in
          put b (match rows with h :: rest -> line h :: rule :: List.map line rest | [] -> [])
      | Doc.Picture { marks = [ Doc.Image (_, _, _, _, name, _) ]; _ } -> put b [ "![" ^ escape name ^ "](" ^ name ^ ")" ]
      | Doc.Picture p ->
          (* pic's own words for what is left of it: lines and texts *)
          let point ((x, y) : float * float) : string = Printf.sprintf "%.3f,%.3f" x y in
          put b (("```pic" :: List.filter_map (fun (m : Doc.mark) ->
            match m with
            | Doc.Stroke (first :: rest) when rest <> [] -> Some ("line from " ^ point first ^ String.concat "" (List.map (fun pt -> " to " ^ point pt) rest))
            | Doc.Stroke _ | Doc.Image _ -> None
            | Doc.Label (x, y, side, text) ->
                let s = String.map (fun c -> if c = '"' then '\'' else c) (text_of Doc.plain (List.filter (fun (i : Doc.inline) -> i <> Doc.Break) text)) in
                Some ("\"" ^ s ^ "\" at " ^ point (x, y) ^ (if side < 0 then " ljust" else if side > 0 then " rjust" else ""))) p.marks) @ [ "```" ])) bs;
    List.rev !out in
  let (left, _, _) = d.header in
  let title =
    match (String.index_opt left '(', ends_with left ')') with
    | Some i, true -> [ "\\title{" ^ escape (String.sub left 0 i) ^ "}{" ^ String.sub left (i + 1) (String.length left - i - 2) ^ "}"; "" ]
    | _ -> [] in
  String.concat "\n" (title @ blocks d.body) ^ "\n"
