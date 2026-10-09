(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Redraw.mli *)

let enabled = ref true

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

(* The shapes of one list that are not in the other, each as many times
 * as it is there more: the others' shapes counted in a table, by what
 * they are (a shape is numbers and strings: compared whole). *)
let only_in (these : Playground.shape list) (others : Playground.shape list) : Playground.shape list =
  let counts : (Playground.shape, int ref) Hashtbl.t = Hashtbl.create 64 in
  List.iter
    (fun (s : Playground.shape) ->
      match Hashtbl.find_opt counts s with Some n -> incr n | None -> Hashtbl.add counts s (ref 1))
    others;
  List.filter
    (fun (s : Playground.shape) ->
      match Hashtbl.find_opt counts s with
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

let frame (t : t) (shapes : Playground.shape list) : (box * Framebuffer.t) list =
  let last = t.last in
  t.last <- Some shapes;
  match last with
  | None -> whole t shapes
  | Some _ when not !enabled -> whole t shapes
  (* (the list itself again: a view that made nothing new) *)
  | Some old when old == shapes -> []
  | Some old ->
      (* old: let changed = only_in old shapes @ only_in shapes old in *)
      let was, now = if !Opti.enabled then middle old shapes else (old, shapes) in
      let changed = only_in was now @ only_in now was in
      let boxes =
        merge
          (List.filter_map
             (fun (s : Playground.shape) -> Shape_render_software.pixel_bounds ~width:t.width ~height:t.height ~scale:t.scale [ s ])
             changed) in
      (* (most of the picture: all of it, at once) *)
      if 2 * List.fold_left (fun (n : int) (b : box) -> n + area b) 0 boxes > t.width * t.height then whole t shapes
      else
        List.map
          (fun ((x0, y0, x1, y1) as b : box) ->
            let fb = Framebuffer.create ~width:(x1 - x0) ~height:(y1 - y0) in
            Shape_render_software.render_region ~options:t.options ~scale:t.scale ~window:(t.width, t.height) ~origin:(x0, y0) fb shapes;
            (b, fb))
          boxes

let paste (picture : Framebuffer.t) (parts : (box * Framebuffer.t) list) : unit =
  List.iter
    (fun (((x0, y0, _, _), fb) : box * Framebuffer.t) ->
      for y = 0 to fb.height - 1 do
        Bytes.blit fb.pixels (4 * y * fb.width) picture.pixels (4 * (((y0 + y) * picture.width) + x0)) (4 * fb.width)
      done)
    parts
