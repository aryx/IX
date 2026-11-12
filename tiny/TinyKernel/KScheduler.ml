(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See KScheduler.mli *)
open KProcs

(*****************************************************************************)
(* The scheduler: round robin, preemptive *)
(*****************************************************************************)

(* the interrupts' sources: the timer re-armed (its time is up) and
 * counted, the console's bytes taken, ^C (3) killing the foreground,
 * every process but the shell (the first: no background here), the
 * mouse's word read, the network's packets taken, each given to
 * KNetwork.ml (what it says to send back sent, an echo's answer
 * kept for the link that asked; a connection's messages are in it,
 * where its descriptor's read finds them); whether the timer's *)
let net_news = ref false

(* whether a program has messages it has not read; the tick at which
 * the network's interrupt is taken again all the same *)
let net_behind () =
  List.exists (fun (c : KNetwork.il) ->
    match c.il_r.il_heard with [] -> false | _ -> true) net.ns_conns
let net_open = ref 0

(* the tick of the connections' next look at the time *)
let net_next = ref 0

let net_take () =
  let n = KMachine.peek (KMachine.net_dev + 4) in
  if n > 0 then begin
    KIO.net_command n 2;
    let bytes = KMachine.k_string KMachine.net_buf n in
    (match KNetwork.net_input net !KDevices.ticks bytes with
     | back, answer ->
         List.iter KIO.net_send back;
         (match answer with
          | Some (from, id, _, data) ->
              List.iter (fun (l : KFiles.link) ->
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
    if net_behind () then KMachine.k_ie 11
  end

(* the ticks since the last one counted, the timer set for the next *)
let count_ticks () =
  let passed = (KMachine.k_clock () - !KDevices.counted) land 0x3fffffff in
  KDevices.ticks := !KDevices.ticks + (passed / KMachine.tick);
  KDevices.counted :=
    (!KDevices.counted + (passed / KMachine.tick * KMachine.tick)) land 0x3fffffff;
  KMachine.k_timer (KMachine.tick - (passed mod KMachine.tick))

(* what each core runs, but core 0 (the processes' core says it too);
 * [back], given a process's trap on another core, is the scheduler's
 * (below) *)
let on = Array.make KMachine.cores None
let back_hook =
  ref (fun (_ : int) (_ : proc) (_ : KMachine.cause) (_ : int) -> ())

let interrupts sources =
  (* the cores' traps, each from the core that raised the interrupt *)
  if sources land 32 <> 0 then begin
    let from = KMachine.peek KMachine.ipi_dev in
    for k = 1 to KMachine.cores - 1 do
      match on.(k) with
      | Some p when from land (1 lsl k) <> 0 ->
          on.(k) <- None;
          p.core <- None;
          let box = KMachine.mailbox k in
          !back_hook k p (KMachine.cause_of (KMachine.peek (box + 16)))
            (KMachine.peek (box + 20))
      | _ -> ()
    done
  end;
  if sources land 16 <> 0 then net_take ();
  if sources land 8 <> 0 then begin
    (* the machine's word: x in 12 bits, y in the next 12, the buttons above *)
    let m = KMachine.peek KMachine.mouse_dev in
    KDevices.mouse.last <-
      KFiles.word (m land 0xfff) ^ KFiles.word ((m lsr 12) land 0xfff)
      ^ KFiles.word (m lsr 24);
    KDevices.mouse.fresh <- true
  end;
  if sources land 2 <> 0 then begin
    let rec take () =
      let c = KMachine.peek KMachine.cons_in in
      if c = -2 then KIO.typed_end := true
      else if c = 3 && not (KIO.raw_on ()) then
        (KIO.typed := "";
         List.iter (fun q -> if q.pid <> 1 then KCalls.kill q) !procs;
         KMachine.puts "\n";
         take ())
      else if c <> -1 then
        (KIO.typed := !KIO.typed ^ String.make 1 (Char.chr c); take ()) in
    take ()
  end;
  (* the ticks since the last one counted, by the machine's time: the
   * timer's interrupt waits while the kernel works, and a long call
   * is several ticks (old: one counted at each interrupt, the timer
   * set a tick from then; a game's second was two under a window) *)
  if sources land 1 <> 0 then begin
    count_ticks ();
    if !KDevices.ticks >= !net_open || not (net_behind ()) then
      (net_open := !KDevices.ticks + 8; KMachine.k_ie 27);
    (* the connections' time: what they send when nothing came, and one
     * that gave up is news for who waits on it *)
    (* (every fourth tick, 10 ms: a pass over the connections is 3,400
     * instructions with one of them, which at each tick was 4 ms of a
     * picture's row; IL's waits are 40 ticks and more) *)
    (match net.ns_conns with
     | [] -> ()
     | conns ->
         if !KDevices.ticks >= !net_next then begin
           net_next := !KDevices.ticks + 4;
           List.iter KIO.net_send (KNetwork.net_tick net !KDevices.ticks);
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
           if (match p.since with Some n -> n = !deaths | None -> false)
           then runnable ok rest
           else if attempt () then
             (p.state <- Ready;
              if KCalls.waited p then runnable ok !procs
              else if ok p then Some p
              else runnable ok rest)
           else (if p.since <> None then p.since <- Some !deaths;
                 runnable ok rest)
       | Stopped -> runnable ok rest)

(* what core 0 may run: a process on no core; what another may: one
 * not traced too (a tracer reads its frame, steps it: core 0's) *)
let core0 = Some 0
let anywhere p = p.core = None
let elsewhere p = p.core = None && not (KIO.traced p)

(* The other cores (kentry.s's slave). A process given to core k: its
 * frame, its window and a slice in k's mailbox, then k's interrupt *)
let give k p =
  p.core <- Some k;
  on.(k) <- Some p;
  let m = KMachine.mailbox k in
  KMemory.mem_post p.mem (m + 4);
  KMachine.poke (m + 12) KMachine.tick;
  KMachine.poke m (KMachine.frame p.slot);
  KMachine.poke KMachine.ipi_dev k

(* each free core given a process that can run *)
let dispatch () =
  for k = 1 to KMachine.cores - 1 do
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
  ignore (KMachine.k_run 0);
  let sources = KMachine.k_tval () in
  ignore (interrupts sources);
  let alarm = !KDevices.alarm in
  if sources land 58 <> 0 || !net_news
     || (alarm > 0 && !KDevices.ticks >= alarm)
  then (KDevices.alarm := 0; net_news := false; schedule ())
  else idle ()

(* (core 0's Some made once: run gives it at each trap) *)
and run p =
  match p.traced with
  | Some { call = Some n; _ } -> KCalls.call p n; next p false
  | Some t when t.step || t.over <> None -> step p t
  | _ ->
      p.core <- core0;
      KMemory.mem_window p.mem;
      let cause = KMachine.cause_of (KMachine.k_run (KMachine.frame p.slot)) in
      next p (trapped p cause (KMachine.k_tval ()))

(* A traced process run for one instruction: a step, or a breakpoint's
 * word run (its 0 written again after, the process going on). The
 * timer's interrupt ends it (or the instruction's trap), and the timer
 * is set again for the next tick; an interrupt that came before the
 * instruction ran is taken, and the process run again. A step that
 * makes a call that waits stops when the call ends (waited). *)
and step p (t : KFiles.trace) =
  KMemory.mem_window p.mem;
  let cause = KMachine.cause_of (KMachine.k_step (KMachine.frame p.slot)) in
  let ran = cause <> Trap_intr || KMachine.k_tval () land 1 <> 0 in
  let timer = trapped p cause (KMachine.k_tval ()) in
  if cause <> Trap_intr then count_ticks ();
  if ran && List.exists (fun q -> q.pid = p.pid) !procs then begin
    (match t.over with
     | Some a when List.exists (fun (b, _) -> b = a) t.stops ->
         KMemory.mem_store p.mem a 0
     | _ -> ());
    t.over <- None;
    match p.state with Ready when t.step -> KIO.stop p "step" | _ -> ()
  end;
  next p timer

(* a trap handled, its cause and its value; whether it was the timer's *)
and trapped p (cause : KMachine.cause) tval =
  match cause with
  | Trap_sys -> KCalls.call p tval; false
  | Trap_intr -> interrupts tval
  | Trap_illegal when KIO.traced p ->
      KIO.stop p
        (if tval = 0 then "break" else "illegal " ^ string_of_int tval);
      false
  (* (a page not touched yet, or one a fork shares: pages) *)
  | Trap_fault when KMemory.mem_fault p.mem tval -> false
  | Trap_fault when KIO.traced p ->
      KIO.stop p ("fault " ^ string_of_int tval); false
  | Trap_illegal | Trap_fault ->
    KMachine.puts ("ml: " ^ string_of_int p.pid ^ ": trap "
          ^ string_of_int (KMachine.cause_code cause)
          ^ " at " ^ string_of_int (reg p 16) ^ ", "
          ^ string_of_int tval ^ ": killed\n");
    KCalls.exit_proc p (-1);
    false

(* the same process again unless its time is up or it cannot go on
 * (the other cores given what can run first: what p's call made ready) *)
and next p timer =
  let alive = List.exists (fun q -> q.pid = p.pid) !procs in
  if alive && (not timer) && (match p.state with Ready -> true | _ -> false)
  then (dispatch (); run p)
  else begin
    p.core <- None;
    if alive then last p;
    schedule ()
  end

(* A trap of p's on core k, handled here as core 0's (its interrupt is
 * the core's timer: its slice is up); p on k again unless its time is
 * up or it cannot go on, as [next]. Killed while it ran, it ends now. *)
let back k p cause tval =
  if p.doomed then KCalls.exit_proc p (-1)
  else begin
    let timer = cause = KMachine.Trap_intr || trapped p cause tval in
    let alive = List.exists (fun q -> q.pid = p.pid) !procs in
    if alive && (not timer) && elsewhere p
       && (match p.state with Ready -> true | _ -> false)
    then give k p
    else if alive then last p
  end;
  dispatch ()
let () = back_hook := back
