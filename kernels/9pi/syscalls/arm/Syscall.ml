(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Syscall.mli *)

open Types
open Errors
open Usermem

(*****************************************************************************)
(* Notes (arm's notify and noted) *)
(*****************************************************************************)

let nframe = 216
let ureg_off = 144
let old_off = 140
let msg_off = 12

(* the process's trap frame as a Ureg (r0-r12, sp, link, type, psr, pc),
 * its words as they are *)
let ureg_bytes typ =
  let t = Ureg.regs () in
  String.sub t 0 (15 * 4) ^ Machine.le32 typ ^ String.sub t (16 * 4) 4 ^ String.sub t (15 * 4) 4

(* an address the process may use: in one of its segments *)
let okaddr (p : proc) a = List.exists (fun s -> a >= s.base && a < s.top) p.segs

(* What a process that dies of a trap was doing, said after its
 * "suicide" line: where its function returns (lr), its stack pointer,
 * and the stack's words that are addresses of its code, the first 16
 * from the top: the functions that called, most likely (a word that
 * only looks like one is there too: no frame pointer says which are
 * returns). The pc alone says where, not how one came there (the
 * author's Pi1, 2026-10-08: "suicide: sys: trap: fault read va=0x35
 * pc=0x103ee4", a game in a window, and nothing more to go on). The
 * addresses are a program's own: its linker's symbols name them.
 * Not Plan 9's: a line more than 9pi's, [traced] false for its words
 * alone (the sessions recorded from it take the line out). *)
let traced = ref true

let trace (p : proc) =
  if !traced then begin
    let sp = Ureg.get Ureg.sp in
    let found = ref [] and n = ref 0 in
    (match List.find_opt (fun s -> s.kind = Text) p.segs, List.find_opt (fun s -> sp >= s.base && sp < s.top) p.segs with
     | Some text, Some stack ->
         (try
           let a = ref (sp land lnot 3) in
           while !n < 16 && !a + 4 <= stack.top && !a < sp + 8192 do
             let w = user_read p !a 4 in
             let v = Char.code w.[0] lor (Char.code w.[1] lsl 8) lor (Char.code w.[2] lsl 16) lor (Char.code w.[3] lsl 24) in
             if v >= text.base && v < text.top then begin found := v :: !found; incr n end;
             a := !a + 4
           done
         with Error _ -> ())
     | _ -> ());
    Sysproc.pprint p (Printf.sprintf "trace: lr=0x%x sp=0x%x:%s\n" (Ureg.get Arch.tf_lr) sp
                        (String.concat "" (List.rev_map (fun (v : int) -> Printf.sprintf " 0x%x" v) !found)))
  end

(* a pending note delivered on the way back to user mode (notify): to
 * the handler, on an NFrame below the user's sp; without one, or
 * already in it, a trap's or kill's note ends the process *)
let notify (p : proc) typ =
  match p.notes with
  | [] -> ()
  | (msg, flag) :: rest ->
      p.notepending <- false;
      let msg =
        if String.length msg >= 4 && String.sub msg 0 4 = "sys:" then
          (if String.length msg > errmax - 23 then String.sub msg 0 (errmax - 23) else msg)
          ^ Printf.sprintf " pc=0x%x" (Ureg.get Ureg.pc)
        else msg in
      if flag <> Nuser && (p.notified || p.notify = 0) then begin
        if flag = Ndebug then begin Sysproc.pprint p ("suicide: " ^ msg ^ "\n"); trace p end;
        Sysproc.exits p msg
      end
      else if p.notified then ()
      else if p.notify = 0 then Sysproc.exits p msg
      else if not (okaddr p p.notify) then begin
        Sysproc.pprint p (Printf.sprintf "suicide: notify function address 0x%x\n" p.notify);
        Sysproc.exits p "Suicide"
      end else begin
        let sp = Ureg.get Ureg.sp - nframe in
        let m = if String.length msg >= errmax then String.sub msg 0 (errmax - 1) else msg in
        let frame = Machine.le32 0 ^ Machine.le32 (sp + ureg_off) ^ Machine.le32 (sp + msg_off)
                    ^ m ^ String.make (errmax - String.length m) '\000' ^ Machine.le32 p.ureg ^ ureg_bytes typ in
        (try user_write p sp frame
         with Error _ -> Sysproc.pprint p (Printf.sprintf "suicide: notify stack address 0x%x\n" sp); Sysproc.exits p "Suicide");
        p.ureg <- sp;
        Ureg.set Ureg.r0 (sp + ureg_off);
        Ureg.set Ureg.sp sp;
        Ureg.set Ureg.pc p.notify;
        p.notified <- true;
        p.notes <- rest;
        p.lastnote <- (msg, flag)
      end

(* noted (arch__noted): back from the handler, the frame's registers
 * restored (not the PSR: its flags stay the current ones, as
 * arch__noted's mask keeps) *)
let noted (p : proc) arg0 =
  if arg0 <> Sysproc.nrstr && not p.notified then begin
    Sysproc.pprint p "call to noted() when not notified\n";
    Sysproc.exits p "Suicide"
  end;
  p.notified <- false;
  let nf = p.ureg in
  let f = try user_read p nf nframe with Error _ -> Sysproc.pprint p (Printf.sprintf "bad ureg in noted 0x%x\n" nf); Sysproc.exits p "Suicide"; "" in
  let ur = String.sub f ureg_off 72 in
  let get i = Machine.get_le32 ur (4 * i) in
  let back () = Ureg.set_regs (String.sub ur 0 (15 * 4) ^ String.sub ur (17 * 4) 4) in
  if arg0 = Sysproc.ncont || arg0 = Sysproc.nrstr then begin
    if not (okaddr p (get 17)) || not (okaddr p (get 13)) then begin Sysproc.pprint p "suicide: trap in noted\n"; Sysproc.exits p "Suicide" end;
    back ();
    p.ureg <- Machine.get_le32 f old_off
  end
  else if arg0 = Sysproc.nsave then begin
    if not (okaddr p (get 17)) || not (okaddr p (get 13)) then begin Sysproc.pprint p "suicide: trap in noted\n"; Sysproc.exits p "Suicide" end;
    back ();
    user_write p nf (Machine.le32 0 ^ Machine.le32 (nf + ureg_off) ^ Machine.le32 (nf + msg_off));
    Ureg.set Ureg.sp nf;
    Ureg.set Ureg.r0 (nf + ureg_off)
  end
  else begin
    back ();
    let msg, flag = p.lastnote in
    let flag = if arg0 <> Sysproc.ndflt then begin Sysproc.pprint p (Printf.sprintf "unknown noted arg 0x%x\n" arg0); Ndebug end else flag in
    if flag = Ndebug then begin Sysproc.pprint p ("suicide: " ^ msg ^ "\n"); trace p end;
    Sysproc.exits p msg
  end

(* a trap's note (NDebug), delivered at once *)
let trap (p : proc) msg typ =
  ignore (Proc.postnote p msg Ndebug);
  notify p typ

(*****************************************************************************)
(* The call *)
(*****************************************************************************)

(* a trace of the calls on the console (Main's [trace]): a debugging
 * aid, off *)
let trace = ref false

let syscall (p : proc) =
  let nr = Ureg.get Ureg.r0 in
  let ret =
    try
      if nr < 0 || nr >= Array.length Systab.calls then raise (Error ebadarg);
      let c, name = Systab.calls.(nr) in
      let sp = Ureg.get Ureg.sp in
      let words = user_read p (sp + 4) 20 in
      let a = Array.init 5 (fun i -> Machine.get_le32 words (4 * i)) in
      p.psstate <- name;
      let traced = !trace in
      if traced then Devcons.print (Printf.sprintf "[%d %s %x %x %x]" p.pid name a.(0) a.(1) a.(2));
      let r =
        try Systab.call p c a words
        with Error "not yet" as e -> Devcons.print ("mini-9pi: " ^ String.lowercase name ^ ": not yet\n"); raise e in
      p.psstate <- "";
      if traced then Devcons.print (Printf.sprintf "[%d = %d]\n" p.pid r);
      r
    with Error e ->
      if !trace && nr = 2 then Devcons.print (Printf.sprintf "[%d error %s]\n" p.pid e);
      p.psstate <- "";
      p.errstr <- (if String.length e >= errmax then String.sub e 0 (errmax - 1) else e);
      -1 in
  Ureg.set Ureg.r0 ret;
  (* noted's frame restored; a note delivered (not to rfork's parent
   * right away: arch__syscall's exception) *)
  (match !Sysproc.noted_arg with Some x -> Sysproc.noted_arg := None; noted p x | None -> ());
  if nr <> 1 then notify p 0x13
