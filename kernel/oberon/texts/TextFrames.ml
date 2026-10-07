(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See TextFrames.mli *)

let bs = '\008'
let tab = '\t'
let cr = '\r'
let del = '\127'

(* the standard sizes, from the default font: a line's height; the
 * margins (the left one after the scroll bar); the font's parts above
 * and below the base line; the selection's and the bar's mark's sizes;
 * the width a line's end is given *)
let lsp = (Fonts.default ()).height
let menu_h = lsp + 2
let bar_w = menu_h
let left = bar_w + (lsp / 2)
let top = lsp / 2
let bot = lsp / 2
let ascent = (Fonts.default ()).max_y
let descent = - (Fonts.default ()).min_y
let sel_h = lsp
let mark_w = lsp / 2
let eol_w = lsp / 2

exception Update of Texts.op * Texts.t * int * int
exception Copy_over of Texts.t * int * int

(* a line shown: its characters (the one that ends it counted), its
 * width, whether the text ends in it *)
type line = { chars : int; wid : int; eot : bool }

(* a place in the frame: the line it is in (which one, and where it
 * starts in the text), a position, and where that is drawn, from the
 * frame's corner; dx: the width of what is there *)
type location = { row : int; org : int; pos : int; x : int; y : int; dx : int }
let nowhere = { row = 0; org = 0; pos = 0; x = 0; y = 0; dx = 0 }

(* a text frame's own (Oberon's FrameDesc, extended): the frame, the
 * text, where the first line starts in it, the lines shown *)
type t = {
  f : Display.frame;
  text : Texts.t;
  mutable first : int;
  bg : Display.color;
  left : int; top : int; bot : int;
  mutable lines : line list;
  mutable mark_h : int; mutable has_mark : bool;
  mutable has_car : bool; mutable car : location;
  mutable has_sel : bool; mutable sel_beg : location; mutable sel_end : location; mutable time : int;
}

(* which text frame a frame is: the answer *)
type answer = { mutable it : t option }
exception Identify of answer

let this (f : Display.frame) =
  let a = { it = None } in
  Display.send f (Identify a);
  a.it

let text_of (s : t) = s.text
let caret (s : t) = if s.has_car then Some s.car.pos else None

let tbuf = ref (Texts.open_buf ())
let recall () = let b = !tbuf in tbuf := Texts.open_buf (); b
let del_buf = Texts.open_buf ()
(* the keyboard's writer, the menus' *)
let kw = Texts.open_writer ()
let w = Texts.open_writer ()

(*****************************************************************************)
(* Showing the lines *)
(*****************************************************************************)

(* line k's base, from the frame's bottom; the lowest a base may be *)
let base (s : t) k = s.f.h - s.top - ascent - (k * lsp)
let lowest (s : t) = s.bot + descent

(* the display's operation, cut at the frame's right edge *)
let repl_const (s : t) (col : Display.color) x y w h (mode : Display.mode) =
  let w = min w (s.f.x + s.f.w - x) in
  if w > 0 then Display.repl_const col x y w h mode

(* a line drawn from the reader, its base at y: to its end or the text's *)
let display_line (s : t) (r : Texts.reader) y : line =
  let nx = s.f.x + s.f.w in
  let rec go x n =
    let ch = Texts.read r in
    if r.eot || ch = cr then { chars = n + 1; wid = x + eol_w - (s.f.x + s.left); eot = r.eot }
    else begin
      let c = Fonts.get r.fnt ch in
      if x + c.x + c.w <= nx && c.h <> 0 then Display.copy_pattern White c.pattern (x + c.x) (y + c.y) Invert;
      go (x + c.dx) (n + 1)
    end
  in
  go (s.f.x + s.left) 0

(* the lines from line k down, read from org: as many as the frame has room for *)
let rec lines_from (s : t) r k : line list =
  if base s k < lowest s then []
  else begin
    let l = display_line s r (s.f.y + base s k) in
    if l.eot then [ l ] else l :: lines_from s r (k + 1)
  end

(* the text's part from line k to the frame's bottom, blank *)
let clear_from (s : t) k =
  let h = base s k + ascent in
  if h > 0 then repl_const s s.bg (s.f.x + s.left) s.f.y (s.f.w - s.left) h Replace

(* a position made a line's start: that of the line after it, when it is inside one *)
let validate (text : Texts.t) pos =
  if pos >= text.len then text.len
  else if pos <= 0 then 0
  else begin
    let r = Texts.open_reader text (pos - 1) in
    let rec go () = let ch = Texts.read r in if r.eot || ch = cr then Texts.pos r else go () in
    go ()
  end

let mark_height (s : t) = s.first * s.f.h / (s.text.len + 1)

(* the mark in the scroll bar: how far in the text the frame is *)
let mark (s : t) on =
  if s.f.h > 0 && s.left >= bar_w && s.has_mark <> on then
    Display.repl_const White (s.f.x + 1) (s.f.y + s.f.h - 1 - s.mark_h) mark_w 1 Invert;
  s.has_mark <- on

(* in the corner, a block: the text was changed and not stored *)
let set_change_mark (s : t) on =
  if s.f.h > menu_h then begin
    if on then Display.copy_pattern White Display.block (s.f.x + s.f.w - 12) (s.f.y + s.f.h - 12) Paint
    else Display.repl_const s.bg (s.f.x + s.f.w - 12) (s.f.y + s.f.h - 12) 8 8 Replace
  end

let bar (s : t) y h = if s.left >= bar_w && h > 0 then Display.repl_const White (s.f.x + bar_w - 1) y 1 h Invert

(* the frame's bottom goes down to new_y: the lines that now fit, after those shown *)
let extend (s : t) new_y =
  let f = s.f in
  Display.repl_const s.bg f.x new_y f.w (f.y - new_y) Replace;
  bar s new_y (f.y - new_y);
  f.h <- f.h + f.y - new_y; f.y <- new_y;
  if s.lines = [] then s.first <- validate s.text s.first;
  let shown = List.length s.lines in
  let org = List.fold_left (fun o (l : line) -> o + l.chars) s.first s.lines in
  if s.lines = [] || not (List.nth s.lines (shown - 1)).eot then
    s.lines <- s.lines @ lines_from s (Texts.open_reader s.text org) shown;
  s.mark_h <- mark_height s

(* the frame's bottom goes up to new_y: the lines that no longer fit forgotten *)
let reduce (s : t) new_y =
  let f = s.f in
  f.h <- f.h + f.y - new_y; f.y <- new_y;
  s.lines <- List.filteri (fun k _ -> base s k >= lowest s) s.lines;
  let below = base s (List.length s.lines) + ascent in
  if below > 0 && f.h > 0 then repl_const s s.bg (f.x + s.left) f.y (f.w - s.left) below Replace;
  s.mark_h <- mark_height s

(* the line at pos becomes the first *)
let show (s : t) pos =
  if s.lines <> [] then begin
    let pos = validate s.text pos in
    if pos <> s.first then begin
      mark s false;
      clear_from s 0;
      s.first <- pos;
      s.lines <- lines_from s (Texts.open_reader s.text pos) 0;
      s.mark_h <- mark_height s;
      mark s true
    end
  end;
  set_change_mark s s.text.changed

(*****************************************************************************)
(* Where things are *)
(*****************************************************************************)

(* the line that has the height y: its number, where it starts in the text, its base *)
let locate_line (s : t) y =
  let rec go k org (lines : line list) =
    match lines with
    | l :: (_ :: _ as rest) when base s k > y + descent -> go (k + 1) (org + l.chars) rest
    | l :: _ -> k, org, l
    | [] -> k, org, { chars = 1; wid = 0; eot = true }
  in
  go 0 s.first s.lines

(* a line's characters but the one that ends it, each with its width *)
let widths (s : t) org (l : line) =
  let r = Texts.open_reader s.text org in
  Array.init (l.chars - 1) (fun _ -> let ch = Texts.read r in ch, (Fonts.get r.fnt ch).dx)

(* the character at (x, y), or the line's end *)
let locate_char (s : t) x y : location =
  let row, org, l = locate_line s y in
  let ws = widths s org l in
  let rec go i ox =
    if i < Array.length ws && ox + snd ws.(i) <= x then go (i + 1) (ox + snd ws.(i))
    else { row; org; pos = org + i; x = ox; y = base s row; dx = (if i < Array.length ws then snd ws.(i) else eol_w) }
  in
  go 0 s.left

(* the word at (x, y): where it starts, its width *)
let locate_string (s : t) x y : location =
  let row, org, l = locate_line s y in
  let ws = widths s org l in
  let n = Array.length ws in
  let gap i = fst ws.(i) <= ' ' in
  (* from i, a word's start at ox: its end, then the gap after it *)
  let rec word i ox b bx =
    let rec skip i ox pred = if i < n && pred i then skip (i + 1) (ox + snd ws.(i)) pred else i, ox in
    let i, ex = skip i ox (fun i -> not (gap i)) in
    let i, ox = skip i ex gap in
    if i < n && ox <= x then word (i + 1) (ox + snd ws.(i)) i ox else b, bx, ex
  in
  let b, bx, ex = word 0 s.left 0 s.left in
  { row; org; pos = org + b; x = bx; y = base s row; dx = ex - bx }

(* where a position of the text is drawn (one not shown: the nearest that is) *)
let locate_pos (s : t) pos : location =
  let pos = max pos s.first in
  let rec go k org (lines : line list) =
    match lines with
    | l :: (_ :: _ as rest) when pos >= org + l.chars -> go (k + 1) (org + l.chars) rest
    | l :: _ -> k, org, l
    | [] -> k, org, { chars = 1; wid = 0; eot = true }
  in
  let row, org, l = go 0 s.first s.lines in
  let pos = min pos (org + l.chars - 1) in
  let ws = widths s org l in
  let x = ref s.left in
  for i = 0 to pos - org - 1 do x := !x + snd ws.(i) done;
  { row; org; pos; x = !x; y = base s row; dx = (if pos - org < Array.length ws then snd ws.(pos - org) else eol_w) }

(*****************************************************************************)
(* The caret, the selection *)
(*****************************************************************************)

let flip_caret (s : t) =
  let c = s.car in
  if c.x < s.f.w && c.y >= 10 && c.x + 12 < s.f.w then Display.copy_pattern White Display.hook (s.f.x + c.x) (s.f.y + c.y - 10) Invert

let set_caret (s : t) pos = s.car <- locate_pos s pos; flip_caret s; s.has_car <- true
let remove_caret (s : t) = if s.has_car then begin flip_caret s; s.has_car <- false end

(* the mouse followed while its keys are held: [moved x y] at each new
 * place; the keys that were down meanwhile *)
let track marker moved =
  let rec go keysum =
    let keys, x, y = Input.mouse () in
    Oberon.draw_mouse marker x y;
    moved x y;
    if keys = 0 then keysum else go (keysum lor keys)
  in
  go 0

let track_caret (s : t) x y =
  if s.lines = [] then 0
  else begin
    s.car <- locate_char s (x - s.f.x) (y - s.f.y);
    flip_caret s;
    let keysum = track Oberon.arrow (fun x y ->
      let loc = locate_char s (x - s.f.x) (y - s.f.y) in
      if loc.pos <> s.car.pos then begin flip_caret s; s.car <- loc; flip_caret s end) in
    s.has_car <- true;
    keysum
  end

(* the stretch from a place to another, inverted: a rectangle a line *)
let flip_selection (s : t) (b : location) (e : location) =
  let f = s.f in
  let y k = f.y + base s k - 2 in
  let width k = (List.nth s.lines k).wid in
  if b.row = e.row then repl_const s White (f.x + b.x) (y b.row) (e.x - b.x) sel_h Invert
  else begin
    repl_const s White (f.x + b.x) (y b.row) (s.left + width b.row - b.x) sel_h Invert;
    for k = b.row + 1 to e.row - 1 do repl_const s White (f.x + s.left) (y k) (width k) sel_h Invert done;
    repl_const s White (f.x + s.left) (y e.row) (e.x - s.left) sel_h Invert
  end

let remove_selection (s : t) = if s.has_sel then begin flip_selection s s.sel_beg s.sel_end; s.has_sel <- false end

let set_selection (s : t) beg end_ =
  remove_selection s;
  s.sel_beg <- locate_pos s beg; s.sel_end <- locate_pos s end_;
  if s.sel_beg.pos < s.sel_end.pos then begin
    flip_selection s s.sel_beg s.sel_end; s.time <- Oberon.time (); s.has_sel <- true
  end

(* the place after a character's *)
let after (loc : location) = { loc with pos = loc.pos + 1; x = loc.x + loc.dx }

let track_selection (s : t) x y =
  if s.lines = [] then 0
  else begin
    if s.has_sel then flip_selection s s.sel_beg s.sel_end;
    let loc = locate_char s (x - s.f.x) (y - s.f.y) in
    (* (a character selected, clicked again: its line from its start) *)
    s.sel_beg <-
      (if s.has_sel && loc.pos = s.sel_beg.pos && s.sel_end.pos = s.sel_beg.pos + 1 then locate_char s s.left (y - s.f.y) else loc);
    s.sel_end <- after loc;
    flip_selection s s.sel_beg s.sel_end;
    let keysum = track Oberon.arrow (fun x y ->
      let loc = locate_char s (x - s.f.x) (y - s.f.y) in
      let loc = after (if loc.pos < s.sel_beg.pos then s.sel_beg else loc) in
      if loc.pos < s.sel_end.pos then begin flip_selection s loc s.sel_end; s.sel_end <- loc end
      else if loc.pos > s.sel_end.pos then begin flip_selection s s.sel_end loc; s.sel_end <- loc end) in
    s.time <- Oberon.time (); s.has_sel <- true;
    keysum
  end

(* a line (in the scroll bar) or a word (a command's) underlined while
 * the keys are held, the one under the mouse; where it is in the text *)
let underline (s : t) (loc : location) w = repl_const s White (s.f.x + loc.x) (s.f.y + loc.y - descent) w 2 Invert

let track_under (s : t) marker locate x y =
  if s.lines = [] then 0, 0
  else begin
    let old = ref (locate (x - s.f.x) (y - s.f.y)) in
    underline s !old !old.dx;
    let keysum = track marker (fun x y ->
      let loc : location = locate (x - s.f.x) (y - s.f.y) in
      if loc.pos <> !old.pos then begin underline s !old !old.dx; underline s loc loc.dx; old := loc end) in
    underline s !old !old.dx;
    !old.pos, keysum
  end

(* the scroll bar's cursor: an arrow up and down *)
let flip_sm x y =
  Display.copy_pattern White Display.updown (max 3 (min x (Display.width - 4)) - 4) (max 6 (min y (Display.height - 6)) - 4) Invert
let scroll_marker : Oberon.marker = { fade = flip_sm; draw = flip_sm }

let track_line (s : t) x y =
  track_under s scroll_marker (fun _ y -> let row, org, l = locate_line s y in { row; org; pos = org; x = s.left; y = base s row; dx = l.wid }) x y
let track_word (s : t) x y = track_under s Oberon.arrow (locate_string s) x y

(*****************************************************************************)
(* The text changed *)
(*****************************************************************************)

let remove_marks (s : t) = remove_caret s; remove_selection s

(* The text's stretch [beg, end_) was inserted, deleted (it was there)
 * or changed looks. Before the frame's first line, only where that
 * line is in the text changes. Else the line that has beg is drawn
 * again, alone when no line was made or gone, with those after it
 * otherwise. *)
let update (s : t) (op : Texts.op) beg end_ =
  set_change_mark s false;
  remove_marks s; Oberon.remove_marks s.f.x s.f.y s.f.w s.f.h;
  let n = end_ - beg in
  if s.lines <> [] then begin
    if op = Texts.Insert && beg < s.first then s.first <- s.first + n
    else if op = Texts.Delete && end_ <= s.first then s.first <- s.first - n
    else if beg < s.first then begin
      (* (deleted or changed across the first line: all again, from beg's line) *)
      mark s false; clear_from s 0;
      s.first <- validate s.text (min beg s.text.len);
      s.lines <- lines_from s (Texts.open_reader s.text s.first) 0
    end
    else begin
      let rec find k org (lines : line list) =
        match lines with
        | l :: rest -> if beg < org + l.chars then Some (k, org, l) else find (k + 1) (org + l.chars) rest
        | [] -> None
      in
      match find 0 s.first s.lines with
      | None -> ()
      | Some (k, org, l) ->
          let r = Texts.open_reader s.text beg in
          let rec has_cr i = i < n && (Texts.read r = cr || has_cr (i + 1)) in
          let alone = match op with Insert -> not (has_cr 0) | Delete -> end_ <= org + l.chars - 1 | _ -> false in
          let before = List.filteri (fun i _ -> i < k) s.lines and after = List.filteri (fun i _ -> i > k) s.lines in
          if alone then begin
            repl_const s s.bg (s.f.x + s.left) (s.f.y + base s k - descent) (s.f.w - s.left) lsp Replace;
            s.lines <- before @ (display_line s (Texts.open_reader s.text org) (s.f.y + base s k) :: after)
          end
          else begin
            clear_from s k;
            s.lines <- before @ lines_from s (Texts.open_reader s.text org) k
          end
    end;
    let h = mark_height s in
    if h <> s.mark_h then begin mark s false; s.mark_h <- h end;
    mark s true
  end;
  set_change_mark s s.text.changed

let notify_display text op beg end_ = Viewers.broadcast (Update (op, text, beg, end_))

(*****************************************************************************)
(* The keyboard, the mouse *)
(*****************************************************************************)

(* a character typed, the caret there: backspace, ctrl-c (copy the
 * selection), ctrl-v (paste), ctrl-x (cut), or the character in *)
let write (s : t) ch =
  let pos = s.car.pos in
  if ch = bs then begin
    if pos > s.first then begin Texts.delete s.text (pos - 1) pos del_buf; set_caret s (pos - 1) end
  end
  else if ch = '\003' then begin
    if s.has_sel then begin tbuf := Texts.open_buf (); Texts.save s.text s.sel_beg.pos s.sel_end.pos !tbuf end
  end
  else if ch = '\022' then begin
    let b = Texts.open_buf () in
    Texts.copy !tbuf b;
    let n = b.blen in
    Texts.insert s.text pos b; set_caret s (pos + n)
  end
  else if ch = '\024' then begin
    if s.has_sel then begin tbuf := Texts.open_buf (); Texts.delete s.text s.sel_beg.pos s.sel_end.pos !tbuf end
  end
  else if (ch >= ' ' && ch <= del) || ch = cr || ch = tab then begin
    kw.wfnt <- !Oberon.cur_fnt;
    Texts.write kw ch;
    Texts.insert s.text pos kw.buf;
    set_caret s (pos + 1)
  end

let viewer (s : t) = Viewers.this s.f.x s.f.y

(* the command whose name starts at pos, called: its parameters are
 * what follows the name *)
let call (s : t) pos =
  let sc = Texts.open_scanner s.text pos in
  Texts.scan sc;
  match sc.sym with
  | Name name when sc.line = 0 ->
      Oberon.set_par s.f s.text (pos + String.length name);
      if not (Oberon.call name) then begin
        Texts.write_string w ("Call error: " ^ name ^ " command not found"); Texts.write_ln w;
        Texts.append !Oberon.log w.buf
      end
  | _ -> ()

(* the mouse's keys went down at (x, y): in the scroll bar, or in the text *)
let edit (s : t) x y keys =
  let f = s.f in
  let scrolled pos =
    set_change_mark s false; remove_marks s; Oberon.remove_marks f.x f.y f.w f.h;
    show s pos
  in
  if x < f.x + min s.left bar_w then begin
    Oberon.draw_mouse scroll_marker x y;
    if keys = Input.left then begin
      let pos, keysum = track_line s x y in
      if keysum land lnot Input.left = 0 then scrolled pos
    end
    else if keys = Input.middle then begin
      let last = ref y in
      let keysum = keys lor track scroll_marker (fun _ y -> last := y) in
      if keysum <> Input.left lor Input.middle lor Input.right then
        scrolled (if keysum land Input.right <> 0 then 0
                  else if keysum land Input.left <> 0 then s.text.len - 100
                  else (f.y + f.h - !last) * s.text.len / max 1 f.h)
    end
    else if keys = Input.right then begin
      let pos, keysum = track_line s x y in
      if keysum land lnot Input.right = 0 then scrolled ((s.first * 2) - pos - 100)
    end
  end
  else begin
    Oberon.draw_mouse_arrow x y;
    if keys land Input.right <> 0 then begin
      (* select; then with the left key, delete; with the middle one, copy to the caret *)
      let keysum = keys lor track_selection s x y in
      if s.has_sel then
        match Oberon.get_selection () with
        | Some (text, beg, end_, _) when keysum = Input.right lor Input.left ->
            Texts.delete text beg end_ !tbuf;
            Oberon.pass_focus (viewer s); set_caret s beg
        | Some (text, beg, end_, _) when keysum = Input.right lor Input.middle ->
            Option.iter (fun (v : Viewers.viewer) -> Display.send v.frame (Copy_over (text, beg, end_))) !Oberon.focus_viewer
        | _ -> ()
    end
    else if keys land Input.middle <> 0 then begin
      (* a command's name *)
      let pos, keysum = track_word s x y in
      if keysum land Input.right = 0 then call s pos
    end
    else if keys land Input.left <> 0 then begin
      (* the caret; then with the middle key, the selection copied here;
       * with the right one, the selection given the looks at the caret *)
      Oberon.pass_focus (viewer s);
      let keysum = keys lor track_caret s x y in
      let pos = s.car.pos in
      if keysum = Input.left lor Input.middle then begin
        match Oberon.get_selection () with
        | Some (text, beg, end_, _) ->
            tbuf := Texts.open_buf ();
            Texts.save text beg end_ !tbuf;
            let b = Texts.open_buf () in
            Texts.copy !tbuf b;
            Texts.insert s.text pos b;
            set_selection s pos (pos + (end_ - beg));
            set_caret s (pos + (end_ - beg))
        | None ->
            let b = Texts.open_buf () in
            Texts.copy !tbuf b;
            let n = b.blen in
            Texts.insert s.text pos b; set_caret s (pos + n)
      end
      else if keysum = Input.left lor Input.right then
        Option.iter (fun (text, beg, end_, _) -> Texts.change_looks text beg end_ (Texts.attributes s.text pos)) (Oberon.get_selection ())
    end
  end

(*****************************************************************************)
(* The messages *)
(*****************************************************************************)

(* the viewer changed the frame's rectangle (MenuViewers): what is
 * shown moved up by dy first, or after *)
let modify (s : t) extending dy y =
  let f = s.f in
  mark s false; remove_marks s; set_change_mark s false;
  if extending then begin
    if dy > 0 then begin Display.copy_block f.x f.y f.w f.h f.x (f.y + dy); f.y <- f.y + dy end;
    extend s y
  end
  else begin
    reduce s (y + dy);
    if dy > 0 then begin Display.copy_block f.x f.y f.w f.h f.x y; f.y <- y end
  end;
  if f.h > 0 then begin mark s true; set_change_mark s s.text.changed end

(* a frame as s, on the same text (set below: it makes a frame, whose handler is this) *)
let copy_of : (t -> Display.frame) ref = ref (fun (s : t) -> s.f)

let handle (s : t) (m : Display.msg) =
  match m with
  | Oberon.Track (keys, x, y) -> if keys = 0 then Oberon.draw_mouse_arrow x y else edit s x y keys
  | Oberon.Consume ch -> if s.has_car then write s ch
  | Oberon.Defocus -> remove_caret s
  | Oberon.Neutralize -> remove_marks s
  | Oberon.Selection sel ->
      if s.has_sel then begin
        match sel.text with
        | Some text when text == s.text ->
            if s.sel_beg.pos < sel.beg then sel.beg <- s.sel_beg.pos;
            if s.time > sel.time then begin sel.end_ <- s.sel_end.pos; sel.time <- s.time end
        | _ ->
            if s.time > sel.time then begin
              sel.text <- Some s.text; sel.beg <- s.sel_beg.pos; sel.end_ <- s.sel_end.pos; sel.time <- s.time
            end
      end
  | MenuViewers.Extend (dy, y, _) -> modify s true dy y
  | MenuViewers.Reduce (dy, y, _) -> modify s false dy y
  | Copy_over (text, beg, end_) ->
      if s.has_car then begin
        let b = Texts.open_buf () and pos = s.car.pos in
        Texts.save text beg end_ b;
        Texts.insert s.text pos b;
        set_caret s (pos + (end_ - beg))
      end
  | Update (op, text, beg, end_) -> if text == s.text then update s op beg end_
  | Identify a -> a.it <- Some s
  | Oberon.Copy c -> c.copied <- Some (!copy_of s)
  | _ -> ()

(*****************************************************************************)
(* Making them *)
(*****************************************************************************)

let open_ text first (bg : Display.color) left top bot : Display.frame =
  let f = Display.frame (fun _ _ -> ()) in
  let s = { f; text; first; bg; left; top; bot; lines = []; mark_h = 0; has_mark = false;
            has_car = false; car = nowhere; has_sel = false; sel_beg = nowhere; sel_end = nowhere; time = 0 } in
  f.handle <- (fun _ m -> handle s m);
  f

let () = copy_of := (fun (s : t) -> open_ s.text s.first s.bg s.left s.top s.bot)

let text name =
  let t = Texts.open_ name in
  t.notify <- notify_display;
  t

let new_menu name commands =
  let t = text "" in
  Texts.write_string w (name ^ " | " ^ commands);
  Texts.append t w.buf;
  t.changed <- false;
  open_ t 0 White (left / 4) 0 0

let new_text text pos = open_ text pos Black left top bot
