(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Palette.mli *)

type t = {
  (* a lit colour -> the faces that have it *)
  counts : (int, int) Hashtbl.t;
  mutable colors : string;
  (* (a colour, a level) -> its index, once asked *)
  indices : (int, int) Hashtbl.t;
}

let levels = 64

let create () : t =
  {
    counts = Hashtbl.create 1024;
    colors = String.make 768 '\000';
    indices = Hashtbl.create 1024;
  }

let level (brightness : float) : int =
  max 0
    (min (levels - 1)
       (int_of_float ((brightness *. float (levels - 1)) +. 0.5)))

let at_level (c : Mesh.color) (l : int) : Mesh.color =
  let ch (shift : int) : int = (c lsr shift) land 255 * l / (levels - 1) in
  (ch 16 lsl 16) lor (ch 8 lsl 8) lor ch 0

let lit (c : Mesh.color) (brightness : float) : Mesh.color =
  at_level c (level brightness)

let count (p : t) (c : Mesh.color) (n : int) : unit =
  let k =
    match Hashtbl.find_opt p.counts c with
    | Some k -> k
    | None -> 0
  in
  Hashtbl.replace p.counts c (k + n)

let add (p : t) (c : Mesh.color) (brightness : float) : unit =
  count p (lit c brightness) 1

let add_mesh (p : t) (m : Mesh.t) : unit =
  for k = 0 to Mesh.faces m - 1 do
    add p m.colors.(k)
      (Lighting.brightness_of_normal (m.nxs.(k), m.nys.(k), m.nzs.(k)))
  done

let add_all_levels (p : t) (c : Mesh.color) : unit =
  for l = 0 to levels - 1 do
    count p (at_level c l) 1
  done

(*****************************************************************************)
(* The median cut *)
(*****************************************************************************)

let channel (c : int) (axis : int) : int = (c lsr (16 - (8 * axis))) land 255

(* a box: the colours from [lo] to [hi] - 1 of the array, its longest
 * side's [axis] and length *)
type box = { lo : int; hi : int; axis : int; side : int }

let box (a : (int * int) array) (lo : int) (hi : int) : box =
  let best = ref (0, -1) in
  for axis = 0 to 2 do
    let mn = ref 255 and mx = ref 0 in
    for i = lo to hi - 1 do
      let v = channel (fst a.(i)) axis in
      mn := min !mn v;
      mx := max !mx v
    done;
    if !mx - !mn > snd !best then best := (axis, !mx - !mn)
  done;
  { lo; hi; axis = fst !best; side = (if hi - lo < 2 then 0 else snd !best) }

(* the box cut at its median, by how many faces each colour has; both
 * halves keep one colour at least *)
let cut (a : (int * int) array) (b : box) : box * box =
  let part = Array.sub a b.lo (b.hi - b.lo) in
  (* (by the axis, then by the whole colour: the order the same by
   * every compiler, whatever order the colours came in) *)
  Array.sort
    (fun ((c1, _) : int * int) ((c2, _) : int * int) ->
      compare (channel c1 b.axis, c1) (channel c2 b.axis, c2))
    part;
  Array.blit part 0 a b.lo (b.hi - b.lo);
  let total =
    Array.fold_left (fun (s : int) ((_, n) : int * int) -> s + n) 0 part
  in
  let i = ref b.lo and acc = ref (snd a.(b.lo)) in
  while !i < b.hi - 2 && 2 * !acc < total do
    incr i;
    acc := !acc + snd a.(!i)
  done;
  (box a b.lo (!i + 1), box a (!i + 1) b.hi)

let make (p : t) : unit =
  let a =
    Array.of_list
      (Hashtbl.fold
         (fun (c : int) (n : int) (l : (int * int) list) -> (c, n) :: l)
         p.counts [])
  in
  Array.sort compare a;
  let boxes =
    ref (if Array.length a = 0 then [] else [ box a 0 (Array.length a) ])
  in
  let n = ref (List.length !boxes) in
  let continue = ref true in
  while !n < 256 && !continue do
    (* the box with the longest side *)
    let widest =
      List.fold_left
        (fun (w : box) (b : box) -> if b.side > w.side then b else w)
        (List.hd !boxes) !boxes
    in
    if widest.side = 0 then continue := false
    else begin
      let b1, b2 = cut a widest in
      boxes := b1 :: b2 :: List.filter (fun (b : box) -> b != widest) !boxes;
      incr n
    end
  done;
  (* each box's colour: its colours' mean, by their faces *)
  let colors = Bytes.make 768 '\000' in
  List.iteri
    (fun (k : int) (b : box) ->
      let sum = Array.make 3 0 and total = ref 0 in
      for i = b.lo to b.hi - 1 do
        let c, w = a.(i) in
        for axis = 0 to 2 do
          sum.(axis) <- sum.(axis) + (w * channel c axis)
        done;
        total := !total + w
      done;
      for axis = 0 to 2 do
        Bytes.set colors
          ((3 * k) + axis)
          (Char.chr ((sum.(axis) + (!total / 2)) / !total))
      done)
    (List.sort (fun (b1 : box) (b2 : box) -> compare b1.lo b2.lo) !boxes);
  p.colors <- Bytes.to_string colors;
  Hashtbl.reset p.indices

let colors (p : t) : string = p.colors

let nearest (p : t) (c : Mesh.color) : int =
  let best = ref 0 and dist = ref max_int in
  for k = 0 to 255 do
    let d (axis : int) : int =
      Char.code p.colors.[(3 * k) + axis] - channel c axis
    in
    let e = (d 0 * d 0) + (d 1 * d 1) + (d 2 * d 2) in
    if e < !dist then begin
      best := k;
      dist := e
    end
  done;
  !best

let index (p : t) (c : Mesh.color) (brightness : float) : int =
  let l = level brightness in
  let key = (c lsl 6) lor l in
  match Hashtbl.find_opt p.indices key with
  | Some k -> k
  | None ->
      let k = nearest p (at_level c l) in
      Hashtbl.replace p.indices key k;
      k
