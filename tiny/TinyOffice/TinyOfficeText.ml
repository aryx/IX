(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyOfficeText.mli *)
open TinyLibPlayground
open TinyOfficeModel

(*****************************************************************************)
(* Text *)
(*****************************************************************************)

(* A text box's data is its text, with a mark where the style changes:
 *
 *     A \{b}bold\{} word, and \{il}large italic\{}.
 *
 * the style's letters between \{ and } (b bold, i italic, u
 * underlined, l large), \{} plain, \\ a backslash. Being edited, it is
 * two strings of the same length: the characters, and their styles. *)
let letters = "biul"

let decode (data : string) : string * string =
  let n = String.length data in
  let rec go i style chars styles =
    if i >= n then
      (String.concat "" (List.rev chars), String.concat "" (List.rev styles))
    else if data.[i] = '\\' && i + 1 < n && data.[i + 1] = '{' then begin
      match String.index_from_opt data i '}' with
      | Some e ->
          let s = ref 0 in
          String.iter (fun c ->
            match String.index_from_opt letters 0 c with
            | Some k -> s := !s lor (1 lsl k)
            | None -> ()) (String.sub data (i + 2) (e - i - 2));
          go (e + 1) !s chars styles
      | None -> go n style chars styles
    end
    else begin
      let skip = if data.[i] = '\\' && i + 1 < n then 1 else 0 in
      go (i + 1 + skip) style (String.make 1 data.[i + skip] :: chars)
        (String.make 1 (Char.chr style) :: styles)
    end in
  go 0 0 [] []

let mark (s : int) =
  "\\{"
  ^ String.concat ""
      (List.init 4 (fun k ->
         if s land (1 lsl k) <> 0 then String.make 1 letters.[k] else ""))
  ^ "}"

let encode (txt : string) (sty : string) : string =
  let rec go i was acc =
    if i >= String.length txt then
      String.concat "" (List.rev (if was <> 0 then mark 0 :: acc else acc))
    else begin
      let s = Char.code sty.[i] in
      let c = if txt.[i] = '\\' then "\\\\" else String.make 1 txt.[i] in
      go (i + 1) s (c :: (if s <> was then mark s :: acc else acc))
    end in
  go 0 0 []

(* A text laid out in a width: each character's place, its x and its
 * line, and the end's (where a cursor after the last character is);
 * each line's top and height, its largest character's. A word goes to
 * the next line when it does not fit (one wider than the line is cut);
 * a newline ends a line. *)
type laid = {
  px : int array; ln : int array; top : int array; tall : int array }

let cw (sty : string) (i : int) = char_width (Char.code sty.[i] lsl 8)

let lay_out (width : int) (txt : string) (sty : string) : laid =
  let n = String.length txt in
  let px = Array.make (n + 1) 0 and ln = Array.make (n + 1) 0 in
  let x = ref 0 and l = ref 0 and i = ref 0 in
  while !i < n do
    if txt.[!i] = '\n' then
      (px.(!i) <- !x; ln.(!i) <- !l; x := 0; incr l; incr i)
    else begin
      let j = ref !i and ww = ref 0 in
      while !j < n && txt.[!j] <> ' ' && txt.[!j] <> '\n' do
        ww := !ww + cw sty !j; incr j
      done;
      if !j = !i then j := !i + 1
      else if !x > 0 && !x + !ww > width then (x := 0; incr l);
      for k = !i to !j - 1 do
        if txt.[k] <> ' ' && !x > 0 && !x + cw sty k > width then
          (x := 0; incr l);
        px.(k) <- !x; ln.(k) <- !l; x := !x + cw sty k
      done;
      i := !j
    end
  done;
  px.(n) <- !x; ln.(n) <- !l;
  let tall = Array.make (!l + 1) 16 and top = Array.make (!l + 1) 0 in
  for k = 0 to n - 1 do
    if txt.[k] <> '\n' then
      tall.(ln.(k)) <-
        max tall.(ln.(k)) (char_height (Char.code sty.[k] lsl 8))
  done;
  for k = 1 to !l do top.(k) <- top.(k - 1) + tall.(k - 1) done;
  { px; ln; top; tall }

