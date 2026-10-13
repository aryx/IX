(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Latex_table.mli *)

open Latex_state
open Latex_input
open Latex_output

(* a length, in the document's ens: 1in, 3cm, 0.5\linewidth *)
let length (t : t) (width : float) (s : string) : float =
  let s = String.trim s in
  let n = String.length s in
  let rec number (i : int) : int = if i < n && (is_digit s.[i] || s.[i] = '.' || s.[i] = '-') then number (i + 1) else i in
  let e = number 0 in
  let v = if e = 0 then 1. else (match float_of_string_opt (String.sub s 0 e) with Some v -> v | None -> 1.) in
  let inch = if t.paper then 14.4 else 10. in
  match String.trim (String.sub s e (n - e)) with
  | "in" -> v *. inch
  | "cm" -> v *. inch /. 2.54
  | "mm" -> v *. inch /. 25.4
  | "pt" -> v *. inch /. 72.27
  | "em" -> v *. (if t.paper then 2. else 1.)
  | "ex" -> v *. 1.
  | "\\linewidth" | "\\textwidth" | "\\columnwidth" | "\\hsize" -> v *. width
  | _ -> 0.

(* A table: its columns' sides, then its rows, cut at \\ and its
 * cells at &, as they are written; a rule is a row. *)
let tabular (t : t) (env_name : string) =
  let width = if t.paper then 86.4 else 60. in
  let asked = if env_name = "tabular*" || env_name = "tabularx" then length t width (arg t) else 0. in
  ignore asked;
  ignore (opt t);
  let spec = arg t in
  let raw = to_end t env_name true in
  (* the columns: a side, whether a text is filled in it, its width *)
  let columns : (Doc.align * bool * float) list =
    let n = String.length spec in
    let rec go (i : int) (acc : (Doc.align * bool * float) list) : (Doc.align * bool * float) list =
      if i >= n then List.rev acc
      else
        let braces (j : int) : string * int = if j < n && spec.[j] = '{' then (let e = closing spec (j + 1) '{' '}' in (String.sub spec (j + 1) (e - j - 1), e + 1)) else ("", j) in
        match spec.[i] with
        | 'l' -> go (i + 1) ((Doc.Left, false, 0.) :: acc)
        | 'c' -> go (i + 1) ((Doc.Center, false, 0.) :: acc)
        | 'r' -> go (i + 1) ((Doc.Right, false, 0.) :: acc)
        | 'X' -> go (i + 1) ((Doc.Left, true, 0.) :: acc)
        | 'p' | 'm' | 'b' -> let w, j = braces (i + 1) in go j ((Doc.Left, true, length t width w) :: acc)
        | '@' | '>' | '<' | '!' -> let _, j = braces (i + 1) in go (max j (i + 1)) acc
        | _ -> go (i + 1) acc in
    go 0 [] in
  let count = max 1 (List.length columns) in
  (* the rows and their cells, as written *)
  let n = String.length raw in
  let rows : string list list ref = ref [] and cells : string list ref = ref [] and from = ref 0 in
  let cell (upto : int) = cells := String.sub raw !from (upto - !from) :: !cells in
  let rec go (i : int) (depth : int) =
    if i >= n then begin cell n; rows := List.rev !cells :: !rows end
    else
      match raw.[i] with
      | '\\' when i + 1 < n && raw.[i + 1] = '\\' && depth = 0 ->
          cell i;
          rows := List.rev !cells :: !rows;
          cells := [];
          let j = if i + 2 < n && raw.[i + 2] = '*' then i + 3 else i + 2 in
          let j = if j < n && raw.[j] = '[' then (match String.index_from_opt raw j ']' with Some e -> e + 1 | None -> j) else j in
          from := j;
          go j depth
      | '\\' when i + 6 < n && String.sub raw i 7 = "\\begin{" -> go (i + 6) (depth + 1)
      | '\\' when i + 4 < n && String.sub raw i 5 = "\\end{" -> go (i + 4) (depth - 1)
      | '\\' -> go (i + 2) depth
      | '%' -> (match String.index_from_opt raw i '\n' with Some e -> go (e + 1) depth | None -> go n depth)
      | '{' -> go (i + 1) (depth + 1)
      | '}' -> go (i + 1) (depth - 1)
      | '[' when i + 1 < n && raw.[i + 1] = '[' -> (let rec close (j : int) : int = if j + 1 >= n then n else if raw.[j] = ']' && raw.[j + 1] = ']' then j + 2 else close (j + 1) in go (close (i + 2)) depth)
      | '&' when depth = 0 -> cell i; from := i + 1; go (i + 1) depth
      | _ -> go (i + 1) depth in
  go 0 0;
  let has (w : string) : bool = let m = String.length w in let rec at (i : int) : bool = i + m <= n && (String.sub raw i m = w || at (i + 1)) in at 0 in
  (* cells that are blocks (a display, chunks of code) are not a
   * table's here: one after the other *)
  if has "\\begin{minipage}" || has "\\VerbatimInput" || has "\\begin{verbatim}" then begin
    par t;
    let file, _ = place t in
    List.iter (fun (row : string list) ->
      List.iter (fun (cell : string) ->
        t.input <- { s = String.trim cell ^ "\n"; i = 0; stop = true; file; line = 1; counts = true } :: t.input;
        t.run t;
        (match t.input with f :: rest when f.stop -> t.input <- rest | _ -> ());
        par t) row) (List.rev !rows)
  end else
  let rules = [ "\\hline"; "\\toprule"; "\\midrule"; "\\bottomrule"; "\\otoprule" ] in
  let starts (s : string) (w : string) : bool = String.length s >= String.length w && String.sub s 0 (String.length w) = w in
  (* the rules a row begins with, and the row without them *)
  let rec ruled (s : string) (k : int) : int * string =
    let s = String.trim s in
    match List.find_opt (starts s) rules with
    | Some w -> ruled (String.sub s (String.length w) (String.length s - String.length w)) (k + 1)
    | None ->
        if starts s "\\cline" || starts s "\\cmidrule" then (match String.index_opt s '}' with Some e -> ruled (String.sub s (e + 1) (String.length s - e - 1)) k | None -> (k, s))
        else if starts s "%" then (match String.index_opt s '\n' with Some e -> ruled (String.sub s (e + 1) (String.length s - e - 1)) k | None -> (k, ""))
        else (k, s) in
  let made : (Doc.cell list option * int) list =
    List.map (fun (row : string list) ->
      match row with
      | [] -> (None, 0)
      | head :: rest ->
          let k, head = ruled head 0 in
          if rest = [] && String.trim head = "" then (None, k)
          else
            (Some (List.mapi (fun (col : int) (raw : string) ->
              let align, filled, _ = match List.nth_opt columns col with Some c -> c | None -> (Doc.Left, false, 0.) in
              t.span <- 1;
              t.cell_align <- None;
              let body = List.map (fun (i : Doc.inline) -> match i with Doc.Break -> Doc.Text (t.look.style, " ") | i -> i) (inlines_of t (String.trim raw)) in
              let c : Doc.cell = { align = (match t.cell_align with Some a -> a | None -> align); span = t.span; filled = filled && t.span = 1; body } in
              c) (head :: rest)), k)) (List.rev !rows) in
  (* a column of long texts is filled in what the line has left, when
   * the table would not fit on it *)
  let longest = Array.make count 0 in
  List.iter (fun ((r, _) : Doc.cell list option * int) ->
    match r with
    | Some cs -> ignore (List.fold_left (fun (k : int) (c : Doc.cell) -> (if c.span = 1 && k < count then longest.(k) <- max longest.(k) (Utf8.length (Doc.words c.body))); k + c.span) 0 cs)
    | None -> ()) made;
  let room = 60 in
  let total = Array.fold_left (fun s w -> s + w) (3 * (count - 1)) longest in
  let given (k : int) : float = match List.nth_opt columns k with Some (_, _, w) -> w | None -> 0. in
  let wants (k : int) : bool = match List.nth_opt columns k with Some (_, f, _) -> f | None -> false in
  let filled (k : int) : bool = given k = 0. && (wants k || total > room) && longest.(k) > room / (count + 1) in
  let long = ref 0 and short = ref (3 * (count - 1)) in
  Array.iteri (fun k w -> if filled k then incr long else short := !short + (if given k > 0. then int_of_float (given k /. cols t 1.) else w)) longest;
  let share = if !long = 0 then 0 else max 10 ((room - !short) / !long) in
  let widths = List.init count (fun k -> if given k > 0. then given k else if filled k then cols t (float_of_int share) else 0.) in
  let rows =
    List.concat_map (fun ((r, k) : Doc.cell list option * int) ->
      List.init (min k 1) (fun _ -> Doc.Rule)
      @ (match r with
         | Some cs -> [ Doc.Cells (snd (List.fold_left (fun ((k, acc) : int * Doc.cell list) (c : Doc.cell) -> (k + c.span, acc @ [ { c with filled = c.span = 1 && (filled k || given k > 0.); align = (if c.span = 1 && filled k then Doc.Left else c.align) } ])) (0, []) cs)) ]
         | None -> [])) made in
  par t;
  let table : Doc.table = { centered = true; boxed = false; widths; rows } in
  block t (Doc.Table table)
