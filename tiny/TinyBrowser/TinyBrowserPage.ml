(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyBrowserPage.mli *)
open TinyBrowserText
open TinyBrowserTokens
open TinyBrowserLines

(*****************************************************************************)
(* The tags *)
(*****************************************************************************)

(* A picture of the page: where it is, the size it is shown at in
 * pixels, its alternative text, and how far it has come: -1 not asked
 * yet, -3 asked, -2 not to be had, or the rows of it received. *)
type picture = {
  pc_src : string; pc_w : int; pc_h : int; pc_alt : string;
  mutable pc_got : int }

(* An open element. Besides its tag, it records how its text should be
 * shown, combining what it says with what its parents say, so the top
 * of the stack alone tells how to show the next text. *)
type elem = {
  tag : string;
  face : int;                 (* the look of its text: bold, emph, code *)
  href : string;
  hide : bool;
  pre : bool;
  margin : int;               (* the column where its lines start *)
  mutable count : int;        (* the next number, for an <ol> *)
}

type page = {
  reader : reader;
  page_flow : flow;
  mutable stack : elem list;
  mutable tables : table list;  (* the open table, if any (at most one: see
                                 * depth) *)
  mutable space : bool;         (* whether a space was read since the last word *)
  mutable page_title : string;
  mutable page_base : string;
  mutable page_refresh : string;          (* where a <meta> refresh sends us *)
  mutable anchors : (string * int) list;  (* an element's id, and the line it
                                           * starts at *)
  mutable pictures : picture list;        (* the page's pictures, the last first *)
  mutable npictures : int;
  mutable heading : (string * int * string * bool) list;
    (* a large heading's words, the last first *)
}

let root =
  { tag = ""; face = 0; href = ""; hide = false; pre = false; margin = 0;
    count = 0 }

(* (the reader and the flow made first: tiny-ml computes a record's
 * fields in tiny-machine's 11 registers) *)
let create width =
  let reader = { tail = ""; raw = "" } and page_flow = flow width in
  { reader = reader; page_flow = page_flow; stack = [ root ]; tables = [];
    space = false; page_title = ""; page_base = ""; page_refresh = "";
    anchors = [];
    pictures = []; npictures = 0; heading = [] }

let top p = match p.stack with e :: _ -> e | [] -> root

(* The table of tags. Each tag has some of these bits:
 *  - void: the element has no end tag (like <br>);
 *  - block: it ends the current line before and after it;
 *  - spaced: it also wants a blank line before and after it;
 *  - hidden: its text is not shown;
 *  - deeper: it indents its lines.
 * The look of its text (bold, emph, code, big, under) is in the bits
 * above those, multiplied by 32. *)
let void = 1
let block = 2
let spaced = 4
let hidden = 8
let deeper = 16
let kinds = [
  "a", 0; "address", block; "area", void; "article", block; "aside", block;
  "b", bold * 32; "base", void; "blockquote", block + spaced + deeper;
  "body", block; "br", void; "button", hidden;
  "caption", block; "center", block; "code", code * 32; "col", void;
  "dd", block + deeper; "dfn", emph * 32; "div", block; "dl", block + spaced;
  "dt", block + bold * 32;
  "em", emph * 32; "embed", void;
  "figcaption", block; "figure", block + spaced; "footer", block;
  "h1", block + spaced + (bold + big) * 32;
  "h2", block + spaced + (bold + big) * 32; "h3", block + spaced + bold * 32;
  "h4", block + spaced + bold * 32; "h5", block + spaced + bold * 32;
  "h6", block + spaced + bold * 32;
  "head", hidden; "header", block; "hr", void; "html", block;
  "i", emph * 32; "img", void; "input", void + hidden; "ins", under * 32;
  "kbd", code * 32; "li", block; "link", void; "main", block; "math", hidden;
  "meta", void; "nav", block; "noscript", hidden;
  "ol", block + deeper; "p", block + spaced; "param", void;
  "pre", block + spaced + code * 32;
  "samp", code * 32; "script", hidden; "section", block; "select", hidden;
  "source", void; "strong", bold * 32;
  "style", hidden; "svg", hidden;
  "table", block; "td", block; "template", hidden; "textarea", hidden;
  "th", block + bold * 32; "title", hidden;
  "tr", block; "tt", code * 32; "u", under * 32; "ul", block + deeper;
  "var", emph * 32; "wbr", void ]

(* A tag is looked up only among the tags with the same first letter,
 * because in tiny-ml comparing two strings is a call to the runtime. *)
let by_letter =
  let a = Array.make 26 [] in
  List.iter (fun (name, k) ->
    let i = Char.code name.[0] - 97 in a.(i) <- (name, k) :: a.(i)) kinds;
  a
let kind tag =
  let i = if tag = "" then -1 else Char.code tag.[0] - 97 in
  if i < 0 || i >= 26 then 0
  else match List.assoc_opt tag by_letter.(i) with Some k -> k | None -> 0
let is k bit = k land bit <> 0
(* The classes Wikipedia uses for parts that are not worth showing on a
 * small screen (navigation boxes, edit links, ...). *)
let hidden_classes =
  [ "navbox"; "noprint"; "metadata"; "mw-editsection"; "mw-empty-elt";
    "sistersitebox"; "mw-jump-link" ]

let attr attrs a = match List.assoc_opt a attrs with Some v -> v | None -> ""

let hides k attrs =
  is k hidden
  || (let cl = attr attrs "class" in
      cl <> "" && List.exists (has_class cl) hidden_classes)
  || (let st = attr attrs "style" in
      find st "display:none" 0 >= 0 || find st "display: none" 0 >= 0)

(* the line's end a table's cell waits for, put in before what comes *)
let unbreak (t : table) c =
  if t.broken > 0 then begin c.items <- Break :: c.items; t.broken <- 0 end

(* Sends a word to the current cell if a table is open (large text is
 * not, there), to the large heading being made, or to the page's flow. *)
let emit p text =
  let e = top p in
  if not e.hide then begin
    (match p.tables with
     | t :: _ ->
       (match t.cell with
        | Some c ->
          unbreak t c;
          c.items <-
            Word (text, e.face land lnot big, e.href, p.space) :: c.items
        | None -> ())
     | [] ->
       if e.face land big <> 0 then
         p.heading <- (text, e.face, e.href, p.space) :: p.heading
       else word p.page_flow text e.face e.href p.space);
    p.space <- false
  end

(* Ends the current line. *)
let break p =
  (match p.tables with
   | t :: _ ->
     (match t.cell with
      | Some c ->
        (match c.items with
         | Break :: _ | [] -> ()
         | _ -> t.broken <- max t.broken 1)
      | None -> ())
   | [] -> end_line p.page_flow);
  p.space <- false

let paragraph p = break p; if p.tables = [] then p.page_flow.blank <- true

let text p s =
  let e = top p in
  if e.tag = "title" then p.page_title <- p.page_title ^ s
  else if e.hide then ()
  else if e.pre && p.tables = [] then begin
    let f = p.page_flow in
    let pieces = String.split_on_char '\n' s in
    List.iteri (fun i piece ->
      if i > 0 then
        (if f.made = [] then push f { runs = []; rule = false }
         else end_line f);
      verbatim f piece e.face e.href) pieces
  end
  else begin
    let n = String.length s in
    let i = ref 0 in
    while !i < n do
      if is_space s.[!i] then begin p.space <- true; incr i end
      else begin
        let j = ref !i in
        while !j < n && not (is_space s.[!j]) do incr j done;
        emit p (String.sub s !i (!j - !i));
        i := !j
      end
    done
  end

let rule p =
  if p.tables = [] then begin
    end_line p.page_flow; push p.page_flow { runs = []; rule = true }
  end

(* A large heading (<h1>, <h2>): its words laid out at half the width,
 * each of its lines two of the page's, its top half and its bottom half
 * (the same runs, their pic -2), so that the page is still rows of 16
 * pixels, each drawn on its own. *)
let lay_heading p =
  let f = p.page_flow in
  let g = flow (max 1 ((f.width - f.left) / 2)) in
  List.iter (fun (text, look, link, sp) -> word g text look link sp)
    (List.rev p.heading);
  end_line g;
  p.heading <- [];
  end_line f;
  List.iter (fun (l : line) ->
    let runs = List.map (fun (r : run) ->
      { col = f.left + (2 * r.col); text = r.text; look = r.look;
        link = r.link; pic = -1 }) l.runs in
    push f { runs = runs; rule = false };
    push f { runs = List.map (fun (r : run) ->
               { col = r.col; text = r.text; look = r.look; link = r.link;
                 pic = -2 }) runs;
             rule = false })
    (List.rev g.out)

(* The pixels the pictures of a page may have in all: they are images of
 * the kernel's, which has 2 MB for them, the windows' included. *)
let picture_room = 1048576

(* A picture: a box of the size the page says (its width and height
 * attributes), smaller if it is wider than the room it has, kept in the
 * page's pictures and drawn when its pixels come. The text never moves
 * when they do: its place is known before the picture is. Small icons
 * (under 24 pixels) are left out. Wikipedia shows math as a picture
 * whose alternative text is the TeX source, which we show instead. *)
let picture p attrs =
  let alt = attr attrs "alt" and cl = attr attrs "class"
  and src = attr attrs "src" in
  let w = number (attr attrs "width") and h = number (attr attrs "height") in
  if has_class cl "mwe-math-fallback-image-inline"
     || has_class cl "mwe-math-fallback-image-display" then begin
    let pre = "{\\displaystyle " in
    let n = String.length alt and m = String.length pre in
    (* (as text, so that a long formula wraps at its spaces) *)
    text p (if n > m + 1 && String.sub alt 0 m = pre
            then String.sub alt m (n - m - 1) else alt)
  end
  else if (w >= 24 || h >= 24) && w > 0 && h > 0 && src <> "" then begin
    let f = p.page_flow in
    let room =
      8 * (if p.tables = [] then f.width - f.left else f.width / 2) in
    let w, h = if w > room then room, max 1 (h * room / w) else w, h in
    let used =
      List.fold_left (fun n (pc : picture) -> n + (pc.pc_w * pc.pc_h)) 0
        p.pictures in
    if used + (w * h) > picture_room then
      emit p ("[" ^ (if alt = "" then "picture" else alt) ^ "]")
    else begin
      let id = p.npictures in
      p.pictures <-
        { pc_src = src; pc_w = w; pc_h = h; pc_alt = alt; pc_got = -1 }
        :: p.pictures;
      p.npictures <- id + 1;
      let cols = (w + 7) / 8 and rows = (h + 15) / 16 and link = (top p).href in
      match p.tables with
      | t :: _ ->
        (match t.cell with
         | Some c ->
           unbreak t c;
           c.items <- Pic (id, cols, rows, link) :: Break :: c.items
         | None -> ())
      | [] -> picture_block f id rows link
    end
  end

(* Some elements close implicitly when another one opens: a paragraph
 * when any block starts, a list item when the next one starts, a cell
 * when the next one starts. *)
let implied p tag k =
  let close_to names stop =
    let rec find = function
      | [] -> false
      | (e : elem) :: rest ->
        if List.mem e.tag names then true
        else if List.mem e.tag stop then false
        else find rest in
    if find p.stack then begin
      let rec pop = function
        | (e : elem) :: rest when not (List.mem e.tag names) -> pop rest
        | _ :: rest -> rest
        | [] -> [] in
      p.stack <- pop p.stack
    end in
  if is k block then begin
    (match tag with
     | "li" -> close_to [ "li" ] [ "ul"; "ol" ]
     | "dt" | "dd" -> close_to [ "dt"; "dd" ] [ "dl" ]
     | "tr" -> close_to [ "tr" ] [ "table" ]
     | "td" | "th" -> close_to [ "td"; "th" ] [ "tr"; "table" ]
     | _ -> ());
    if (top p).tag = "p" then
      p.stack <- (match p.stack with _ :: rest -> rest | [] -> [])
  end

(* Where <meta http-equiv="refresh" content="0; url=x"> sends us: x,
 * when the wait is 0 (a page that reloads itself every few minutes is
 * not followed). A search's results link through such a page. *)
let meta_refresh attrs =
  (* (not refresh, the page's below: tiny-ml exports both names) *)
  let c = attr attrs "content" in
  match String.index_opt c ';' with
  | Some i
    when String.lowercase_ascii (attr attrs "http-equiv") = "refresh"
         && number (String.trim (String.sub c 0 i)) = 0 ->
      let u = String.trim (String.sub c (i + 1) (String.length c - i - 1)) in
      let u =
        if String.length u > 4
           && String.lowercase_ascii (String.sub u 0 4) = "url="
        then String.sub u 4 (String.length u - 4) else u in
      let n = String.length u in
      if n >= 2 && (u.[0] = '\'' || u.[0] = '"') then String.sub u 1 (n - 2)
      else u
  | _ -> ""

(* A cell of a table inside a cell: the outer table lays out its cells,
 * the inner one's are a space and its rows lines. An empty block in
 * such a cell (Hacker News' vote arrow) is no line's end. *)
let inner_cell p tag =
  (tag = "td" || tag = "th")
  && (match p.tables with t :: _ -> t.depth > 0 | [] -> false)
let cell_space p =
  (match p.tables with t :: _ when t.broken = 1 -> t.broken <- 0 | _ -> ());
  p.space <- true

let open_tag p tag k attrs =
  implied p tag k;
  let e = top p in
  let hide = e.hide || hides k attrs in
  (* (in the <head>, or a <noscript>, which are hidden) *)
  if tag = "meta" && p.page_refresh = "" then p.page_refresh <- meta_refresh attrs;
  (* An element with an id is a place a link can go to (#History,
   * #cite_note-2): the line it starts at is kept. Parsoid gives nearly
   * every element an id of its own, which starts with mw, and no link
   * names those. *)
  let id = attr attrs "id" in
  if id <> "" && not hide
     && not (String.length id > 1 && id.[0] = 'm' && id.[1] = 'w') then
    p.anchors <-
      (id, p.page_flow.nlines
           + (if p.page_flow.made <> [] || p.page_flow.blank then 1 else 0))
      :: p.anchors;
  (* Inside a table, a <tr> starts a new row and a <td> or <th> a new
   * cell, whose words are kept until the end of the table. *)
  if is k block then
    (match p.tables, tag with
     | [], "table" when not hide ->
         end_line p.page_flow;
         p.tables <-
           [ { rows = []; row = []; cell = None; depth = 0; broken = 0 } ]
     | t :: _, "table" when not hide -> t.depth <- t.depth + 1; break p
     | t :: _, "tr" when t.depth = 0 && not hide ->
         if t.row <> [] then t.rows <- t.row :: t.rows;
         t.row <- []; t.cell <- None; t.broken <- 0
     | t :: _, ("td" | "th" | "caption") when t.depth = 0 && not hide ->
         let span =
           if tag = "caption" then 1000
           else max 1 (number (attr attrs "colspan")) in
         let c =
           { items = []; span = span; head = tag = "th" || tag = "caption" } in
         if tag = "caption" then begin
           t.rows <- [ c ] :: t.rows; t.cell <- Some c
         end
         else begin t.row <- c :: t.row; t.cell <- Some c end;
         t.broken <- 0; p.space <- false
     | t :: _, ("tr" | "td" | "th") when not hide ->
         if tag = "tr" then begin
           break p; if t.broken = 1 then t.broken <- 2
         end
         else cell_space p
     | _ -> ());
  if not hide then begin
    if is k spaced then paragraph p
    else if is k block && not (inner_cell p tag) then break p;
    if is k void then
      match tag with
      | "br" ->
        if p.tables = [] && p.page_flow.made = [] then
          push p.page_flow { runs = []; rule = false }
        else break p
      | "hr" -> rule p
      | "img" -> picture p attrs
      | "base" -> if p.page_base = "" then p.page_base <- attr attrs "href"
      | _ -> ()
  end;
  if not (is k void) then begin
    let face = e.face lor (k / 32) in
    let href =
      if tag = "a" && attr attrs "href" <> "" then attr attrs "href"
      else e.href in
    let margin =
      if p.tables = [] && is k deeper then
        min (e.margin + 3) (p.page_flow.width / 2)
      else e.margin in
    let pre = e.pre || (is k spaced && is k (code * 32)) in
    let el =
      { tag = tag; face = face; href = href; hide = hide; pre = pre;
        margin = margin; count = max 1 (number (attr attrs "start")) } in
    p.stack <- el :: p.stack;
    if not hide then begin
      p.page_flow.left <- margin;
      if is k block && tag = "li" then begin
        (* The bullet, or the number of an <ol>, goes in the margin. *)
        let mark = match p.stack with
          | _ :: (l : elem) :: _ when l.tag = "ol" ->
            let n = l.count in l.count <- n + 1; string_of_int n ^ "."
          | _ -> "*" in
        match p.tables with
        | [] ->
            let f = p.page_flow in
            f.at <- max 0 (margin - String.length mark - 1);
            f.made <-
              [ { col = f.at; text = mark; look = 0; link = ""; pic = -1 } ];
            (* If the number is wider than the margin, the item's text
             * starts after it. *)
            f.at <- max margin (f.at + String.length mark + 1)
        | _ -> emit p mark; p.space <- true
      end
    end
  end

let close_tag p tag k =
  let rec opened = function
    | [] -> None
    | (e : elem) :: rest -> if e.tag = tag then Some e else opened rest in
  match (if is k void then None else opened p.stack) with
  | None -> ()
  | Some was ->
      let rec pop = function
        | (e : elem) :: rest when e.tag <> tag -> pop rest
        | _ :: rest -> rest
        | [] -> [] in
      p.stack <- pop p.stack;
      let e = top p in
      if not was.hide then begin
        p.page_flow.left <- e.margin;
        if is k block then
          (match p.tables, tag with
           | t :: rest, "table" ->
               if t.depth > 0 then begin t.depth <- t.depth - 1; break p end
               else begin
                 if t.row <> [] then t.rows <- t.row :: t.rows;
                 p.tables <- rest;
                 lay_table p.page_flow t
               end
           | t :: _, ("td" | "th" | "caption") when t.depth = 0 ->
               t.cell <- None
           | _ -> ());
        (* (a heading is laid out at its end, not at a <span>'s in it) *)
        if p.heading <> [] && e.face land big = 0 then lay_heading p;
        if is k spaced && tag = "h2" && p.tables = [] then rule p;
        if is k spaced then paragraph p
        else if inner_cell p tag then cell_space p
        else if is k block then break p
      end

let token p = function
  | Text s -> text p s
  | Open (tag, attrs) -> open_tag p tag (kind tag) attrs
  | Close tag -> close_tag p tag (kind tag)

let feed p chunk = List.iter (token p) (tokens p.reader chunk false)

let finish p =
  List.iter (token p) (tokens p.reader "" true);
  (match p.tables with
   | t :: _ ->
     (if t.row <> [] then t.rows <- t.row :: t.rows);
     p.tables <- [];
     lay_table p.page_flow t
   | [] -> ());
  if p.heading <> [] then lay_heading p;
  end_line p.page_flow

let title p = p.page_title
let base p = p.page_base
let refresh p = p.page_refresh
let anchor p id = List.assoc_opt id p.anchors
let pictures p = p.npictures
let picture_of p id = List.nth p.pictures (p.npictures - 1 - id)
let count p = p.page_flow.nlines

(* The lines from the a-th to before the b-th, from the top. The lines
 * are kept last first, as they are made; an array of them from the top
 * is made again when lines have come since it was made, so that the
 * lines a scroll asks for are found at once (walking the list from its
 * end each time was a tenth of a page down). *)
let lines_between p a b =
  let f = p.page_flow in
  let n = f.nlines in
  let b = min b n and a = max a 0 in
  if a >= b then []
  else begin
    if f.cached <> n then begin
      let arr = Array.make n { runs = []; rule = false } in
      List.iteri (fun k l -> arr.(n - 1 - k) <- l) f.out;
      f.cache <- arr;
      f.cached <- n
    end;
    let rec take k acc =
      if k < a then acc else take (k - 1) (f.cache.(k) :: acc) in
    take (b - 1) []
  end
