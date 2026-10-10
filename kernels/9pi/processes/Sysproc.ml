(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Sysproc.mli *)

open Types
open Errors
open Usermem

let find_proc pid = List.find (fun o -> match o with Some q -> q.pid = pid && q.state <> Zombie | None -> false)
                      (Array.to_list Proc.procs)

let exits (p : proc) status =
  Kchan.fgrp_close p.fgrp;
  if p.pid = 1 then ignore (Machine.panic ("boot process died: " ^ (if status = "" then "unknown" else status)));
  (* the parent told, if still there (the last child's first) *)
  (if p.parent <> 0 then
     match (try find_proc p.parent with Not_found -> None) with
     | Some q ->
         q.nchild <- q.nchild - 1;
         if List.length q.waitq < 128 then begin
           let msg = if status = "" then "" else p.text ^ " " ^ string_of_int p.pid ^ ": " ^ status in
           let msg = if String.length msg >= errmax then String.sub msg 0 (errmax - 1) else msg in
           q.waitq <- { wpid = p.pid; wtime = (!Proc.ticks - p.start) * 10; wmsg = msg } :: q.waitq;
           Proc.wakeup (Child_exit q.pid)
         end
     | None -> ());
  Machine.mmu_switch 0;
  Fault.release p.pgdir p.segs;
  p.pgdir <- 0;
  p.segs <- [];
  p.alarm <- 0;
  p.state <- Zombie;
  Proc.sched ()

let pprint (p : proc) s =
  match p.fgrp.fds.(2) with
  | Some c when (match c.opened with Some m -> m.access = Owrite || m.access = Ordwr | None -> false) ->
      (try ignore ((Dev.find c.dev).Dev.write c (p.text ^ " " ^ string_of_int p.pid ^ ": " ^ s) c.offset)
       with Error _ -> ())
  | _ -> ()

(*****************************************************************************)
(* rfork *)
(*****************************************************************************)

let rfnameg = 1 and rfenvg = 2 and rffdg = 4 and rfnoteg = 8 and rfproc = 16 and rfmem = 32 and rfnowait = 64
and rfcnameg = 1024 and rfcenvg = 2048 and rfcfdg = 4096 and rfrend = 8192 and rfnomnt = 16384

let noteids = ref 1

(* the groups a process gets, from its own and the flags *)
let groups (p : proc) flag =
  let fg = if flag land rffdg <> 0 then Kchan.fgrp_copy p.fgrp
    else if flag land rfcfdg <> 0 then Kchan.fgrp_new ()
    else begin p.fgrp.fref <- p.fgrp.fref + 1; p.fgrp end in
  let pg = if flag land rfnameg <> 0 then Kchan.pgrp_copy p.pgrp
    else if flag land rfcnameg <> 0 then { mnt = [] } else p.pgrp in
  let eg = if flag land rfenvg <> 0 then Devenv.copy p.egrp
    else if flag land rfcenvg <> 0 then { vars = []; last_path = 0 } else p.egrp in
  fg, pg, eg

let sysrfork (p : proc) flag =
  if flag land (rffdg lor rfcfdg) = rffdg lor rfcfdg || flag land (rfnameg lor rfcnameg) = rfnameg lor rfcnameg
     || flag land (rfenvg lor rfcenvg) = rfenvg lor rfcenvg then raise (Error ebadarg);
  if flag land rfproc = 0 then begin
    if flag land (rfmem lor rfnowait) <> 0 then raise (Error ebadarg);
    let old = p.fgrp in
    let fg, pg, eg = groups p flag in
    if fg != old then Kchan.fgrp_close old else old.fref <- old.fref - 1;
    p.fgrp <- fg; p.pgrp <- pg; p.egrp <- eg;
    if flag land rfrend <> 0 then p.rgrp <- { rend = [] };
    if flag land rfnoteg <> 0 then begin incr noteids; p.noteid <- !noteids end;
    0
  end else begin
    let slot = match Proc.free_slot () with Some s -> s | None -> raise (Error "no free processes") in
    let pgdir = match Mmu.create () with Some d -> d | None -> raise (Error enovmem) in
    (* the memory (dupseg): text shared, data and bss too with RFMEM, the
     * stack copied *)
    let share s = s.kind = Text || (flag land rfmem <> 0 && s.kind <> Stack) in
    let segs = List.fold_left (fun acc s ->
      match acc with
      | None -> None
      | Some l -> (try Some (Fault.dup s pgdir (share s) :: l) with Error _ -> Fault.release pgdir l; None)) (Some []) p.segs in
    let segs = match segs with Some l -> List.rev l | None -> raise (Error enovmem) in
    let fg, pg, eg = groups p flag in
    let pid = !Proc.nextpid in
    incr Proc.nextpid;
    if flag land rfnoteg <> 0 then incr noteids;
    let child = {
      pid = pid; slot = slot; state = Runnable;
      parent = (if flag land rfnowait <> 0 then 0 else p.pid); nchild = 0; waitq = [];
      pgdir = pgdir; segs = segs;
      fgrp = fg; pgrp = pg; egrp = eg; slash = p.slash; dot = p.dot;
      notify = p.notify; noteid = (if flag land rfnoteg <> 0 then !noteids else p.noteid);
      errstr = ""; text = p.text; start = !Proc.ticks; psstate = ""; args = ""; setargs = false;
      notes = []; notepending = false; notified = false; ureg = 0; lastnote = ("", Nuser); alarm = 0;
      rgrp = (if flag land rfrend <> 0 then { rend = [] } else p.rgrp); rendtag = 0; rendval = 0 } in
    if flag land rfnowait = 0 then p.nchild <- p.nchild + 1;
    ignore (Mmu.write pgdir (Exec.ustktop - Exec.tos_size + 52) (Machine.le32 pid));
    Machine.tf_copy slot;
    Machine.proc_context slot;
    Proc.procs.(slot) <- Some child;
    Proc.ready child;
    Proc.yield ();
    pid
  end

(*****************************************************************************)
(* exec, exits, await *)
(*****************************************************************************)

(* argv: the user's array of strings, to its 0 *)
let user_args (p : proc) addr =
  let rec go a acc =
    let v = Machine.get_le32 (user_read p a 4) 0 in
    if v = 0 then List.rev acc else go (a + 4) (user_string p v maxpath :: acc) in
  go addr []

let sysexec (p : proc) name argv =
  let r = Exec.exec p name (user_args p argv) in
  Exec.set_tos_pid p;
  r

let sysexits (p : proc) status = exits p (if status = 0 then "" else user_string p status errmax); 0

let sysawait (p : proc) buf n =
  if p.nchild = 0 && p.waitq = [] then raise (Error enochild);
  let rec wait () = match p.waitq with
    | [] -> Proc.sleep (Child_exit p.pid); wait ()
    | w :: rest -> p.waitq <- rest; w in
  let w = wait () in
  user_snprint p buf n (Printf.sprintf "%d %d %d %d %s" w.wpid 0 0 w.wtime (Dev.quote w.wmsg))

(*****************************************************************************)
(* brk *)
(*****************************************************************************)

let seg (p : proc) kind =
  try List.find (fun s -> s.kind = kind) p.segs with Not_found -> raise (Error ebadarg)

(* ibrk on the bss: its top moved to addr (0: where it starts) *)
let sysbrk (p : proc) addr =
  let s = seg p Bss in
  if addr = 0 then s.base
  else begin
    let addr =
      if addr >= s.base then addr
      else if addr < (seg p Data).base then raise (Error enovmem)
      else s.base in
    (* the new pages given at their first touch (Fault) *)
    let newtop = Mmu.pgroundup addr in
    if newtop < s.top then begin
      Fault.shrink p s newtop;
      s.top <- newtop
    end else begin
      List.iter (fun ns -> if ns != s && newtop >= ns.base && newtop < ns.top then raise (Error esoverlap)) p.segs;
      s.top <- newtop
    end;
    0
  end

(*****************************************************************************)
(* sleep, alarm, notes, rendezvous, errstr *)
(*****************************************************************************)

let syssleep (_ : proc) ms = if ms <= 0 then Proc.yield () else Proc.tsleep ms; 0

(* alarm: the old one's ms left; the new one's tick (ms2tk: rounded) *)
let sysalarm (p : proc) ms =
  let old = if p.alarm <> 0 then max 0 ((p.alarm - !Proc.ticks) * 10) else 0 in
  p.alarm <- (if ms = 0 then 0 else !Proc.ticks + max 1 ((ms + 5) / 10));
  old

let sysnotify (p : proc) f = if f <> 0 then Fault.validaddr p f 4; p.notify <- f; 0

let ncont = 0 and ndflt = 1 and nsave = 2 and nrstr = 3

let noted_arg = ref None

let sysnoted (p : proc) arg0 = if arg0 <> nrstr && not p.notified then raise (Error egreg); noted_arg := Some arg0; 0

(* rendezvous: the value exchanged with the process waiting on the tag
 * (the last to come first), or waited for (-1: a note came) *)
let sysrendezvous (p : proc) tag v =
  try
    let q = List.find (fun q -> q.rendtag = tag) p.rgrp.rend in
    p.rgrp.rend <- List.filter (fun x -> x != q) p.rgrp.rend;
    let r = q.rendval in
    q.rendval <- v;
    Proc.ready q;
    r
  with Not_found ->
    p.rendtag <- tag;
    p.rendval <- v;
    p.rgrp.rend <- p :: p.rgrp.rend;
    p.state <- Sleeping (Rendez p.pid);
    Proc.sched ();
    p.rendval

let syserrstr (p : proc) buf n =
  if n <= 0 then raise (Error ebadarg);
  let n = min n errmax in
  let mine = user_read p buf n in
  let mine = try String.sub mine 0 (String.index mine '\000') with Not_found -> String.sub mine 0 (n - 1) in
  let e = if String.length p.errstr >= n then String.sub p.errstr 0 (n - 1) else p.errstr in
  user_write p buf (e ^ "\000");
  p.errstr <- mine;
  0
