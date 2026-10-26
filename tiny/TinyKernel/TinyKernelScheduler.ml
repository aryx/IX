(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyKernelScheduler.mli *)
open TinyKernelNetwork
open TinyKernelMemory
open TinyKernelMachine
open TinyKernelFiles
open TinyKernelProcs
open TinyKernelDevices
open TinyKernelIO
open TinyKernelCalls

(*****************************************************************************)
(* The scheduler: round robin, preemptive *)
(*****************************************************************************)

(* the interrupts' sources: the timer re-armed (its time is up) and
 * counted, the console's bytes taken, ^C (3) killing the foreground,
 * every process but the shell (the first: no background here), the
 * mouse's word read, the network's packets taken, each given to
 * TinyKernelNetwork.ml (what it says to send back sent, an echo's answer
 * kept for the link that asked; a connection's messages are in it,
 * where its descriptor's read finds them); whether the timer's *)
let net_news = ref false

(* whether a program has messages it has not read; the tick at which
 * the network's interrupt is taken again all the same *)
let net_behind () =
  List.exists (fun c ->
    match c.il_r.il_heard with [] -> false | _ -> true) net.ns_conns
let net_open = ref 0

(* the tick of the connections' next look at the time *)
let net_next = ref 0

let net_take () =
  let n = peek (net_dev + 4) in
  if n > 0 then begin
    net_command n 2;
    (match net_input net !ticks (k_string net_buf n) with
     | back, answer ->
         List.iter net_send back;
         (match answer with
          | Some (from, id, _, data) ->
              List.iter (fun l ->
                if l.lid = id && l.peer = from then
                  l.heard <- l.heard @ [ data ]) !links
          | None -> ()))
    (* (one packet a call: the interrupt stays while another waits, and
     * the timer's is seen between two, so a burst does not stop the
     * clock, nor the acknowledgements, which go at its ticks. old: a
     * loop here, 230 ms without a tick for seven packets of 1 KB) *);
    (* When a program has messages to read, the packets that wait are
     * left for a while (the timer's interrupt says when: one more is
     * taken every 20 ms): the network's interrupt is not taken until
     * then, and the programs run. A burst of 20 rows was taken before
     * its reader read one, 280 ms in which nothing was acknowledged,
     * and the other end asked where it was. *)
    if net_behind () then k_ie 11
  end

(* the ticks since the last one counted, the timer set for the next *)
let count_ticks () =
  let passed = (k_clock () - !counted) land 0x3fffffff in
  ticks := !ticks + (passed / tick);
  counted := (!counted + (passed / tick * tick)) land 0x3fffffff;
  k_timer (tick - (passed mod tick))

(* what each core runs, but core 0 (the processes' core says it too);
 * [back], given a process's trap on another core, is the scheduler's
 * (below) *)
let on = Array.make cores None
let back_hook = ref (fun (_ : int) (_ : proc) (_ : int) (_ : int) -> ())

let interrupts sources =
  (* the cores' traps, each from the core that raised the interrupt *)
  if sources land 32 <> 0 then begin
    let from = peek ipi_dev in
    for k = 1 to cores - 1 do
      match on.(k) with
      | Some p when from land (1 lsl k) <> 0 ->
          on.(k) <- None;
          p.core <- -1;
          !back_hook k p (peek (mailbox k + 16)) (peek (mailbox k + 20))
      | _ -> ()
    done
  end;
  if sources land 16 <> 0 then net_take ();
  if sources land 8 <> 0 then begin
    (* the machine's word: x in 12 bits, y in the next 12, the buttons above *)
    let m = peek mouse_dev in
    mouse.last <-
      word (m land 0xfff) ^ word ((m lsr 12) land 0xfff) ^ word (m lsr 24);
    mouse.fresh <- true
  end;
  if sources land 2 <> 0 then begin
    let rec take () =
      let c = peek cons_in in
      if c = -2 then typed_end := true
      else if c = 3 && not (raw_on ()) then
        (typed := "";
         List.iter (fun q -> if q.pid <> 1 then kill q) !procs;
         puts "\n";
         take ())
      else if c <> -1 then
        (typed := !typed ^ String.make 1 (Char.chr c); take ()) in
    take ()
  end;
  (* the ticks since the last one counted, by the machine's time: the
   * timer's interrupt waits while the kernel works, and a long call
   * is several ticks (old: one counted at each interrupt, the timer
   * set a tick from then; a game's second was two under a window) *)
  if sources land 1 <> 0 then begin
    count_ticks ();
    if !ticks >= !net_open || not (net_behind ()) then
      (net_open := !ticks + 8; k_ie 27);
    (* the connections' time: what they send when nothing came, and one
     * that gave up is news for who waits on it *)
    (* (every fourth tick, 10 ms: a pass over the connections is 3,400
     * instructions with one of them, which at each tick was 4 ms of a
     * picture's row; IL's waits are 40 ticks and more) *)
    (match net.ns_conns with
     | [] -> ()
     | conns ->
         if !ticks >= !net_next then begin
           net_next := !ticks + 4;
           List.iter net_send (net_tick net !ticks);
           if List.length net.ns_conns < List.length conns then
             net_news := true
         end);
    true
  end
  else false

(* the first process that can run and that [ok] takes: ready, or
 * waiting and its call now finished. A traced one whose call ended may
 * stop instead (waited), which its tracer reads: the processes looked at
 * again from the first, since the tracer may be before it, already
 * passed over (old: runnable rest, and the tracer waited for the next
 * key or alarm: trace of a process in the background stopped at a
 * wait's end) *)
let rec runnable ok l =
  match l with
  | [] -> None
  | p :: rest ->
      (match p.state with
       | Ready -> if ok p then Some p else runnable ok rest
       | Waiting attempt ->
           if p.since = !deaths then runnable ok rest
           else if attempt () then
             (p.state <- Ready;
              if waited p then runnable ok !procs
              else if ok p then Some p
              else runnable ok rest)
           else (if p.since >= 0 then p.since <- !deaths; runnable ok rest)
       | Zombie _ -> runnable ok rest
       | Stopped -> runnable ok rest)

(* what core 0 may run: a process on no core; what another may: one
 * not traced too (a tracer reads its frame, steps it: core 0's) *)
let anywhere p = p.core < 0
let elsewhere p = p.core < 0 && not (traced p)

(* The other cores (entry.tm's slave). A process given to core k: its
 * frame, its window and a slice in k's mailbox, then k's interrupt *)
let give k p =
  p.core <- k;
  on.(k) <- Some p;
  let m = mailbox k in
  mem_post p.mem (m + 4);
  poke (m + 12) tick;
  poke m (frame p.slot);
  poke ipi_dev k

(* each free core given a process that can run *)
let dispatch () =
  for k = 1 to cores - 1 do
    if on.(k) = None then
      match runnable elsewhere !procs with
      | Some p -> give k p
      | None -> ()
  done

(* last in the round *)
let last p = procs := List.filter (fun q -> q.pid <> p.pid) !procs @ [ p ]

(* the loop: a process run until it traps, the trap handled; the same
 * process again unless its time is up or it cannot go on (then it goes
 * last); none to run, an interrupt waited for *)
let rec schedule () =
  dispatch ();
  match runnable anywhere !procs with
  | Some p -> run p
  | None -> idle ()

(* Every process waits. What they wait for changes only by a key, the
 * mouse, or a time one of them asked for (the alarm, which the calls
 * still waiting set again when retried): the clock's other ticks are
 * counted and nothing is retried. (old: schedule () after each
 * interrupt, every closure at each tick: a quarter of the instructions
 * of a machine where nothing happened) *)
and idle () =
  ignore (k_run 0);
  let sources = k_tval () in
  ignore (interrupts sources);
  if sources land 58 <> 0 || !net_news || (!alarm > 0 && !ticks >= !alarm)
  then (alarm := 0; net_news := false; schedule ())
  else idle ()

and run p =
  match p.traced with
  | Some t when t.call >= 0 -> call p t.call; next p false
  | Some t when t.step || t.over >= 0 -> step p t
  | _ ->
      p.core <- 0;
      mem_window p.mem;
      let cause = k_run (frame p.slot) in
      next p (trapped p cause (k_tval ()))

(* A traced process run for one instruction: a step, or a breakpoint's
 * word run (its 0 written again after, the process going on). The
 * timer's interrupt ends it (or the instruction's trap), and the timer
 * is set again for the next tick; an interrupt that came before the
 * instruction ran is taken, and the process run again. A step that
 * makes a call that waits stops when the call ends (waited). *)
and step p t =
  mem_window p.mem;
  let cause = k_step (frame p.slot) in
  let ran = cause <> c_intr || k_tval () land 1 <> 0 in
  let timer = trapped p cause (k_tval ()) in
  if cause <> c_intr then count_ticks ();
  if ran && List.exists (fun q -> q.pid = p.pid) !procs then begin
    if t.over >= 0 && List.exists (fun (b, _) -> b = t.over) t.stops then
      mem_store p.mem t.over 0;
    t.over <- -1;
    match p.state with Ready when t.step -> stop p "step" | _ -> ()
  end;
  next p timer

(* a trap handled, its cause and its value; whether it was the timer's *)
and trapped p cause tval =
  if cause = c_sys then (call p tval; false)
  else if cause = c_intr then interrupts tval
  else if cause = c_illegal && traced p then
    (stop p (if tval = 0 then "break" else "illegal " ^ string_of_int tval);
     false)
  (* (a page not touched yet, or one a fork shares: pages) *)
  else if cause = c_fault && mem_fault p.mem tval then false
  else if cause = c_fault && traced p then
    (stop p ("fault " ^ string_of_int tval); false)
  else begin
    puts ("ml: " ^ string_of_int p.pid ^ ": trap " ^ string_of_int cause
          ^ " at " ^ string_of_int (reg p 16) ^ ", "
          ^ string_of_int tval ^ ": killed\n");
    exit_proc p (-1);
    false
  end

(* the same process again unless its time is up or it cannot go on
 * (the other cores given what can run first: what p's call made ready) *)
and next p timer =
  let alive = List.exists (fun q -> q.pid = p.pid) !procs in
  if alive && (not timer) && (match p.state with Ready -> true | _ -> false)
  then (dispatch (); run p)
  else begin
    p.core <- -1;
    if alive then last p;
    schedule ()
  end

(* A trap of p's on core k, handled here as core 0's (its interrupt is
 * the core's timer: its slice is up); p on k again unless its time is
 * up or it cannot go on, as [next]. Killed while it ran, it ends now. *)
let back k p cause tval =
  if p.doomed then exit_proc p (-1)
  else begin
    let timer = cause = c_intr || trapped p cause tval in
    let alive = List.exists (fun q -> q.pid = p.pid) !procs in
    if alive && (not timer) && elsewhere p
       && (match p.state with Ready -> true | _ -> false)
    then give k p
    else if alive then last p
  end;
  dispatch ()
let () = back_hook := back
