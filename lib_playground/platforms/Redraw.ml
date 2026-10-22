(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Redraw.mli *)

let enabled = ref true
let groups = ref true

let choose (how : string option) : unit =
  match how with Some "all" -> enabled := false | Some "top" -> groups := false | _ -> ()

type box = int * int * int * int

type t = {
  width : int;
  height : int;
  scale : float;
  options : Shape_render_software.options;
  (* the last frame's shapes; None: nothing drawn yet *)
  mutable last : Playground.shape list option;
}

let create ~(width : int) ~(height : int) ~(scale : float) (options : Shape_render_software.options) : t =
  { width; height; scale; options; last = None }

(* A shape's hash, a picture's pixels not read: its place and size.
 * Hashtbl.hash goes through ten numbers and strings of a value, and a
 * Bitmap's tenth is its bytes, a megabyte read whole (mini-doom's
 * 640 by 400 picture: 0.56 ms a hash, four in a frame that changed
 * it). Two pictures at the same place and size have the same hash;
 * [compare] tells them apart, at their first pixel that differs.
 * old: the table's keys the shapes, hashed by Hashtbl.hash *)
let hash (s : Playground.shape) : int =
  match s.form with Bitmap (w, h, _) | Pixels (w, h, _) -> Hashtbl.hash (s.x, s.y, w, h) | _ -> Hashtbl.hash s

(* The shapes of one list that are not in the other, each as many times
 * as it is there more: the others' shapes counted in a table, by what
 * they are (a shape is numbers and strings: compared whole), a hash
 * having those alike. *)
let only_in (these : Playground.shape list) (others : Playground.shape list) : Playground.shape list =
  let counts : (int, Playground.shape * int ref) Hashtbl.t = Hashtbl.create 64 in
  let count (s : Playground.shape) : int ref option =
    Option.map snd
      (List.find_opt (fun ((t, _) : Playground.shape * int ref) -> t == s || compare t s = 0) (Hashtbl.find_all counts (hash s))) in
  List.iter
    (fun (s : Playground.shape) ->
      match count s with Some n -> incr n | None -> Hashtbl.add counts (hash s) (s, ref 1))
    others;
  List.filter
    (fun (s : Playground.shape) ->
      match count s with
      | Some n when !n > 0 -> decr n; false
      | _ -> true)
    these

(* Optimization (Opti.enabled): the shapes two frames start with alike,
 * and end with alike, are in both: left out before the table is made.
 * A page of text is 8,000 shapes, a letter's strokes each, and a sheet
 * dragged over it changes 20: the table of the 8,000 was made twice a
 * frame, 17 ms of a frame whose pixels are 11 (mini-office on Linux,
 * 2026-10-09; the author: "moving around a sheet inside a Word
 * document is really slow"), and of a frame where nothing moved.
 * What is left is the same shapes as many times, in another order. *)
let rec unlike (a : Playground.shape list) (b : Playground.shape list) : Playground.shape list * Playground.shape list =
  match (a, b) with
  (* opti: [x == y] first, the same block of memory, two pointers
   * compared, where [compare] goes through all that is under them: a
   * group of 8,000 letters that mini-office keeps from a frame to the
   * next (the draw platform's show says it at length) *)
  | x :: a', y :: b' when x == y || compare x y = 0 -> unlike a' b'
  | _ -> (a, b)

let middle (a : Playground.shape list) (b : Playground.shape list) : Playground.shape list * Playground.shape list =
  let a, b = unlike a b in
  unlike (List.rev a) (List.rev b)

(* [s] put back in the groups it was found in, the innermost first: the
 * same pixels as there, a shape whose bounds can be asked alone *)
let inside (groups : Playground.shape list) (s : Playground.shape) : Playground.shape =
  List.fold_left (fun (s : Playground.shape) (g : Playground.shape) -> { g with form = Group [ s ] }) s groups

let same_place (a : Playground.shape) (b : Playground.shape) : bool =
  a.x = b.x && a.y = b.y && a.angle = b.angle && a.scale = b.scale && a.alpha = b.alpha

(* more shapes than that changed: most of the picture, drawn whole,
 * their boxes not asked; the shapes left to compare too, not compared
 * (mini-office's paragraph reflowed by a word typed, 1,500 words that
 * moved: their comparing 3.6 s on mini-9pi under QEMU, their bounds a
 * second more, where the whole picture is 90 ms) *)
let many = 64

exception Many

(* Optimization (Opti.enabled): the shapes that differ looked for inside
 * the groups too. A program that draws all in one group (mini-netscape's
 * page) changed that group when one link was lit: its whole box drawn
 * again, 452 letters. Two lists of as many shapes are compared a pair
 * at a time, and two groups at the same place by their members, as the
 * lists at the top are (mini-office's page, a word typed: one more
 * member); other lists as at the top, the shapes whole. *)
let rec differ (groups : Playground.shape list) (was : Playground.shape list) (now : Playground.shape list) :
    Playground.shape list =
  let was, now = middle was now in
  if List.length was + List.length now > many then raise Many
  else if List.length was <> List.length now then List.map (inside groups) (only_in was now @ only_in now was)
  else
    List.concat
      (List.map2
         (fun (a : Playground.shape) (b : Playground.shape) ->
           if a == b || compare a b = 0 then []
           else
             match (a.form, b.form) with
             | Group xs, Group ys when same_place a b -> differ (a :: groups) xs ys
             | _ -> [ inside groups a; inside groups b ])
         was now)

let touch ((a0, b0, a1, b1) : box) ((c0, d0, c1, d1) : box) : bool = a0 < c1 && c0 < a1 && b0 < d1 && d0 < b1
let union ((a0, b0, a1, b1) : box) ((c0, d0, c1, d1) : box) : box = (min a0 c0, min b0 d0, max a1 c1, max b1 d1)
let area ((x0, y0, x1, y1) : box) : int = (x1 - x0) * (y1 - y0)

(* boxes that touch made one, until none does: no pixel drawn twice *)
let rec merge (boxes : box list) : box list =
  match boxes with
  | [] -> []
  | b :: rest ->
      let near, far = List.partition (touch b) rest in
      if near = [] then b :: merge far else merge (List.fold_left union b near :: far)

let whole (t : t) (shapes : Playground.shape list) : (box * Framebuffer.t) list =
  let fb = Framebuffer.create ~width:t.width ~height:t.height in
  Shape_render_software.render ~options:t.options ~scale:t.scale fb shapes;
  [ ((0, 0, t.width, t.height), fb) ]

(* None: all of the picture; else the boxes that changed (none: the
 * same picture) *)
let changed (t : t) (bounds : Playground.shape -> box option) (shapes : Playground.shape list) : box list option =
  let last = t.last in
  t.last <- Some shapes;
  match last with
  | None -> None
  | Some _ when not !enabled -> None
  (* (the list itself again: a view that made nothing new) *)
  | Some old when old == shapes -> Some []
  | Some old ->
      (* old: let changed = only_in old shapes @ only_in shapes old in *)
      let changed =
        if !Opti.enabled && !groups then (try Some (differ [] old shapes) with Many -> None)
        else
          (* old: top-level shapes only *)
          let was, now = if !Opti.enabled then middle old shapes else (old, shapes) in
          Some (only_in was now @ only_in now was) in
      (* (most of the picture: all of it, at once; known at the first
       * shape that is, a game's turning maze, the others' boxes not
       * computed) *)
      let most (n : int) : bool = 2 * n > t.width * t.height in
      let rec boxes_of (shapes : Playground.shape list) (acc : box list) : box list option =
        match shapes with
        | [] -> Some acc
        | s :: rest -> (
            match bounds s with
            | Some b when most (area b) -> None
            | Some b -> boxes_of rest (b :: acc)
            | None -> boxes_of rest acc) in
      match changed with
      | Some changed when List.length changed <= many -> (
          match boxes_of changed [] with
          | None -> None
          | Some boxes ->
              let boxes = merge (List.rev boxes) in
              if most (List.fold_left (fun (n : int) (b : box) -> n + area b) 0 boxes) then None else Some boxes)
      | _ -> None

let frame (t : t) (shapes : Playground.shape list) : (box * Framebuffer.t) list =
  let bounds (s : Playground.shape) : box option =
    Shape_render_software.pixel_bounds ~width:t.width ~height:t.height ~scale:t.scale [ s ] in
  match changed t bounds shapes with
  | None -> whole t shapes
  | Some boxes ->
      List.map
        (fun ((x0, y0, x1, y1) as b : box) ->
          (* (old: a framebuffer of its own, the window's transform
           * moved by (x0, y0): its floats added in another order, a
           * pixel at an edge then another, mini-office's menu bar
           * 153 pixels off; bugs/ix.md) *)
          let fb = Framebuffer.part ~window:(t.width, t.height) ~at:(x0, y0) ~width:(x1 - x0) ~height:(y1 - y0) in
          Shape_render_software.render ~options:t.options ~scale:t.scale fb shapes;
          (b, fb))
        boxes

let paste (picture : Framebuffer.t) (parts : (box * Framebuffer.t) list) : unit =
  List.iter
    (fun (((x0, y0, _, _), fb) : box * Framebuffer.t) ->
      for y = 0 to fb.height - 1 do
        Bytes.blit fb.pixels (4 * y * fb.width) picture.pixels (4 * (((y0 + y) * picture.width) + x0)) (4 * fb.width)
      done)
    parts
