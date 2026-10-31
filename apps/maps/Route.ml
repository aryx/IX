(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Route.mli *)

type t = { edges : int list; millis : int; metres : int; settled : int }

(* a binary heap: the children of i at 2i+1 and 2i+2, each no less than
 * its parent; two arrays, doubled as needed *)
type heap = { mutable costs : int array; mutable nodes : int array; mutable size : int }

let push (h : heap) (cost : int) (node : int) : unit =
  if h.size = Array.length h.costs then begin
    let grown (a : int array) : int array =
      Array.append a (Array.make (Array.length a) 0)
    in
    h.costs <- grown h.costs;
    h.nodes <- grown h.nodes
  end;
  let i = ref h.size in
  h.size <- h.size + 1;
  while !i > 0 && h.costs.((!i - 1) / 2) > cost do
    let parent = (!i - 1) / 2 in
    h.costs.(!i) <- h.costs.(parent);
    h.nodes.(!i) <- h.nodes.(parent);
    i := parent
  done;
  h.costs.(!i) <- cost;
  h.nodes.(!i) <- node

(* the smallest; the heap is not empty *)
let pop (h : heap) : int * int =
  let top = (h.costs.(0), h.nodes.(0)) in
  h.size <- h.size - 1;
  let cost = h.costs.(h.size) and node = h.nodes.(h.size) in
  let i = ref 0 and placed = ref false in
  while not !placed do
    let left = (2 * !i) + 1 and right = (2 * !i) + 2 in
    let c =
      if right < h.size && h.costs.(right) < h.costs.(left) then right else left
    in
    if c < h.size && h.costs.(c) < cost then begin
      h.costs.(!i) <- h.costs.(c);
      h.nodes.(!i) <- h.nodes.(c);
      i := c
    end
    else placed := true
  done;
  h.costs.(!i) <- cost;
  h.nodes.(!i) <- node;
  top

let search (g : Roads.t) ~(guess : bool) (from : int) (goal : int) : t option =
  let count = Array.length g.lat in
  (* what is left, rounded down as the edges are rounded up, so that it
   * stays consistent *)
  let left (n : int) : int =
    if not guess then 0
    else
      let dx = g.x.(n) -. g.x.(goal) and dy = g.y.(n) -. g.y.(goal) in
      int_of_float (sqrt ((dx *. dx) +. (dy *. dy)) /. g.top_speed *. 1000.)
  in
  let cost = Array.make count max_int in
  let came = Array.make count (-1) in
  let settled = Array.make count false in
  let queue = { costs = Array.make 1024 0; nodes = Array.make 1024 0; size = 0 } in
  cost.(from) <- 0;
  push queue (left from) from;
  let taken = ref 0 and found = ref false in
  while (not !found) && queue.size > 0 do
    let _, n = pop queue in
    if not settled.(n) then begin
      settled.(n) <- true;
      incr taken;
      if n = goal then found := true
      else
        for e = g.first.(n) to g.first.(n + 1) - 1 do
          let m = g.target.(e) in
          let c = cost.(n) + g.millis.(e) in
          if c < cost.(m) then begin
            cost.(m) <- c;
            came.(m) <- e;
            push queue (c + left m) m
          end
        done
    end
  done;
  if not !found then None
  else begin
    let rec back (n : int) (acc : int list) : int list =
      if n = from then acc
      else
        let e = came.(n) in
        back g.origin.(e) (e :: acc)
    in
    let edges = back goal [] in
    let metres = List.fold_left (fun (s : int) (e : int) -> s + g.metres.(e)) 0 edges in
    Some { edges; millis = cost.(goal); metres; settled = !taken }
  end
