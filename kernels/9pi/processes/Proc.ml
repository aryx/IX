(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Proc.mli *)

open Types
open Errors

let nproc = 64
let scheduler_slot = nproc
let procs : proc option array = Array.make nproc None
let nextpid = ref 1

(* the pids 9pi's kernel processes take (kgenrandom and alarm at the
 * boot, kpager at the swap's start, rxmitproc at #I's attach): spent
 * at the same moments, so that the processes' pids are 9pi's (mini-9pi
 * has no such processes) *)
let kproc (_ : string) = incr nextpid

(* the kernel's own processes (ix's: Kusb's that looks at the
 * USB ports), by their slots: what each runs, in the kernel, for ever,
 * where a process goes to user mode (Main's process_start) *)
let kernel_work : (int * (unit -> unit)) list ref = ref []

(* the clock: 100 a second *)
let ticks = ref 0

let myproc () = match procs.(Machine.current ()) with Some p -> p | None -> failwith "myproc: the scheduler"

let all () = List.fold_right (fun o acc -> match o with Some p -> p :: acc | None -> acc) (Array.to_list procs) []

let free_slot () =
  let rec go i = if i = nproc then None else match procs.(i) with None -> Some i | Some _ -> go (i + 1) in
  go 0

(* the processes ready to run, in the order they became so (Plan 9's
 * run queue, one priority): a new process after its parent's readying,
 * so run before the parent goes on (sysrfork's sched) *)
let runq = ref []

(* the process last readied by another (cpu->readied): run next when
 * the running one gives up the CPU (cooperative scheduling: a server
 * woken by a request answers at once, its client right after) *)
(* (a core's own, as the slice below: Machine's cores) *)
let readieds : proc option array = Array.make 4 None

(* not when the CPU was idle (the scheduler's: an interrupt woke p): then
 * p gets a fresh 100ms (9pi's keeps the stale one of the process's last
 * dispatch, so an interactive command could be preempted at its first
 * tick; a divergence of mini-9pi's, for fewer races in a session) *)
let ready p =
  let cur = Machine.current () in
  if cur <> p.slot && cur <> scheduler_slot then readieds.(Machine.core ()) <- Some p;
  p.state <- Runnable;
  runq := !runq @ [ p ];
  (* a core with nothing to run may take it *)
  Machine.cores_wake ()

(* The time a process runs, in its own code (user) or in the kernel
 * (Plan 9's TUser and TSys; time(1)'s u and s, a wait message's, and
 * /dev/cputime's, which were 0). Counted by the board's clock, in
 * microseconds, at each change: the kernel entered (Main's trap, irq
 * and fault: what ran since was the user's), left again for the user
 * (the kernel's), and the processor given up (sched: the kernel's;
 * what passes until it runs again is nobody's, a wait). With several
 * cores, a wait for the kernel's lock at the entry is before the
 * count: the user's.
 * old: nothing counted; a recipe of 12 s whose tool said 0.4 could not
 * say where the rest went (plan_9pi_self_speed.md, 2026-11-20) *)
let charge (p : proc) ~user =
  let now = Machine.timer_now () in
  let d = (now - p.since) land 0x3fffffff in
  p.since <- now;
  if user then begin
    let u = p.uus + d in
    p.utime <- p.utime + (u / 1000); p.uus <- u mod 1000
  end else begin
    let s = p.sus + d in
    p.stime <- p.stime + (s / 1000); p.sus <- s mod 1000
  end

let sched () =
  let p = match procs.(Machine.current ()) with Some p -> Some p | None -> None in
  Option.iter (fun p -> charge p ~user:false) p;
  Machine.swtch scheduler_slot;
  Option.iter (fun (p : proc) -> p.since <- Machine.timer_now ()) p

(* a pending note interrupts a sleep (Eintr), before or after *)
let eintr = "interrupted"

let interrupted p = if p.notepending then begin p.notepending <- false; raise (Error eintr) end

let sleep ch =
  let p = myproc () in
  interrupted p;
  p.state <- Sleeping ch;
  sched ();
  interrupted p

let tsleep ms =
  let until = !ticks + ((ms + 9) / 10) in
  (* (old: sleep Ticks, so woken at each tick to look at the clock
   * again: every sleeping process run 100 times a second, the kernel
   * never idle; a rio's handful of sleepers were most of what an idle
   * screen cost under mini-qemu, plan_web.md) *)
  while !ticks < until do sleep (Until until) done

(* (old: List.iter (fun p -> ...) (all ()): the 64 slots made a list,
 * then the list of the processes, at each wakeup; a wakeup is each
 * tick's and each interrupt's, and those two lists were a fifth of an
 * idle kernel's instructions under mini-qemu, plan_web.md. The slots
 * themselves, in the same order) *)
let wakeup ch =
  Array.iter (fun o -> match o with
    | Some p -> (match p.state with Sleeping c when c = ch -> ready p | _ -> ())
    | None -> ()) procs

(* a tick's: those waiting for any tick (Syssema's), and those whose
 * tick has come (tsleep's) *)
let wakeup_ticks () =
  Array.iter (fun o -> match o with
    | Some p -> (match p.state with
        | Sleeping Ticks -> ready p
        | Sleeping (Until t) when t <= !ticks -> ready p
        | _ -> ())
    | None -> ()) procs

let yield () =
  ready (myproc ());
  sched ()

(* a tick's preemption: no cooperative handing over (hzsched) *)
let preempt () = readieds.(Machine.core ()) <- None; yield ()

let idle = ref (fun () -> ())

(* the running process's slice: 100ms from its dispatch (hzsched:
 * "unless preempted, get to run for at least 100ms") *)
let schedticks = Array.make 4 0
(* the processes each core switched to (/dev/sysstat's second number) *)
let switches = Array.make 4 0

let preempt_due () = !ticks > schedticks.(Machine.core ()) && !runq <> []

(* the run queue's first, its table in TTBR0 while it runs; a dead one's
 * slot freed once it is off its kernel stack. Each core runs this
 * loop on a stack of its own, all on the one queue: a process
 * switched from on one core may be taken next by another. *)
let scheduler () =
  let rec loop () =
    let core = Machine.core () in
    (* the readied process first (its slice going on), or the queue's *)
    let next =
      match readieds.(core) with
      | Some p when p.state = Runnable && List.memq p !runq ->
          runq := List.filter (fun q -> q != p) !runq; Some (p, false)
      | _ -> (match !runq with [] -> None | p :: rest -> runq := rest; Some (p, true)) in
    readieds.(core) <- None;
    (match next with
     | None -> !idle ()
     | Some (p, fresh) ->
         if p.state = Runnable then begin
           p.state <- Running;
           if fresh then schedticks.(core) <- !ticks + 10;
           switches.(core) <- switches.(core) + 1;
           Machine.mmu_switch p.pgdir;
           Machine.swtch p.slot;
           Machine.mmu_switch 0;
           if p.state = Zombie then begin
             Machine.proc_free p.slot;
             procs.(p.slot) <- None
           end
         end);
    loop () in
  loop ()

(*****************************************************************************)
(* Notes *)
(*****************************************************************************)

let nnote = 5

let postnote p msg flag =
  (* a note that ends a process with no handler for it: the only one *)
  if flag <> Nuser && (p.notify = 0 || p.notified) then p.notes <- [];
  let ok = List.length p.notes < nnote in
  if ok then p.notes <- p.notes @ [ msg, flag ];
  p.notepending <- true;
  (match p.state with
   | Sleeping (Rendez _) ->
       p.rgrp.rend <- List.filter (fun q -> q != p) p.rgrp.rend;
       p.rendval <- -1;
       ready p
   | Sleeping _ -> ready p
   | _ -> ());
  ok

let find pid = try Some (List.find (fun p -> p.pid = pid && p.state <> Zombie) (all ())) with Not_found -> None

