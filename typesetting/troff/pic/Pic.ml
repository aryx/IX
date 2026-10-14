(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Pic.mli *)

open Pic_ast

type point = float * float

(* An object once placed: the box it is in, where a line starts and
 * ends (a box's: its centre), and, of a block, the names in it. *)
type obj = {
  kind : string;
  x0 : float; y0 : float; x1 : float; y1 : float;
  first : point; last : point;
  names : (string * obj) list;
}

type env = {
  vars : (string, float) Hashtbl.t;
  mutable here : point;
  mutable dir : string;
  (* the objects, the last first; those with a name *)
  mutable objs : obj list;
  mutable names : (string * obj) list;
  mutable marks : Doc.mark list;
  words : string -> Doc.inline list;
}

exception Unknown of string

let vector (dir : string) : point = match dir with "up" -> (0., 1.) | "down" -> (0., -1.) | "left" -> (-1., 0.) | _ -> (1., 0.)

let var (e : env) (name : string) : float = match Hashtbl.find_opt e.vars name with Some v -> v | None -> raise (Unknown name)

(* a corner of an object: of the box it is in, but a round one's
 * diagonal corners, which are on it *)
let corner_of (o : obj) (c : corner option) : point =
  let cx = (o.x0 +. o.x1) /. 2. and cy = (o.y0 +. o.y1) /. 2. in
  let rx = (o.x1 -. o.x0) /. 2. and ry = (o.y1 -. o.y0) /. 2. in
  let k = if o.kind = "circle" || o.kind = "ellipse" then 0.7071 else 1. in
  match c with
  | None -> if o.kind = "line" then o.last else (cx, cy)
  | Some "n" -> (cx, o.y1) | Some "s" -> (cx, o.y0) | Some "e" -> (o.x1, cy) | Some "w" -> (o.x0, cy)
  | Some "ne" -> (cx +. (k *. rx), cy +. (k *. ry)) | Some "nw" -> (cx -. (k *. rx), cy +. (k *. ry))
  | Some "se" -> (cx +. (k *. rx), cy -. (k *. ry)) | Some "sw" -> (cx -. (k *. rx), cy -. (k *. ry))
  | Some "start" -> o.first | Some "end" -> o.last
  | Some _ -> (cx, cy)

let rec place (e : env) (p : place) : point =
  match p with
  | Here -> e.here
  | Named (path, c) ->
      let rec find (names : (string * obj) list) (path : string list) : obj =
        match path with
        | [] -> raise (Unknown "a place")
        | [ name ] -> (match List.assoc_opt name names with Some o -> o | None -> raise (Unknown name))
        | name :: rest -> (match List.assoc_opt name names with Some o -> find o.names rest | None -> raise (Unknown name)) in
      corner_of (find e.names path) c
  | Nth (n, kind, c) ->
      let kind = if kind = "arrow" || kind = "spline" then "line" else kind in
      let same = List.filter (fun (o : obj) -> o.kind = kind) e.objs in
      let o = if n < 0 then List.nth_opt same 0 else List.nth_opt (List.rev same) (n - 1) in
      (match o with Some o -> corner_of o c | None -> raise (Unknown ("no " ^ kind)))

and expr (e : env) (x : expr) : float =
  match x with
  | Num v -> v
  | Var name -> var e name
  | Neg a -> -.expr e a
  | Coord (p, axis) -> let x, y = place e p in if axis = "y" then y else x
  | Bin (op, a, b) ->
      let a = expr e a and b = expr e b in
      (match op with '+' -> a +. b | '-' -> a -. b | '*' -> a *. b | _ -> if b = 0. then 0. else a /. b)


and position (e : env) (p : position) : point =
  match p with
  | Xy (x, y) -> (expr e x, expr e y)
  | Place pl -> place e pl
  | Shift (p, dx, dy) -> let x, y = position e p in (x +. expr e dx, y +. expr e dy)
  | Between (t, a, b) ->
      let t = expr e t and ax, ay = position e a and bx, by = position e b in
      (ax +. (t *. (bx -. ax)), ay +. (t *. (by -. ay)))

let rec moved (dx : float) (dy : float) (o : obj) : obj =
  { o with x0 = o.x0 +. dx; x1 = o.x1 +. dx; y0 = o.y0 +. dy; y1 = o.y1 +. dy; first = (fst o.first +. dx, snd o.first +. dy); last = (fst o.last +. dx, snd o.last +. dy);
    names = List.map (fun (n, x) -> (n, moved dx dy x)) o.names }

let stroke (e : env) (points : point list) = e.marks <- Doc.Stroke points :: e.marks

(* an arrow's head at b, coming from a *)
let head (e : env) ((ax, ay) : point) ((bx, by) : point) =
  let dx = bx -. ax and dy = by -. ay in
  let len = Float.sqrt ((dx *. dx) +. (dy *. dy)) in
  if len > 0. then begin
    let ux = dx /. len and uy = dy /. len in
    let h = var e "arrowht" and w = var e "arrowwid" /. 2. in
    let px = bx -. (h *. ux) and py = by -. (h *. uy) in
    stroke e [ (px -. (w *. uy), py +. (w *. ux)); (bx, by); (px +. (w *. uy), py -. (w *. ux)) ]
  end

(* a circle or an ellipse, as the lines that look like it *)
let round (cx : float) (cy : float) (rx : float) (ry : float) : point list =
  List.init 33 (fun k -> let a = float_of_int k *. 6.283185307 /. 32. in (cx +. (rx *. Float.cos a), cy +. (ry *. Float.sin a)))

(* a spline: a curve that starts and ends at its first and last points
 * and is drawn towards the others (between the middles of each two) *)
let curve (points : point list) : point list =
  match points with
  | [] | [ _ ] | [ _; _ ] -> points
  | first :: _ ->
      let a = Array.of_list points in
      let n = Array.length a in
      let mid i = ((fst a.(i) +. fst a.(i + 1)) /. 2., (snd a.(i) +. snd a.(i + 1)) /. 2.) in
      let out = ref [ first ] in
      for i = 1 to n - 2 do
        let p0 = if i = 1 then a.(0) else mid (i - 1) and p1 = a.(i) and p2 = if i = n - 2 then a.(n - 1) else mid i in
        for k = 1 to 8 do
          let t = float_of_int k /. 8. in
          let u = 1. -. t in
          out := ((u *. u *. fst p0) +. (2. *. u *. t *. fst p1) +. (t *. t *. fst p2), (u *. u *. snd p0) +. (2. *. u *. t *. snd p1) +. (t *. t *. snd p2)) :: !out
        done
      done;
      List.rev !out

(* the texts said of an object, one under the other round a point *)
let texts (e : env) ((x, y) : point) (attrs : attr list) =
  let rec strings (l : attr list) (acc : (string * string list) list) =
    match l with
    | Str s :: rest -> strings rest ((s, []) :: acc)
    | Just j :: rest -> (match acc with (s, js) :: more -> strings rest ((s, j :: js) :: more) | [] -> strings rest acc)
    | _ :: rest -> strings rest acc
    | [] -> List.rev acc in
  let all = strings attrs [] in
  let n = List.length all and line = var e "textht" in
  List.iteri (fun i (s, js) ->
    let dy = (((float_of_int (n - 1)) /. 2.) -. float_of_int i) *. line in
    let dy = if List.mem "above" js then dy +. (line /. 2.) else if List.mem "below" js then dy -. (line /. 2.) else dy in
    let side = if List.mem "ljust" js then -1 else if List.mem "rjust" js then 1 else 0 in
    if s <> "" then e.marks <- Doc.Label (x, y +. dy, side, e.words s) :: e.marks) all

let add (e : env) (label : string option) (o : obj) =
  e.objs <- o :: e.objs;
  match label with Some name -> e.names <- (name, o) :: List.remove_assoc name e.names | None -> ()

(* the first of an object's attributes that is of a kind *)
let find (attrs : attr list) (f : attr -> 'a option) : 'a option = List.find_map f attrs

let rec statement (e : env) (s : statement) =
  match s with
  | Direction d -> e.dir <- d
  | Assign ("scale", x) ->
      (* the sizes that were inches are now so many of the new unit *)
      let v = expr e x and old = var e "scale" in
      List.iter (fun name -> Hashtbl.replace e.vars name (var e name *. v /. old))
        [ "boxwid"; "boxht"; "circlerad"; "ellipsewid"; "ellipseht"; "linewid"; "lineht"; "movewid"; "moveht"; "arcrad"; "arrowht"; "arrowwid"; "textht" ];
      Hashtbl.replace e.vars "scale" v
  | Assign (name, x) -> Hashtbl.replace e.vars name (expr e x)
  | Object (label, kind, attrs) ->
      let has (a : attr) = List.mem a attrs in
      let invis = has Invis in
      let dx, dy = vector e.dir in
      (* a box's place: by a corner said at a place, or where the one
       * before ended, its side towards it there *)
      let boxed (name : string) (w : float) (h : float) : obj =
        let cx, cy =
          match find attrs (fun a -> match a with At p -> Some p | _ -> None) with
          | Some p ->
              let x, y = position e p in
              let c = find attrs (fun a -> match a with With c -> Some c | _ -> None) in
              let probe = { kind = name; x0 = -.w /. 2.; x1 = w /. 2.; y0 = -.h /. 2.; y1 = h /. 2.; first = (0., 0.); last = (0., 0.); names = [] } in
              let ox, oy = match c with Some _ -> corner_of probe c | None -> (0., 0.) in
              (x -. ox, y -. oy)
          | None -> (fst e.here +. (dx *. w /. 2.), snd e.here +. (dy *. h /. 2.)) in
        let o = { kind = name; x0 = cx -. (w /. 2.); x1 = cx +. (w /. 2.); y0 = cy -. (h /. 2.); y1 = cy +. (h /. 2.); first = (cx, cy); last = (cx, cy); names = [] } in
        e.here <- (cx +. (dx *. w /. 2.), cy +. (dy *. h /. 2.));
        o in
      let size (f : attr -> expr option) (default : string) : float = match find attrs f with Some x -> expr e x | None -> var e default in
      (match kind with
       | Box ->
           let o = boxed "box" (size (fun a -> match a with Wid x -> Some x | _ -> None) "boxwid") (size (fun a -> match a with Ht x -> Some x | _ -> None) "boxht") in
           if not invis then stroke e [ (o.x0, o.y0); (o.x1, o.y0); (o.x1, o.y1); (o.x0, o.y1); (o.x0, o.y0) ];
           texts e o.first attrs; add e label o
       | Circle | Ellipse ->
           let name = if kind = Circle then "circle" else "ellipse" in
           let w, h =
             if kind = Circle then begin let r = size (fun a -> match a with Rad x -> Some x | _ -> None) "circlerad" in (2. *. r, 2. *. r) end
             else (size (fun a -> match a with Wid x -> Some x | _ -> None) "ellipsewid", size (fun a -> match a with Ht x -> Some x | _ -> None) "ellipseht") in
           let o = boxed name w h in
           if not invis then stroke e (round (fst o.first) (snd o.first) (w /. 2.) (h /. 2.));
           texts e o.first attrs; add e label o
       | Text ->
           let at = match find attrs (fun a -> match a with At p -> Some p | _ -> None) with Some p -> position e p | None -> e.here in
           texts e at attrs;
           add e label { kind = "text"; x0 = fst at; x1 = fst at; y0 = snd at; y1 = snd at; first = at; last = at; names = [] }
       | Block inner ->
           let sub = { e with here = (0., 0.); dir = "right"; objs = []; names = []; marks = [] } in
           List.iter (statement sub) inner;
           let x0, y0, x1, y1 = bounds sub in
           let o = boxed "block" (x1 -. x0) (y1 -. y0) in
           (* (with (0,0) at a place: the block's own origin there) *)
           let mx, my =
             if has (With "origin") then (match find attrs (fun a -> match a with At p -> Some p | _ -> None) with Some p -> position e p | None -> (0., 0.))
             else (o.x0 -. x0, o.y0 -. y0) in
           let o = if has (With "origin") then { o with x0 = x0 +. mx; x1 = x1 +. mx; y0 = y0 +. my; y1 = y1 +. my } else o in
           e.marks <- List.map (fun (m : Doc.mark) ->
               match m with
               | Doc.Stroke ps -> Doc.Stroke (List.map (fun (x, y) -> (x +. mx, y +. my)) ps)
               | Doc.Label (x, y, side, t) -> Doc.Label (x +. mx, y +. my, side, t)
               | Doc.Image (x, y, w, h, name, img) -> Doc.Image (x +. mx, y +. my, w, h, name, img)) sub.marks @ e.marks;
           add e label { o with names = List.map (fun (n, x) -> (n, moved mx my x)) sub.names }
       | Line | Arrow | Spline | Move ->
           let start = match find attrs (fun a -> match a with From p -> Some p | _ -> None) with Some p -> position e p | None -> e.here in
           let wid = if kind = Move then "movewid" else "linewid" and ht = if kind = Move then "moveht" else "lineht" in
           (* the points: each "then" ends a move made of what was said
            * since the one before; "to" is a point of its own *)
           let points = ref [ start ] and cur = ref start and pending = ref None in
           let flush () = match !pending with Some (px, py) -> cur := (fst !cur +. px, snd !cur +. py); points := !cur :: !points; pending := None | None -> () in
           let go (d : string) (far : float) =
             let vx, vy = vector d and px, py = match !pending with Some p -> p | None -> (0., 0.) in
             pending := Some (px +. (vx *. far), py +. (vy *. far)); e.dir <- d in
           List.iter (fun (a : attr) ->
             match a with
             | Go (d, far) -> go d (match far with Some x -> expr e x | None -> if d = "up" || d = "down" then var e ht else var e wid)
             | Dist x -> go e.dir (expr e x)
             | Then -> flush ()
             | To p -> flush (); cur := position e p; points := !cur :: !points
             | _ -> ()) attrs;
           flush ();
           if List.length !points = 1 then begin go e.dir (if e.dir = "up" || e.dir = "down" then var e ht else var e wid); flush () end;
           let points = List.rev !points in
           let last = List.nth points (List.length points - 1) in
           if kind <> Move && not invis then begin
             let drawn = if kind = Spline then curve points else points in
             stroke e drawn;
             let at_start, at_end = match find attrs (fun a -> match a with Head (s, t) -> Some (s, t) | _ -> None) with Some h -> h | None -> (false, kind = Arrow) in
             (match List.rev drawn with b :: a :: _ when at_end -> head e a b | _ -> ());
             (match drawn with b :: a :: _ when at_start -> head e a b | _ -> ())
           end;
           let xs = List.map fst points and ys = List.map snd points in
           let o = { kind = "line"; x0 = List.fold_left Float.min (List.hd xs) xs; x1 = List.fold_left Float.max (List.hd xs) xs;
                     y0 = List.fold_left Float.min (List.hd ys) ys; y1 = List.fold_left Float.max (List.hd ys) ys; first = start; last; names = [] } in
           (* (a line's texts are at its middle) *)
           texts e ((fst start +. fst last) /. 2., (snd start +. snd last) /. 2.) attrs;
           e.here <- last;
           if kind <> Move || label <> None then add e label o
       | Arc ->
           let r = size (fun a -> match a with Rad x -> Some x | _ -> None) "arcrad" in
           let cw = has Cw in
           let p1 = match find attrs (fun a -> match a with From p -> Some p | _ -> None) with Some p -> position e p | None -> e.here in
           let p2 =
             match find attrs (fun a -> match a with To p -> Some p | _ -> None) with
             | Some p -> position e p
             (* a quarter of a circle, turning left (right, if cw) *)
             | None ->
                 let tx, ty = if cw then (dy, -.dx) else (-.dy, dx) in
                 (fst p1 +. (r *. (dx +. tx)), snd p1 +. (r *. (dy +. ty))) in
           let mx = (fst p1 +. fst p2) /. 2. and my = (snd p1 +. snd p2) /. 2. in
           let hx = fst p2 -. fst p1 and hy = snd p2 -. snd p1 in
           let half = Float.sqrt ((hx *. hx) +. (hy *. hy)) /. 2. in
           let r = Float.max r half in
           let h = Float.sqrt (Float.max 0. ((r *. r) -. (half *. half))) in
           (* the centre: to the left of the way from p1 to p2 when
            * turning left *)
           let nx = if half = 0. then 0. else -.hy /. (2. *. half) and ny = if half = 0. then 0. else hx /. (2. *. half) in
           let cx, cy = if cw then (mx -. (h *. nx), my -. (h *. ny)) else (mx +. (h *. nx), my +. (h *. ny)) in
           let a1 = Float.atan2 (snd p1 -. cy) (fst p1 -. cx) and a2 = Float.atan2 (snd p2 -. cy) (fst p2 -. cx) in
           let sweep = if cw then (let d = a1 -. a2 in if d <= 0. then d +. 6.283185307 else d) else (let d = a2 -. a1 in if d <= 0. then d +. 6.283185307 else d) in
           let points = List.init 17 (fun k -> let t = float_of_int k /. 16. in let a = if cw then a1 -. (t *. sweep) else a1 +. (t *. sweep) in (cx +. (r *. Float.cos a), cy +. (r *. Float.sin a))) in
           if not invis then begin
             stroke e points;
             let at_start, at_end = match find attrs (fun a -> match a with Head (s, t) -> Some (s, t) | _ -> None) with Some h -> h | None -> (false, false) in
             (match List.rev points with b :: a :: _ when at_end -> head e a b | _ -> ());
             (match points with b :: a :: _ when at_start -> head e a b | _ -> ())
           end;
           let xs = List.map fst points and ys = List.map snd points in
           e.here <- p2;
           (* (turned: the way things go is now across the one it was) *)
           if find attrs (fun a -> match a with To p -> Some p | _ -> None) = None then
             e.dir <- (match (e.dir, cw) with
               | "right", false | "left", true -> "up" | "right", true | "left", false -> "down"
               | "up", false | "down", true -> "left" | _ -> "right");
           add e label { kind = "arc"; x0 = List.fold_left Float.min (List.hd xs) xs; x1 = List.fold_left Float.max (List.hd xs) xs;
                         y0 = List.fold_left Float.min (List.hd ys) ys; y1 = List.fold_left Float.max (List.hd ys) ys; first = p1; last = p2; names = [] })

(* the box that everything drawn is in *)
and bounds (e : env) : float * float * float * float =
  let points = List.concat_map (fun (m : Doc.mark) -> match m with Doc.Stroke ps -> ps | Doc.Label (x, y, _, _) -> [ (x, y) ] | Doc.Image (x, y, w, h, _, _) -> [ (x, y); (x +. w, y +. h) ]) e.marks
               @ List.concat_map (fun (o : obj) -> [ (o.x0, o.y0); (o.x1, o.y1) ]) e.objs in
  match points with
  | [] -> (0., 0., 0., 0.)
  | (x, y) :: rest -> List.fold_left (fun (x0, y0, x1, y1) (px, py) -> (Float.min x0 px, Float.min y0 py, Float.max x1 px, Float.max y1 py)) (x, y, x, y) rest

(* a word of the grammar, to say where a picture stopped being understood *)
let show (t : Pic_parser.token) : string =
  match t with
  | Pic_parser.NUMBER v -> string_of_float v | Pic_parser.STRING s -> "\"" ^ s ^ "\"" | Pic_parser.LABEL s | Pic_parser.VAR s | Pic_parser.PRIM s | Pic_parser.DIR s | Pic_parser.JUST s -> s
  | Pic_parser.CORNER s -> "." ^ s | Pic_parser.EOL -> ";" | Pic_parser.COLON -> ":" | Pic_parser.LBRACK -> "[" | Pic_parser.RBRACK -> "]"
  | Pic_parser.LPAREN -> "(" | Pic_parser.RPAREN -> ")" | Pic_parser.COMMA -> "," | Pic_parser.LT -> "<" | Pic_parser.GT -> ">" | Pic_parser.EQ -> "="
  | Pic_parser.PLUS -> "+" | Pic_parser.MINUS -> "-" | Pic_parser.STAR -> "*" | Pic_parser.SLASH -> "/" | Pic_parser.DOT -> "." | Pic_parser.AT -> "at"
  | Pic_parser.WITH -> "with" | Pic_parser.FROM -> "from" | Pic_parser.TO -> "to" | Pic_parser.EOF -> "the end" | _ -> "?"

let read (load : string -> string option) (width : float) (words : string -> Doc.inline list) (text : string) : (Doc.picture, string) result =
  let vars = Hashtbl.create 32 in
  List.iter (fun (name, v) -> Hashtbl.replace vars name v)
    [ ("scale", 1.); ("boxwid", 0.75); ("boxht", 0.5); ("circlerad", 0.25); ("ellipsewid", 0.75); ("ellipseht", 0.5); ("linewid", 0.5); ("lineht", 0.5);
      ("movewid", 0.5); ("moveht", 0.5); ("arcrad", 0.25); ("arrowht", 0.1); ("arrowwid", 0.05); ("textht", 0.17) ];
  let e = { vars; here = (0., 0.); dir = "right"; objs = []; names = []; marks = []; words } in
  (* the words read last, the last first *)
  let seen = ref [] in
  match
    let tokens = ref (Pic_lexer.tokens load text) in
    let next (_ : Lexing.lexbuf) : Pic_parser.token =
      match !tokens with t :: rest -> tokens := rest; seen := show t :: !seen; t | [] -> Pic_parser.EOF in
    List.iter (statement e) (Pic_parser.picture next (Lexing.from_string ""))
  with
  | exception Parsing.Parse_error -> Error ("at: " ^ String.concat " " (List.rev (List.filteri (fun k _ -> k < 8) !seen)))
  | exception Unknown name -> Error ("no " ^ name)
  | exception Failure why -> Error why
  | () ->
      let x0, y0, x1, y1 = bounds e in
      let scale = var e "scale" in
      let wide = (x1 -. x0) /. scale in
      (* (.PS 3i: that wide, whatever its own width) *)
      let k = (if width > 0. && wide > 0. then width /. wide else 1.) /. scale in
      let at (x, y) = ((x -. x0) *. k, (y -. y0) *. k) in
      let p : Doc.picture = { wide = (x1 -. x0) *. k; high = (y1 -. y0) *. k;
             marks = List.rev_map (fun (m : Doc.mark) ->
               match m with
               | Doc.Stroke ps -> Doc.Stroke (List.map at ps)
               | Doc.Label (x, y, side, t) -> let x, y = at (x, y) in Doc.Label (x, y, side, t)
               | Doc.Image (x, y, w, h, name, img) -> let x, y = at (x, y) in Doc.Image (x, y, w, h, name, img)) e.marks } in
      Ok p
