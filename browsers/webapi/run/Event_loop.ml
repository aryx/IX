(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's src/webapi/run/Event_loop.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Event_loop.mli *)
open Js_value
open Script_types
open Script_host

(* setTimeout(f, ms) and setInterval: f kept with the time it is due *)
let add ~(frame : bool) (t : t) (args : value list) ~(repeat : bool) : value =
  let f = arg args 0 in
  (* 1 ms at least: a setInterval(f, 0) must let the clock move *)
  let ms = Float.max 1. (match arg args 1 with Undefined -> 0. | v -> to_number v) in
  t.next_timer <- t.next_timer + 1;
  t.timers <- t.timers @ [ { tid = t.next_timer; due = t.now +. ms; every = (if repeat then Some ms else None); fn = f; frame } ];
  Number (float_of_int t.next_timer)

let clear (t : t) (args : value list) : value =
  let id = int_of_float (to_number (arg args 0)) in
  t.timers <- List.filter (fun tm -> tm.tid <> id) t.timers;
  Undefined

let install (t : t) (define : string -> (value list -> value) -> unit) : unit =
  define "setTimeout" (fun args -> add ~frame:false t args ~repeat:false);
  define "setInterval" (fun args -> add ~frame:false t args ~repeat:true);
  define "clearTimeout" (clear t);
  define "clearInterval" (clear t);
  (* the next frame: a timer of a sixtieth of a second, its function
   * given the time (milliseconds since the page began): what an
   * animation moves by *)
  define "requestAnimationFrame" (fun args -> add ~frame:true t [ arg args 0; Number 16. ] ~repeat:false);
  define "cancelAnimationFrame" (clear t)

(* one turn of the loop for the timers: the clock moved, those due
 * are run, the earliest first, each a task; an interval put back at
 * its next time; a thousand at most, so that a page cannot keep the
 * browser here *)
let advance (t : t) (ms : float) ~(task : value -> value -> unit) : unit =
  t.now <- t.now +. ms;
  let rec go (runs : int) =
    match List.sort (fun a b -> compare (a.due, a.tid) (b.due, b.tid)) (List.filter (fun tm -> tm.due <= t.now) t.timers) with
    | tm :: _ when runs < 1000 ->
        (match tm.every with
        | Some every -> tm.due <- tm.due +. every
        | None -> t.timers <- List.filter (fun x -> x.tid <> tm.tid) t.timers);
        task tm.fn (if tm.frame then Number t.now else Undefined);
        go (runs + 1)
    | _ -> ()
  in
  go 0
