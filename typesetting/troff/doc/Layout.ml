(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Layout.mli *)

type piece = { x : float; style : Doc.style; text : string }
type row = Line of piece list | Skip of float | Foot of row list | Together of row list | Rule of float * float | Drawing of float * Doc.picture | Mark of string * bool
type look = { en : float; inch : float; width : float; tag_room : float; justify : bool }

(* a length of the document, in ens, as a whole number of the writer's
 * units. (Not when the unit is the en itself, a terminal's: half a
 * column is kept, and its writer takes the column on the left of each
 * place, as nroff does.) *)
let units (look : look) (ens : float) : float = if look.en = 1. then ens else Float.round (ens *. look.en)
type metrics = Doc.style -> string -> float

(* A paragraph's text cut where a line may be: a word (its letters,
 * maybe in several fonts), the spaces between two, a tab. *)
type atom =
  | Word of (Doc.style * string) list
  (* a word's start, up to a hyphen of its own after which the line
   * may end (non-empty; not the first letter's: -c) *)
  | Start of (Doc.style * string) list
  | Spaces of float
  | Tab
  | Newline
  (* where a line may end between two letters, with a hyphen to add if
   * it does (troff's \%, U+00AD in the text) *)
  | Soft_break

let atoms (metrics : metrics) (body : Doc.inline list) : atom list =
  let out = ref [] and word = ref [] in
  let flush () = if !word <> [] then begin out := Word (List.rev !word) :: !out; word := [] end in
  let add (a : atom) = flush (); out := (match (a, !out) with Spaces w, Spaces v :: rest -> Spaces (v +. w) :: rest | _ -> a :: !out) in
  List.iter (fun (i : Doc.inline) ->
    match i with
    | Doc.Break -> add Newline
    | Doc.Text (style, s) | Doc.Page (style, _, s) ->
        let n = String.length s in
        let rec go from i =
          let letters () = if i > from then word := (style, String.sub s from (i - from)) :: !word in
          if i >= n then letters ()
          else if s.[i] = ' ' then begin letters (); add (Spaces (metrics style " ")); go (i + 1) (i + 1) end
          else if s.[i] = '\t' then begin letters (); add Tab; go (i + 1) (i + 1) end
          else if s.[i] = '\xc2' && i + 1 < n && s.[i + 1] = '\xad' then begin letters (); add Soft_break; go (i + 2) (i + 2) end
          (* (U+2060: nothing; U+200B: a word ends, with no space after) *)
          else if s.[i] = '\xe2' && i + 2 < n && s.[i + 1] = '\x81' && s.[i + 2] = '\xa0' then begin letters (); go (i + 3) (i + 3) end
          else if s.[i] = '\xe2' && i + 2 < n && s.[i + 1] = '\x80' && s.[i + 2] = '\x8b' then begin letters (); flush (); go (i + 3) (i + 3) end
          else if s.[i] = '-' && (i > from || !word <> []) && i + 1 < n && s.[i + 1] <> ' ' && s.[i + 1] <> '\t' then begin
            word := (style, String.sub s from (i + 1 - from)) :: !word;
            out := Start (List.rev !word) :: !out; word := []; go (i + 1) (i + 1)
          end
          else go from (i + 1) in
        go 0 0) body;
  flush (); List.rev !out

(* the stop after x, both from the paragraph's left; past the last, a
 * tab is nothing *)
let next_stop (tabs : float list) (x : float) : float =
  match List.find_opt (fun t -> t > x +. 0.01) tabs with Some t -> t | None -> x

(* [paragraph look metrics left start before p]: the lines of p, the
 * first starting at [start] after the pieces [before] (a tag), the
 * others at [left] *)
let paragraph (look : look) (metrics : metrics) (left : float) (start : float) (before : piece list) (p : Doc.par) : piece list list =
  let lines = ref [] and line = ref (List.rev before) and x = ref start in
  (* how many spaces between words are to the left of each piece of
   * the line, the last first: what a line made even is stretched at *)
  let gaps = ref (List.map (fun _ -> 0) before) and gap = ref 0 in
  let tabs = List.map (units look) p.tabs in
  (* (this paragraph's line's end) *)
  let look = { look with width = look.width -. units look p.short } in
  (* where the line starts: its tabs' stops are from there *)
  let origin = ref start in
  (* the room between the last word and the next, not made yet: none
   * at the start of a line *)
  let space = ref 0. and has_word = ref false and soft = ref false in
  let finish (full : bool) =
    let l = List.rev !line in
    (* a line that ended because the next word did not fit, its right
     * edge put at the line's end: the room left shared between its
     * spaces *)
    let l = if look.justify && full && p.fill && not p.center && !gap > 0 && l <> [] then begin
        let last = List.nth l (List.length l - 1) in
        let each = (look.width -. (last.x +. metrics last.style last.text)) /. float_of_int !gap in
        (* (whole units, and a product that is rounded before it is
         * added: a compiler may do the two in one instruction, a
         * multiply-add with one rounding, and another in two; the same
         * file whatever compiled this) *)
        List.map2 (fun (pc : piece) (g : int) -> let more = Float.round (each *. float_of_int g) in { pc with x = pc.x +. more }) l (List.rev !gaps)
      end else l in
    (* (in the middle of what is between the paragraph's left and the
     * line's end) *)
    let l = if p.center && l <> [] then begin
        let first = List.hd l and last = List.nth l (List.length l - 1) in
        let by = left +. Float.floor ((look.width -. left -. (last.x +. metrics last.style last.text -. first.x)) /. 2.) -. first.x in
        List.map (fun (pc : piece) -> { pc with x = pc.x +. by }) l
      end else l in
    lines := l :: !lines; line := []; gaps := []; gap := 0; x := left; origin := left; space := 0.; has_word := false in
  let place (parts : (Doc.style * string) list) =
    List.iter (fun ((style : Doc.style), s) -> line := { x = !x; style; text = s } :: !line; gaps := !gap :: !gaps; x := !x +. metrics style s) parts;
    has_word := true in
  List.iter (fun (a : atom) ->
    match a with
    | Word parts | Start parts ->
        let w = List.fold_left (fun w ((style : Doc.style), s) -> w +. metrics style s) 0. parts in
        (* (troff asks for a hyphen's room after a word's start, though
         * its own hyphen is there) *)
        let room = match a with Start ((style, _) :: _) -> metrics style "-" | _ -> 0. in
        if p.fill && !has_word && !x +. !space +. w +. room > look.width +. 0.01 then begin
          (match (!soft, !line) with true, last :: _ -> line := { x = !x; style = last.style; text = "-" } :: !line; gaps := !gap :: !gaps | _ -> ());
          finish true
        end
        else begin if !has_word && !space > 0. then incr gap; x := !x +. !space end;
        space := 0.; soft := false;
        place parts
    (* (spaces before any word are the line's own: an example's indent) *)
    | Spaces w -> if !has_word && p.fill then space := !space +. w else x := !x +. w
    | Tab -> x := !origin +. next_stop tabs (!x +. !space -. !origin); space := 0.; has_word := true
    | Soft_break -> soft := true
    | Newline -> finish false) (atoms metrics p.body);
  if !line <> [] || !lines = [] || not p.fill then finish false;
  List.rev !lines

(* a text on one line, from x: a tag, a heading *)
let one_line (metrics : metrics) (x : float) (text : Doc.inline list) : piece list * float =
  let at = ref x and out = ref [] in
  List.iter (fun (i : Doc.inline) ->
    match i with
    (* (a tab in a tag has no stops to go to: a space) *)
    | Doc.Text (style, s) | Doc.Page (style, _, s) -> let s = String.map (fun c -> if c = '\t' then ' ' else c) (Doc.letters s) in out := { x = !at; style; text = s } :: !out; at := !at +. metrics style s
    | Doc.Break -> ()) text;
  (List.rev !out, !at)

(* a cell's text as one string, and its two parts if it is a number:
 * to its decimal point, and from it *)
let cell_text (c : Doc.cell) : string = String.concat "" (List.map (fun (i : Doc.inline) -> match i with Doc.Text (_, s) | Doc.Page (_, _, s) -> Doc.letters s | Doc.Break -> "") c.body)

let split_number (metrics : metrics) (c : Doc.cell) : float * float =
  let s = cell_text c in
  let style = match c.body with Doc.Text (st, _) :: _ -> st | _ -> Doc.plain in
  let at = match String.rindex_opt s '.' with Some i when i + 1 < String.length s && s.[i + 1] >= '0' && s.[i + 1] <= '9' -> i | _ -> String.length s in
  (metrics style (String.sub s 0 at), metrics style (String.sub s at (String.length s - at)))

(* A table: each column as wide as its widest cell (or as the table
 * says), three ens between two. *)
let table (look : look) (metrics : metrics) (left : float) (t : Doc.table) : row list =
  let gap = units look 3. in
  let count = List.fold_left (fun n (r : Doc.table_row) -> match r with Doc.Rule -> n | Doc.Cells cs -> max n (List.fold_left (fun k (c : Doc.cell) -> k + c.span) 0 cs)) 0 t.rows in
  let widths = Array.make (max 1 count) 0. and lefts = Array.make (max 1 count) 0. and rights = Array.make (max 1 count) 0. in
  let said = Array.make (max 1 count) false and wants = Array.make (max 1 count) false in
  List.iteri (fun k w -> if k < count && w > 0. then begin widths.(k) <- units look w; said.(k) <- true end) t.widths;
  let natural (c : Doc.cell) : float = snd (one_line metrics 0. c.body) in
  let each (f : int -> Doc.cell -> unit) = List.iter (fun (r : Doc.table_row) -> match r with Doc.Rule -> () | Doc.Cells cs -> ignore (List.fold_left (fun k (c : Doc.cell) -> f k c; k + c.span) 0 cs)) t.rows in
  each (fun (k : int) (c : Doc.cell) ->
    if c.span = 1 && not said.(k) then begin
      if c.filled then wants.(k) <- true
      else if c.align = Doc.Numeric then begin
        let l, r = split_number metrics c in
        lefts.(k) <- Float.max lefts.(k) l; rights.(k) <- Float.max rights.(k) r;
        widths.(k) <- Float.max widths.(k) (lefts.(k) +. rights.(k))
      end
      else widths.(k) <- Float.max widths.(k) (natural c)
    end
    else if c.span = 1 && c.align = Doc.Numeric then begin
      let l, r = split_number metrics c in
      lefts.(k) <- Float.max lefts.(k) l; rights.(k) <- Float.max rights.(k) r
    end);
  let wanting = Array.fold_left (fun n w -> if w then n + 1 else n) 0 wants in
  if wanting > 0 then begin
    let taken = ref (gap *. float_of_int (count - 1)) in
    Array.iteri (fun k w -> if not wants.(k) then taken := !taken +. w) widths;
    (* (tbl's: a text with no width said has the line's length shared
     * between the columns and one more; less if less is left) *)
    let share = Float.max (units look 10.) (Float.min (Float.floor ((look.width -. left) /. float_of_int (count + 1))) (Float.floor ((look.width -. left -. !taken) /. float_of_int wanting))) in
    Array.iteri (fun k w -> if w then widths.(k) <- Float.max widths.(k) share) wants
  end;
  let total = Array.fold_left (fun s w -> s +. w) (gap *. float_of_int (count - 1)) widths in
  let x0 = if t.centered then left +. Float.max 0. (Float.floor ((look.width -. left -. total) /. 2.)) else left in
  let xs = Array.make (max 1 count) x0 in
  for k = 1 to count - 1 do xs.(k) <- xs.(k - 1) +. widths.(k - 1) +. gap done;
  let rule = Rule (x0, x0 +. total) in
  let rows =
    List.concat_map (fun (r : Doc.table_row) ->
      match r with
      | Doc.Rule -> [ rule ]
      | Doc.Cells cs ->
          let cells = ref [] in
          ignore (List.fold_left (fun k (c : Doc.cell) ->
            if k < count then begin
              let last = min (count - 1) (k + c.span - 1) in
              let w = xs.(last) +. widths.(last) -. xs.(k) in
              let lines =
                if c.filled then paragraph { look with width = xs.(k) +. w; justify = false } metrics xs.(k) xs.(k) [] { fill = true; first = 0.; short = 0.; tabs = []; center = false; body = c.body }
                else begin
                  let pieces, stop = one_line metrics 0. c.body in
                  let by = match c.align with
                    | Doc.Left -> 0.
                    | Doc.Right -> w -. stop
                    | Doc.Center -> Float.floor ((w -. stop) /. 2.)
                    | Doc.Numeric -> if c.span > 1 then 0. else lefts.(k) -. fst (split_number metrics c) in
                  [ List.map (fun (p : piece) -> { p with x = p.x +. xs.(k) +. Float.max 0. by }) pieces ]
                end in
              cells := lines :: !cells
            end;
            k + c.span) 0 cs);
          let cells = List.rev !cells in
          let height = List.fold_left (fun n l -> max n (List.length l)) 1 cells in
          List.init height (fun i -> Line (List.concat_map (fun l -> match List.nth_opt l i with Some pieces -> pieces | None -> []) cells))) t.rows in
  if t.boxed then (rule :: rows) @ [ rule ] else rows

let rec blocks (look : look) (metrics : metrics) (sub : float) (left : float) (bs : Doc.block list) : row list =
  let lines (l : piece list list) : row list = List.map (fun pieces -> Line pieces) l in
  List.concat_map (fun (b : Doc.block) ->
    match b with
    | Doc.Heading (level, text) ->
        (* (a paragraph at the left: a long one takes several lines) *)
        let at = if level <= 1 then 0. else sub in
        lines (paragraph { look with justify = false } metrics at at [] { fill = true; first = 0.; short = 0.; tabs = []; center = false; body = text })
    | Doc.Footnote inner -> [ Foot (blocks look metrics sub left inner) ]
    | Doc.Keep inner -> [ Together (blocks look metrics sub left inner) ]
    | Doc.Table t -> [ Together (table look metrics left t) ]
    (* (in the middle of the line; an inch is 14.4 ens of a text of 10
     * points, 10 of a terminal's letters: [inch]) *)
    | Doc.Picture p ->
        let wide = Float.round (p.wide *. look.inch) in
        [ Drawing (left +. Float.max 0. (Float.floor ((look.width -. left -. wide) /. 2.)), p) ]
    | Doc.Para p -> lines (paragraph look metrics left (left +. units look p.first) [] p)
    | Doc.Indent (by, inner) -> blocks look metrics sub (left +. units look by) inner
    | Doc.Space n -> [ Skip n ]
    | Doc.Anchor (name, lettered) -> [ Mark (name, lettered) ]
    | Doc.Tagged { tag; width; body } ->
        let width = units look width in
        let pieces, stop = one_line metrics left tag in
        (match body with
         (* (the tag and some room after it: tmac.an's 3 points) *)
         | Doc.Para p :: rest when stop -. left < width -. look.tag_room ->
             lines (paragraph look metrics (left +. width) (left +. width +. units look p.first) pieces p) @ blocks look metrics sub (left +. width) rest
         (* (a paragraph of nothing after the tag: the tag's line was
          * ended there, and it has it to itself) *)
         | Doc.Para { body = []; _ } :: rest | rest -> Line pieces :: blocks look metrics sub (left +. width) rest)) bs

let rows (look : look) (metrics : metrics) (d : Doc.t) : row list =
  blocks { look with width = units look d.width } metrics (units look d.sub) (units look d.margin) d.body
