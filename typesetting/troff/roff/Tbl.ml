(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Tbl.mli *)

(* a column's format in a row: its letter, its font, its size, its width *)
type column = { key : char; font : string; size : int; width : float }

(* a line of formats: "c s s", "lfCWp-2 | l w(3i)" *)
let formats (roff : Roff.t) (s : string) : column list =
  let n = String.length s in
  let rec go i (acc : column list) : column list =
    if i >= n then List.rev acc
    else
      let c = Char.lowercase_ascii s.[i] in
      if String.contains "lrcnas^" c then go (i + 1) ({ key = (if c = 'a' then 'l' else c); font = ""; size = 0; width = 0. } :: acc)
      else
        match acc with
        | [] -> go (i + 1) acc
        | col :: rest ->
            if c = 'f' then begin
              (* fB, fCW, f(CW) *)
              let j = if i + 1 < n && s.[i + 1] = '(' then i + 2 else i + 1 in
              let k = ref j in
              while !k < n && !k < j + 2 && ((s.[!k] >= 'A' && s.[!k] <= 'Z') || (s.[!k] >= '0' && s.[!k] <= '9')) do incr k done;
              go (if !k < n && s.[!k] = ')' then !k + 1 else !k) ({ col with font = String.sub s j (!k - j) } :: rest)
            end
            else if c = 'b' then go (i + 1) ({ col with font = "B" } :: rest)
            else if c = 'i' then go (i + 1) ({ col with font = "I" } :: rest)
            else if c = 'p' || c = 'v' then begin
              let k = ref (i + 1) in
              while !k < n && (s.[!k] = '-' || s.[!k] = '+' || (s.[!k] >= '0' && s.[!k] <= '9')) do incr k done;
              let v = match int_of_string_opt (String.sub s (i + 1) (!k - i - 1)) with Some v -> v | None -> 0 in
              go !k (if c = 'p' then { col with size = v } :: rest else acc)
            end
            else if c = 'w' then begin
              let j, k =
                if i + 1 < n && s.[i + 1] = '(' then (i + 2, match String.index_from_opt s i ')' with Some k -> k | None -> n)
                else begin
                  let k = ref (i + 1) in
                  while !k < n && ((s.[!k] >= '0' && s.[!k] <= '9') || s.[!k] = '.') do incr k done;
                  (i + 1, !k)
                end in
              go (min n (k + 1)) ({ col with width = Roff.ens roff (Roff.number roff 'n' (String.sub s j (k - j))) } :: rest)
            end
            else go (i + 1) acc in
  go 0 []

let read (roff : Roff.t) (block : unit -> Doc.inline list * string) : Doc.table =
  let centered = ref false and boxed = ref false and tab = ref '\t' in
  let rows = ref [] and widths = ref [] in
  (* the formats not used yet, and the one in use when they are all used *)
  let waiting = ref [] and current = ref [] in
  (* reading formats, to the line that ends with a dot *)
  let in_formats = ref true and first = ref true in
  let format_line (s : string) =
    let s = String.trim s in
    if !first && String.length s > 0 && s.[String.length s - 1] = ';' then
      List.iter (fun o ->
        let o = String.trim o in
        if o = "center" then centered := true
        else if o = "box" || o = "allbox" || o = "doublebox" then boxed := true
        else if String.length o >= 6 && String.sub o 0 4 = "tab(" then tab := o.[4])
        (String.split_on_char ',' (String.concat "," (String.split_on_char ' ' (String.sub s 0 (String.length s - 1)))))
    else begin
      let last = String.length s > 0 && s.[String.length s - 1] = '.' in
      let s = if last then String.sub s 0 (String.length s - 1) else s in
      (* (several rows' formats on one line, with commas) *)
      List.iter (fun part -> let f = formats roff part in if f <> [] then waiting := !waiting @ [ f ]) (String.split_on_char ',' s);
      if last then in_formats := false
    end;
    first := false in
  (* a row's cells from a line of data, each in its column's format *)
  let data (s : string) =
    let format = match !waiting with f :: rest -> waiting := rest; current := f; f | [] -> !current in
    (* (a width said for a column, in whatever row's format) *)
    List.iteri (fun (k : int) (c : column) ->
      if c.width > 0. then begin
        while List.length !widths <= k do widths := !widths @ [ 0. ] done;
        widths := List.mapi (fun i w -> if i = k then c.width else w) !widths
      end) format;
    let rec cells (texts : string list) (format : column list) (acc : Doc.cell list) : Doc.cell list =
      match format with
      | [] -> List.rev acc
      | col :: rest ->
          let text, texts = match texts with t :: more -> (t, more) | [] -> ("", []) in
          (* (the columns after this one that it goes across) *)
          let rec spans (l : column list) (k : int) = match l with { key = 's'; _ } :: more -> spans more (k + 1) | _ -> (k, l) in
          let span, rest = spans rest 1 in
          let align = match col.key with 'r' -> Doc.Right | 'c' -> Doc.Center | 'n' -> Doc.Numeric | _ -> Doc.Left in
          let styled (words : Doc.inline list) : Doc.inline list =
            if col.size = 0 then words
            else List.map (fun (w : Doc.inline) -> match w with Doc.Text (st, t) -> Doc.Text ({ st with size = st.size + col.size }, t) | Doc.Break | Doc.Page _ -> w) words in
          let words (t : string) = styled (if col.font = "" then Roff.inlines roff t else Roff.inlines_in roff (Roff.font_named roff col.font) t) in
          if String.length text >= 2 && String.sub text (String.length text - 2) 2 = "T{" then begin
            (* a text of several lines; what is after its T} are the
             * row's next cells *)
            let body, after = block () in
            let after = if String.length after > 0 && after.[0] = !tab then String.sub after 1 (String.length after - 1) else after in
            let more = if after = "" then [] else String.split_on_char !tab after in
            cells (more @ texts) rest ({ align = Doc.Left; span; filled = true; body = styled body } :: acc)
          end
          else
            let text = if text = "\\^" || text = "_" || text = "\\_" || col.key = '^' then "" else text in
            cells texts rest ({ align; span; filled = false; body = words text } :: acc) in
    rows := Doc.Cells (cells (String.split_on_char !tab s) format []) :: !rows in
  let rec go () =
    match Roff.next roff with
    | None -> ()
    | Some (Roff.Request ("TE", _)) -> ()
    | Some (Roff.Request ("T&", _)) -> in_formats := true; waiting := []; go ()
    | Some (Roff.Request ("ft", a :: _)) -> Roff.set_font roff (Roff.font_named roff a); go ()
    | Some (Roff.Request (_, _)) -> go ()
    | Some (Roff.Text s) ->
        if !in_formats then format_line s
        else if s = "_" || s = "=" then rows := Doc.Rule :: !rows
        else data (Roff.again roff s);
        go () in
  go ();
  Roff.reset_style roff;
  { centered = !centered; boxed = !boxed; widths = !widths; rows = List.rev !rows }
