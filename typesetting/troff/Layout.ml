(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Layout.mli *)

type piece = { x : float; style : Doc.style; text : string }
type line = piece list
type look = { width : float; margin : float; sub : float }
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
    | Doc.Text (style, s) ->
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
let paragraph (look : look) (metrics : metrics) (left : float) (start : float) (before : piece list) (p : Doc.par) : line list =
  let lines = ref [] and line = ref (List.rev before) and x = ref start in
  (* where the line starts: its tabs' stops are from there *)
  let origin = ref start in
  (* the room between the last word and the next, not made yet: none
   * at the start of a line *)
  let space = ref 0. and has_word = ref false and soft = ref false in
  let finish () =
    let l = List.rev !line in
    (* (in the middle of what is between the paragraph's left and the
     * line's end) *)
    let l = if p.center && l <> [] then begin
        let first = List.hd l and last = List.nth l (List.length l - 1) in
        let by = left +. Float.floor ((look.width -. left -. (last.x +. metrics last.style last.text -. first.x)) /. 2.) -. first.x in
        List.map (fun (pc : piece) -> { pc with x = pc.x +. by }) l
      end else l in
    lines := l :: !lines; line := []; x := left; origin := left; space := 0.; has_word := false in
  let place (parts : (Doc.style * string) list) =
    List.iter (fun ((style : Doc.style), s) -> line := { x = !x; style; text = s } :: !line; x := !x +. metrics style s) parts;
    has_word := true in
  List.iter (fun (a : atom) ->
    match a with
    | Word parts | Start parts ->
        let w = List.fold_left (fun w ((style : Doc.style), s) -> w +. metrics style s) 0. parts in
        (* (troff asks for a hyphen's room after a word's start, though
         * its own hyphen is there) *)
        let room = match a with Start ((style, _) :: _) -> metrics style "-" | _ -> 0. in
        if p.fill && !has_word && !x +. !space +. w +. room > look.width +. 0.01 then begin
          (match (!soft, !line) with true, last :: _ -> line := { x = !x; style = last.style; text = "-" } :: !line | _ -> ());
          finish ()
        end
        else x := !x +. !space;
        space := 0.; soft := false;
        place parts
    (* (spaces before any word are the line's own: an example's indent) *)
    | Spaces w -> if !has_word && p.fill then space := !space +. w else x := !x +. w
    | Tab -> x := !origin +. next_stop p.tabs (!x +. !space -. !origin); space := 0.; has_word := true
    | Soft_break -> soft := true
    | Newline -> finish ()) (atoms metrics p.body);
  if !line <> [] || !lines = [] || not p.fill then finish ();
  List.rev !lines

(* a text on one line, from x: a tag, a heading *)
let one_line (metrics : metrics) (x : float) (text : Doc.inline list) : piece list * float =
  let at = ref x and out = ref [] in
  List.iter (fun (i : Doc.inline) ->
    match i with
    | Doc.Text (style, s) -> let s = Doc.letters s in out := { x = !at; style; text = s } :: !out; at := !at +. metrics style s
    | Doc.Break -> ()) text;
  (List.rev !out, !at)

let rec blocks (look : look) (metrics : metrics) (left : float) (bs : Doc.block list) : line list =
  List.concat_map (fun (b : Doc.block) ->
    match b with
    | Doc.Heading (level, text) -> [ fst (one_line metrics (if level <= 1 then 0. else look.sub) text) ]
    | Doc.Para p -> paragraph look metrics left (left +. p.first) [] p
    | Doc.Indent (by, inner) -> blocks look metrics (left +. by) inner
    | Doc.Space n -> List.init (int_of_float (Float.round n)) (fun _ -> [])
    | Doc.Tagged { tag; width; body } ->
        let pieces, stop = one_line metrics left tag in
        (match body with
         (* (the tag and some room after it: tmac.an's 3 points) *)
         | Doc.Para p :: rest when stop -. left < width -. 0.4 ->
             paragraph look metrics (left +. width) (left +. width +. p.first) pieces p @ blocks look metrics (left +. width) rest
         (* (a paragraph of nothing after the tag: the tag's line was
          * ended there, and it has it to itself) *)
         | Doc.Para { body = []; _ } :: rest | rest -> pieces :: blocks look metrics (left +. width) rest)) bs

let lines (look : look) (metrics : metrics) (bs : Doc.block list) : line list = blocks look metrics look.margin bs
