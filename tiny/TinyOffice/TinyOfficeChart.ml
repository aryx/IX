(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyOfficeChart.mli *)
open TinyLibPlayground
open TinyOfficeModel
open TinyOfficeSheet

(*****************************************************************************)
(* The chart *)
(*****************************************************************************)

(* A chart's data is a line: bars, the sheet it draws by its name, the
 * cells of its values, and of its labels if it has some:
 *
 *     bars budget b1:b3 a1:a3
 *
 * a range being cells of a column or of a row. The values are the
 * sheet's at each view, so a chart follows its sheet; a sheet renamed,
 * its charts are too. *)

(* the cells of a range, "b1:b3" or "a1:c1" ([] if it is none) *)
let range_cells (r : string) : string list =
  let at n = if String.length n >= 2 && n.[0] >= 'a' && n.[0] <= 'z' then
      (match int_of_string_opt (String.sub n 1 (String.length n - 1)) with
       | Some k when k >= 1 -> Some (Char.code n.[0] - 97, k - 1)
       | _ -> None)
    else None in
  match String.split_on_char ':' r with
  | [ a; b ] -> (
      match at a, at b with
      | Some (c0, r0), Some (c1, r1) when c0 = c1 && r1 >= r0 ->
        List.init (r1 - r0 + 1) (fun k -> name c0 (r0 + k))
      | Some (c0, r0), Some (c1, r1) when r0 = r1 && c1 >= c0 ->
        List.init (c1 - c0 + 1) (fun k -> name (c0 + k) r0)
      | _ -> [])
  | _ -> []

(* A chart's bars, each its label and its value (a cell that is not a
 * number, 0), from its sheet on the page; or, none, why *)
let chart_bars (page : obj list) (b : obj) : (string * int) list * string =
  let first =
    match String.split_on_char '\n' b.data with l :: _ -> l | [] -> "" in
  match String.split_on_char ' ' first with
  | "bars" :: sheet :: range :: rest -> (
      match
        List.filter (fun (s : obj) -> s.kind = "sheet" && s.called = sheet)
          page
      with
      | s :: _ ->
          let value = values s.data in
          let labels = match rest with l :: _ -> range_cells l | [] -> [] in
          let label k = match labels with [] -> "" | _ -> (
            match (if k < List.length labels then value (List.nth labels k)
                   else Str "") with
            | Num v -> string_of_int v
            | Str t -> t
            | Err e -> "#" ^ e) in
          let bars =
            List.mapi (fun k n ->
              (label k, match value n with Num v -> v | _ -> 0))
              (range_cells range) in
          if bars = [] then ([], "no cells in " ^ range) else (bars, "")
      | [] -> ([], "no sheet " ^ sheet))
  | _ -> ([], "a chart: bars SHEET b1:b3 a1:a3")

(* the bars' colours, in turn: the paint's blue, red, green, yellow,
 * orange, purple *)
let bar_colours = [ 54; 240; 42; 252; 231; 129 ]

(* A chart: a bar a value, as tall as its share of the largest (none
 * below 0), its value above it, its label under it (cut to its width);
 * the axis a grey line *)
let chart_view (page : obj list) (b : obj) : shape list =
  match chart_bars page b with
  | [], why -> [ Move (b.x + 4, b.y + 2, Words (160, why)) ]
  | bars, _ ->
      let n = List.length bars in
      let top = List.fold_left (fun m (_, v) -> max m v) 1 bars in
      let bw = max 6 ((b.w - 16) / n)
      and base = b.y + b.h - 20
      and room = b.h - 42 in
      let cut t =
        let k = max 0 ((bw - 2) / 8) in
        if String.length t > k then String.sub t 0 k else t in
      List.concat (List.mapi (fun k (label, v) ->
        let x = b.x + 8 + (k * bw) and tall = max 0 (v * room / top) in
        (if tall > 0 then
           [ Move (x + 2, base - tall,
                   Rect (List.nth bar_colours (k mod 6), bw - 4, tall)) ]
         else [])
        @ [ Move (x + 2, base - tall - 16, Words (black, cut (string_of_int v)));
            Move (x + 2, base + 2, Words (black, cut label)) ]) bars)
      @ [ Move (b.x + 4, base, Rect (grey, b.w - 8, 1)) ]

(* a name a sheet can have: a letter, then letters, digits, _ *)
let good_name (n : string) =
  n <> "" && ((n.[0] >= 'a' && n.[0] <= 'z') || (n.[0] >= 'A' && n.[0] <= 'Z'))
  && String.for_all (fun c ->
       (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
       || (c >= '0' && c <= '9') || c = '_') n

(* A key while the selected sheet's name is typed: a character, Backspace,
 * Enter (the name given, to the charts of the sheet too), C-g *)
let name_key (o : office) (typed : string) (k : int) =
  if k >= 32 && k < 127 then
    o.editing <- Naming (typed ^ String.make 1 (Char.chr k))
  else if (k = 8 || k = 127) && typed <> "" then
    o.editing <- Naming (String.sub typed 0 (String.length typed - 1))
  else if k = 13 || k = 10 then begin
    let s = List.nth o.page o.sel in
    if not (good_name typed) then
      o.message <- "a name: a letter, then letters, digits, _"
    else if List.exists (fun (b : obj) -> b.called = typed && b != s) o.page
    then o.message <- "another sheet is " ^ typed
    else begin
      let renamed l =
        match String.split_on_char ' ' l with
        | "bars" :: was :: rest when was = s.called ->
          String.concat " " ("bars" :: typed :: rest)
        | _ -> l in
      keep o;
      o.page <- List.map (fun (b : obj) ->
        if b == s then { b with called = typed }
        else if b.kind = "chart" then
          { b with data =
                     String.concat "\n"
                       (List.map renamed (String.split_on_char '\n' b.data)) }
        else b) o.page;
      o.editing <- Nothing
    end
  end
  else if k = 7 then o.editing <- Nothing

(* a chart of the chosen cell's column, beside its sheet (under it, if
 * the page is too narrow): its cells from the first number to the last,
 * the column at its left their labels *)
let make_chart (o : office) (c : int) =
  let s = List.nth o.page o.sel in
  let value = values s.data in
  let rows =
    List.filter (fun r ->
      match value (name c r) with Num _ -> true | _ -> false)
      (List.init 99 (fun r -> r)) in
  match rows with
  | [] ->
    o.message <- "no numbers in column " ^ String.make 1 (Char.chr (97 + c))
  | r0 :: _ ->
      let r1 = List.fold_left max r0 rows in
      let range c = name c r0 ^ ":" ^ name c r1 in
      let data =
        "bars " ^ s.called ^ " " ^ range c
        ^ (if c > 0 then " " ^ range (c - 1) else "") ^ "\n" in
      let x, y =
        if s.x + s.w + 216 <= o.where.width then s.x + s.w + 16, s.y
        else s.x, s.y + s.h + 24 in
      keep o;
      o.page <-
        o.page @ [ { kind = "chart"; x; y; w = 200; h = 120; data;
                     called = ""; page_no = s.page_no } ];
      o.sel <- List.length o.page - 1;
      o.editing <- Nothing
