(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Scan.mli *)

open Edges

(* the new edges of a scanline merged into the active ones, both
 * sorted by u (R_InsertNewEdges) *)
let insert_new_edges (e : Edges.t) (first : int) : unit =
  let at = ref e.next.(head) and k = ref first in
  while !k >= 0 do
    let after = e.next.(!k) in
    while e.u.(!at) < e.u.(!k) do
      at := e.next.(!at)
    done;
    (* before !at *)
    e.next.(!k) <- !at;
    e.prev.(!k) <- e.prev.(!at);
    e.next.(e.prev.(!at)) <- !k;
    e.prev.(!at) <- !k;
    k := after
  done

let remove_edges (e : Edges.t) (first : int) : unit =
  let k = ref first in
  while !k >= 0 do
    e.prev.(e.next.(!k)) <- e.prev.(!k);
    e.next.(e.prev.(!k)) <- e.next.(!k);
    k := e.next_remove.(!k)
  done

(* each edge a scanline down, and those out of order put back
 * (R_StepActiveU): the edge after the tail is at u = -1, which ends it *)
let step_active_u (e : Edges.t) : unit =
  let k = ref e.next.(head) and continue = ref true in
  while !continue do
    let c = !k in
    e.u.(c) <- e.u.(c) + e.u_step.(c);
    if e.u.(c) < e.u.(e.prev.(c)) then begin
      if c = after_tail then continue := false
      else begin
        let after = e.next.(c) in
        (* out, then back before the first edge whose u is not above *)
        e.prev.(e.next.(c)) <- e.prev.(c);
        e.next.(e.prev.(c)) <- e.next.(c);
        let w = ref e.prev.(e.prev.(c)) in
        while e.u.(!w) > e.u.(c) do
          w := e.prev.(!w)
        done;
        e.next.(c) <- e.next.(!w);
        e.prev.(c) <- !w;
        e.prev.(e.next.(c)) <- c;
        e.next.(!w) <- c;
        k := after;
        if after = tail then continue := false
      end
    end
    else k := e.next.(c)
  done

(* a span of surface s, from its last_u to iu, on scanline v *)
let span (e : Edges.t) (s : int) (iu : int) (v : int) : unit =
  if iu > e.last_u.(s) && e.num_spans < Array.length e.span_u then begin
    let k = e.num_spans in
    e.num_spans <- k + 1;
    e.span_u.(k) <- e.last_u.(s);
    e.span_count.(k) <- iu - e.last_u.(s);
    e.span_v.(k) <- v;
    e.span_next.(k) <- e.spans.(s);
    e.spans.(s) <- k
  end

let trailing_edge (e : Edges.t) (s : int) (edge : int) (v : int) : unit =
  e.spanstate.(s) <- e.spanstate.(s) - 1;
  if e.spanstate.(s) = 0 then begin
    if s = e.snext.(background) then begin
      (* the top going away: its span, and the one below starts here *)
      let iu = e.u.(edge) asr shift in
      span e s iu v;
      e.last_u.(e.snext.(s)) <- iu
    end;
    e.snext.(e.sprev.(s)) <- e.snext.(s);
    e.sprev.(e.snext.(s)) <- e.sprev.(s)
  end

