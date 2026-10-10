(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Thread.mli *)

type t = int

(* The runtime's part: a thread is a number, 0 the program's first.
 * thread_new gives one its two stacks and the function it starts with
 * (Failure when there are too many); thread_switch leaves the running
 * one where it is and goes on with another, where that one left (or at
 * its function, the first time); thread_free gives a finished one's
 * number and stacks back (not its own: a thread cannot free the stack
 * it runs on). *)
external thread_new : (unit -> unit) -> t = "thread_new"
external thread_switch : t -> unit = "thread_switch"
external thread_free : t -> unit = "thread_free"

let critical_section = ref false

(* the program's end (exit, below, is a thread's) *)
let quit : int -> unit = exit

let current = ref 0
(* those that can run, in their turn's order *)
let ready : t Queue.t = Queue.create ()
(* those that wait for a wakeup; those that ended and are not freed yet *)
let asleep : (t, unit) Hashtbl.t = Hashtbl.create 16
let ended : t list ref = ref []
(* who waits for whom to end *)
let joiners : (t, t) Hashtbl.t = Hashtbl.create 16
let alive : (t, unit) Hashtbl.t = Hashtbl.create 16

let idle = ref (fun () -> prerr_string "Thread: deadlock: every thread sleeps\n"; quit 2)

(* the next thread that can run, run: back here when the caller's turn
 * comes again *)
let rec schedule () =
  match Queue.take_opt ready with
  | Some t when t = !current -> ()
  | Some t ->
      current := t;
      thread_switch t;
      (* (in the caller again: the finished ones' stacks given back) *)
      List.iter (fun d -> if d <> !current then begin thread_free d; ended := List.filter (fun e -> e <> d) !ended end) !ended
  | None -> !idle (); schedule ()

let self () = !current
let id (t : t) : int = t

let yield () = Queue.add !current ready; schedule ()

let sleep () =
  critical_section := false;
  Hashtbl.replace asleep !current ();
  schedule ()

let wakeup t =
  if Hashtbl.mem asleep t then begin
    Hashtbl.remove asleep t;
    Queue.add t ready
  end

let exit () =
  let me = !current in
  if me = 0 then quit 0;
  Hashtbl.remove alive me;
  List.iter wakeup (Hashtbl.find_all joiners me);
  while Hashtbl.mem joiners me do Hashtbl.remove joiners me done;
  ended := me :: !ended;
  schedule ()

let join t =
  if Hashtbl.mem alive t then begin
    Hashtbl.add joiners t !current;
    sleep ()
  end

let create fn arg =
  let t = thread_new (fun () ->
    (try ignore (fn arg) with e ->
       flush stdout;
       prerr_string ("Thread " ^ string_of_int !current ^ " killed on uncaught exception " ^ Printexc.to_string e ^ "\n"));
    exit ()) in
  Hashtbl.replace alive t ();
  Queue.add t ready;
  t