(* the place in the text nearest (x, y): on the line there, the first
 * character whose middle is right of x, or the line's last place *)
let index_at (lay : laid) (txt : string) (sty : string) (x : int) (y : int)
    : int =
  let n = String.length txt and lines = Array.length lay.top in
  let line = ref (lines - 1) and found = ref (-1) and last = ref 0 in
  for k = 0 to lines - 1 do
    if !line = lines - 1 && y < lay.top.(k) + lay.tall.(k) then line := k
  done;
  for i = 0 to n do
    if lay.ln.(i) = !line then begin
      last := i;
      if !found < 0
         && (i = n || txt.[i] = '\n' || lay.px.(i) + (cw sty i / 2) > x)
      then found := i
    end
  done;
  if !found >= 0 then !found else !last

(* the selection, from its first character to after its last *)
let selection (d : doc) = (min d.cur d.anchor, max d.cur d.anchor)

(* the cursor put at i, no selection, what is typed next in the style
 * of the character before *)
let go_to (d : doc) (i : int) =
  let i = max 0 (min (String.length d.txt) i) in
  d.cur <- i;
  d.anchor <- i;
  if i > 0 && d.txt.[i - 1] <> '\n' then d.typing <- Char.code d.sty.[i - 1]

(* the selection replaced by a text and its styles *)
let put_text (d : doc) (t : string) (styles : string) =
  let (a, z) = selection d and n = String.length d.txt in
  d.txt <- String.sub d.txt 0 a ^ t ^ String.sub d.txt z (n - z);
  d.sty <- String.sub d.sty 0 a ^ styles ^ String.sub d.sty z (n - z);
  d.cur <- a + String.length t;
  d.anchor <- d.cur

(* A style: the selection's (set, or taken off when all of it has it
 * already), or, nothing selected, what is typed next's; 0 plain. *)
let restyle (d : doc) (bit : int) =
  let (a, z) = selection d in
  if a = z then d.typing <- (if bit = 0 then 0 else d.typing lxor bit)
  else begin
    let all = ref true in
    for i = a to z - 1 do
      if Char.code d.sty.[i] land bit = 0 then all := false
    done;
    let one i =
      let s = Char.code d.sty.[a + i] in
      String.make 1
        (Char.chr
           (if bit = 0 then 0
            else if !all then s land lnot bit
            else s lor bit)) in
    let n = String.length d.txt in
    d.sty <-
      String.sub d.sty 0 a ^ String.concat "" (List.init (z - a) one)
      ^ String.sub d.sty z (n - z)
  end

(* what was cut or copied, its characters and their styles *)
let clipboard = ref ("", "")
let copy (d : doc) =
  let (a, z) = selection d in
  clipboard := (String.sub d.txt a (z - a), String.sub d.sty a (z - a))


(*****************************************************************************)
(* Editing *)
(*****************************************************************************)

(* box i's text edited, its cursor where (x, y) is, the left button
 * selecting from there if it is down *)
let edit (o : office) (i : int) (x : int) (y : int) (selecting : bool) =
  let b = List.nth o.page i in
  let (txt, sty) = decode b.data in
  let d = { txt; sty; cur = 0; anchor = 0; typing = 0; selecting } in
  go_to d
    (index_at (lay_out (b.w - 8) txt sty) txt sty (x - b.x - 4) (y - b.y - 2));
  o.sel <- i;
  o.editing <- Writing d

(* A key in a text: a character typed, in the style of what is typed
 * next; Backspace, C-d the selection or a character deleted; the
 * arrows (C-f, C-p, C-n), C-a, C-e the cursor moved; C-b bold, Tab
 * italic, C-u underlined, C-l large; C-w cut, C-y pasted; C-g no
 * selection. The box grows to show it all. *)
let write_key (o : office) (d : doc) (k : int) =
  let b = List.nth o.page o.sel in
  let lay = lay_out (b.w - 8) d.txt d.sty and n = String.length d.txt in
  let (a, z) = selection d and line = lay.ln.(d.cur) in
  let vertical l =
    if l >= 0 && l < Array.length lay.top then
      go_to d (index_at lay d.txt d.sty lay.px.(d.cur) lay.top.(l)) in
  let rec back i =
    if i > 0 && lay.ln.(i - 1) = line && d.txt.[i - 1] <> '\n' then back (i - 1)
    else i in
  let rec forth i =
    if i < n && d.txt.[i] <> '\n' && lay.ln.(i + 1) = line then forth (i + 1)
    else i in
  if (k >= 32 && k < 127) || k = 10 || k = 13 then
    put_text d (String.make 1 (if k = 13 then '\n' else Char.chr k))
      (String.make 1 (Char.chr d.typing))
  else if k = 8 || k = 127 then
    ((if a = z && a > 0 then d.anchor <- a - 1); put_text d "" "")
  else if k = 4 then
    ((if a = z && z < n then d.anchor <- z + 1); put_text d "" "")
  else if k = 130 then go_to d (if a < z then a else d.cur - 1)
  else if k = 131 || k = 6 then go_to d (if a < z then z else d.cur + 1)
  else if k = 128 || k = 16 then vertical (line - 1)
  else if k = 129 || k = 14 then vertical (line + 1)
  else if k = 1 then go_to d (back d.cur)
  else if k = 5 then go_to d (forth d.cur)
  else if k = 2 then restyle d 1
  else if k = 9 then restyle d 2
  else if k = 21 then restyle d 4
  else if k = 12 then restyle d 8
  else if k = 23 then (copy d; put_text d "" "")
  else if k = 25 then (let (t, st) = !clipboard in put_text d t st)
  else if k = 7 then d.anchor <- d.cur
  else
    o.message <-
      "a text: C-b bold, Tab italic, C-u underlined, C-l large; C-w cut, C-y paste";
  let lay = lay_out (b.w - 8) d.txt d.sty in
  let last = Array.length lay.top - 1 in
  let need = lay.top.(last) + lay.tall.(last) + 6 in
  if need > b.h then o.page <- replace o.page o.sel (Some { b with h = need })

(*****************************************************************************)
(* The view *)
(*****************************************************************************)

(* A text box: a word for each run of characters of a style on a line,
 * at the line's bottom (a line with a large character is taller); the
 * lines that fit. Being edited, the selection under the words in pale
 * blue, a rectangle a line, and the cursor. *)
let text_view (b : obj) (txt : string) (sty : string) (editing : doc option)
    : shape list =
  let lay = lay_out (b.w - 8) txt sty and n = String.length txt in
  let fits l = lay.top.(l) + lay.tall.(l) <= b.h - 4 in
  let x0 = b.x + 4 and y0 = b.y + 2 in
  let rec runs i acc =
    if i >= n then acc
    else if txt.[i] = '\n' || not (fits lay.ln.(i)) then runs (i + 1) acc
    else begin
      let j = ref (i + 1) and l = lay.ln.(i) and c = Char.code sty.[i] lsl 8 in
      while !j < n && txt.[!j] <> '\n' && lay.ln.(!j) = l
            && sty.[!j] = sty.[i] do
        incr j
      done;
      runs !j
        (Move (x0 + lay.px.(i), y0 + lay.top.(l) + lay.tall.(l) - char_height c,
               Words (black lor c, String.sub txt i (!j - i))) :: acc)
    end in
  let marks = match editing with
    | None -> []
    | Some d ->
        let (a, z) = selection d in
        (* the selection's pieces, a line each: its line, its two ends *)
        let rec pieces i acc =
          if i >= z then acc
          else begin
            let l = lay.ln.(i) and w = if txt.[i] = '\n' then 4 else cw sty i in
            match acc with
            | (l', p, q) :: rest when l' = l && q = lay.px.(i) ->
              pieces (i + 1) ((l, p, q + w) :: rest)
            | _ -> pieces (i + 1) ((l, lay.px.(i), lay.px.(i) + w) :: acc)
          end in
        let l = lay.ln.(d.cur) in
        List.concat
          (List.map (fun (l, p, q) ->
             if fits l then
               [ Move (x0 + p, y0 + lay.top.(l),
                       Rect (pale_blue, q - p, lay.tall.(l))) ]
             else []) (pieces a []))
        @ (if fits l then
             [ Move (x0 + lay.px.(d.cur), y0 + lay.top.(l),
                     Rect (black, 2, lay.tall.(l))) ]
           else []) in
  marks @ List.rev (runs 0 [])