(* is s nearer than s2, both brush models' of a leaf: their 1/z where
 * the edge is, s's lowered by 1%, then by the slope *)
let nearer (e : Edges.t) (s : int) (s2 : int) (edge : int) (fv : float) : bool =
  let fu = float (e.u.(edge) - ((1 lsl shift) - 1)) /. float (1 lsl shift) in
  let newzi =
    e.ziorigin.(s) +. (fv *. e.zistepv.(s)) +. (fu *. e.zistepu.(s))
  in
  let testzi =
    e.ziorigin.(s2) +. (fv *. e.zistepv.(s2)) +. (fu *. e.zistepu.(s2))
  in
  newzi *. 0.99 >= testzi
  || (newzi *. 1.01 >= testzi && e.zistepu.(s) >= e.zistepu.(s2))

let leading_edge (e : Edges.t) (edge : int) (v : int) : unit =
  let s = e.surf_lead.(edge) in
  if s <> 0 then begin
    e.spanstate.(s) <- e.spanstate.(s) + 1;
    (* (a span whose end edge came first, inverted, is not started) *)
    if e.spanstate.(s) = 1 then begin
      let fv = float v in
      let top = e.snext.(background) in
      let new_top =
        e.key.(s) < e.key.(top)
        || e.insubmodel.(s)
           && e.key.(s) = e.key.(top)
           && nearer e s top edge fv
      in
      let s2 =
        if new_top then begin
          (* it hides the top: the top's span ends here *)
          let iu = e.u.(edge) asr shift in
          span e top iu v;
          e.last_u.(s) <- iu;
          top
        end
        else begin
          (* its place in the stack: before the first surface farther *)
          let s2 = ref top and found = ref false in
          while not !found do
            s2 := e.snext.(!s2);
            while e.key.(s) > e.key.(!s2) do
              s2 := e.snext.(!s2)
            done;
            (* (of the same key: the one already there is in front, but
             * for brush models, by 1/z) *)
            if
              e.key.(s) <> e.key.(!s2)
              || (e.insubmodel.(s) && nearer e s !s2 edge fv)
            then found := true
          done;
          !s2
        end
      in
      (* before s2 *)
      e.snext.(s) <- s2;
      e.sprev.(s) <- e.sprev.(s2);
      e.snext.(e.sprev.(s2)) <- s;
      e.sprev.(s2) <- s
    end
  end

(* the spans of a scanline (R_GenerateSpans, R_CleanupSpan) *)
let generate_spans (e : Edges.t) (v : int) : unit =
  e.snext.(background) <- background;
  e.sprev.(background) <- background;
  e.last_u.(background) <- e.u.(head) asr shift;
  let k = ref e.next.(head) in
  while !k <> tail do
    let edge = !k in
    let s = e.surf_trail.(edge) in
    if s <> 0 then trailing_edge e s edge v;
    if s = 0 || e.surf_lead.(edge) <> 0 then leading_edge e edge v;
    k := e.next.(edge)
  done;
  (* the right border: what is on top ends there *)
  let top = e.snext.(background) in
  span e top (e.u.(tail) asr shift) v;
  let s = ref top in
  let continue = ref true in
  while !continue do
    e.spanstate.(!s) <- 0;
    s := e.snext.(!s);
    if !s = background then continue := false
  done

let scan_edges (e : Edges.t) (v : View.t) (draw : unit -> unit) : unit =
  (* the borders: the head starts the background at the left, the tail
   * ends it at the right *)
  e.u.(head) <- 0;
  e.u_step.(head) <- 0;
  e.prev.(head) <- -1;
  e.next.(head) <- tail;
  e.surf_trail.(head) <- 0;
  e.surf_lead.(head) <- background;
  e.u.(tail) <- (v.width lsl shift) + ((1 lsl shift) - 1);
  e.u_step.(tail) <- 0;
  e.prev.(tail) <- head;
  e.next.(tail) <- after_tail;
  e.surf_trail.(tail) <- background;
  e.surf_lead.(tail) <- 0;
  e.u.(after_tail) <- -1;
  e.u_step.(after_tail) <- 0;
  e.next.(after_tail) <- sentinel;
  e.prev.(after_tail) <- tail;
  e.u.(sentinel) <- max_int;
  e.prev.(sentinel) <- after_tail;
  for iv = 0 to v.height - 1 do
    e.spanstate.(background) <- 1;
    if e.newedges.(iv) >= 0 then insert_new_edges e e.newedges.(iv);
    generate_spans e iv;
    (* (the table nearly full: drawn and emptied, as id's) *)
    if e.num_spans >= Array.length e.span_u - v.width then begin
      draw ();
      e.num_spans <- 0;
      for s = 1 to e.num_surfaces - 1 do
        e.spans.(s) <- -1
      done
    end;
    if iv < v.height - 1 then begin
      if e.removeedges.(iv) >= 0 then remove_edges e e.removeedges.(iv);
      if e.next.(head) <> tail then step_active_u e
    end
  done;
  draw ()
