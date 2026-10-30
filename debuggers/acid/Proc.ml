(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Proc.mli *)

open Ast

type caps = < Cap.open_in; Cap.open_out; Cap.fork; Cap.exec >

let error fmt = Printf.ksprintf (fun s -> raise (Eval.Error s)) fmt

(*****************************************************************************)
(* The program *)
(*****************************************************************************)

(* the a.out's header (Exe's, -H2): its text at 0x1020, after the
 * header, its data on the page after the text *)
type program = {
  path : string;
  file : string;
  txtaddr : int64;
  txtsz : int64;
  dataddr : int64;
  datsz : int64;
  table : Symbols.t option;
}

let prog : program option ref = ref None

let be32 s o =
  Int64.logor (Int64.shift_left (Int64.of_int (Char.code s.[o])) 24)
    (Int64.of_int ((Char.code s.[o + 1] lsl 16) lor (Char.code s.[o + 2] lsl 8) lor Char.code s.[o + 3]))

let header file path =
  if String.length file < 32 || be32 file 0 <> 0x647L then error "%s: not an arm plan 9 executable" path;
  let text = be32 file 4 and data = be32 file 8 in
  let txtaddr = 0x1020L in
  { path; file; txtaddr; txtsz = text;
    dataddr = Int64.logand (Int64.add (Int64.add txtaddr text) 0xfffL) (Int64.lognot 0xfffL);
    datsz = data; table = Symbols.read file }

(* the symbols of a kind, the text's or the data's *)
let syms text =
  match !prog with
  | Some { table = Some t; _ } ->
      List.filter (fun (s : Symbols.sym) ->
        if text then String.contains "TtLl" s.typ else String.contains "DdBb" s.typ) t.syms
  | _ -> []

(* findsym: the symbol at or below an address, of the text if it is in
 * the text, else of the data *)
let findsym v =
  let text = match !prog with
    | Some p -> v >= p.txtaddr && v < Int64.add p.txtaddr p.txtsz
    | None -> false in
  List.fold_left (fun best (s : Symbols.sym) ->
    let sv = Int64.of_int s.value in
    if sv <= v then (match best with Some (b : Symbols.sym) when b.value >= s.value -> best | _ -> Some s) else best)
    None (syms text)

(* libmach's symoff: name+0xoff, the name alone, or the number (no
 * symbol, or a data symbol 4096 bytes or more below) *)
let symoff v =
  match (if v = 0L then None else findsym v) with
  | None -> Printf.sprintf "0x%Lx" v
  | Some s ->
      let delta = Int64.sub v (Int64.of_int s.value) in
      if s.typ <> 't' && s.typ <> 'T' && delta >= 4096L then Printf.sprintf "0x%Lx" v
      else if delta <> 0L then Printf.sprintf "%s+0x%Lx" s.name delta
      else s.name

(*****************************************************************************)
(* The process *)
(*****************************************************************************)

let pid = ref 0
let mem : Unix.file_descr option ref = ref None
let regs : Unix.file_descr option ref = ref None
let stacktop = ref 0L
(* the processes attached, their ctl files (acid's ptab) *)
let ctls : (int * Unix.file_descr) list ref = ref []

(* arm's Ureg: 18 words *)
let regsize = 72L

let pread fd off n =
  ignore (Unix.LargeFile.lseek fd off Unix.SEEK_SET);
  let b = Bytes.create n in
  let rec go k = if k < n then (match Unix.read fd b k (n - k) with 0 -> k | r -> go (k + r)) else k in
  let k = go 0 in
  Bytes.sub_string b 0 k

let pwrite fd off s =
  ignore (Unix.LargeFile.lseek fd off Unix.SEEK_SET);
  ignore (Unix.write fd (Bytes.of_string s) 0 (String.length s))

(* the maps (libmach's map.c): what is at an address, n bytes *)
let load core addr n =
  let fail () = error "indir: can't translate address 0x%Lx" addr in
  let within lo hi = addr >= lo && Int64.add addr (Int64.of_int n) <= hi in
  let got s = if String.length s < n then fail () else s in
  match !prog, !mem, !regs with
  | Some p, Some m, Some r when core ->
      if within 0L regsize then got (pread r addr n)
      else if within p.txtaddr (Int64.add p.txtaddr p.txtsz) || within p.dataddr !stacktop then got (pread m addr n)
      else fail ()
  | Some p, _, _ ->
      let off =
        if within p.txtaddr (Int64.add p.txtaddr p.txtsz) then Int64.sub addr 0x1000L
        else if within p.dataddr (Int64.add p.dataddr p.datsz) then Int64.add (Int64.add 32L p.txtsz) (Int64.sub addr p.dataddr)
        else fail () in
      String.sub p.file (Int64.to_int off) n
  | None, _, _ -> (if core then error "no map for *" else error "no map for @")

let store addr s =
  match !mem, !regs with
  | Some m, Some r -> if addr < regsize then pwrite r addr s else pwrite m addr s
  | _ -> error "no map for *"

let set name v = Eval.set_global name v

let install (caps : < caps; .. >) p =
  if not (List.mem_assoc p !ctls) then begin
    let fd = try FS.open_rw_fd caps (Printf.sprintf "/proc/%d/ctl" p) with Unix.Unix_error _ -> error "pid=%d: open ctl: process exited" p in
    ctls := (p, fd) :: !ctls;
    set "proclist" (Value.list (List.map (fun (p, _) -> Value.int 'D' (Int64.of_int p)) !ctls))
  end

let deinstall p =
  (match List.assoc_opt p !ctls with Some fd -> (try Unix.close fd with Unix.Unix_error _ -> ()) | None -> ());
  ctls := List.remove_assoc p !ctls;
  set "proclist" (Value.list (List.map (fun (p, _) -> Value.int 'D' (Int64.of_int p)) !ctls));
  if !pid = p then (pid := 0; set "pid" (Value.int 'D' 0L))

(* a message to a process's ctl *)
let msg p m =
  match List.assoc_opt p !ctls with
  | None -> error "msg: pid=%d: not found for %s" p m
  | Some fd ->
      (try ignore (Unix.write fd (Bytes.of_string m) 0 (String.length m))
       with Unix.Unix_error _ -> deinstall p; error "msg: pid=%d %s: process exited" p m)

(* its pending notes, read (and so taken) from its note file *)
let notes (caps : < caps; .. >) p =
  let fd = try FS.open_in_fd caps (Printf.sprintf "/proc/%d/note" p) with Unix.Unix_error _ -> error "pid=%d: open note: process exited" p in
  let rec all acc =
    let b = Bytes.create 128 in
    match Unix.read fd b 0 128 with
    | 0 -> List.rev acc
    | n -> all (Value.string (Bytes.sub_string b 0 n) :: acc)
    | exception Unix.Unix_error _ -> List.rev acc in
  let l = all [] in
  Unix.close fd;
  set "notes" (Value.list l)

let dostop p = Eval.call_if_defined "stopped" [ Value.int 'D' (Int64.of_int p) ]

(* libmach's stacktop: the first line of its segment file, the stack's *)
let top (caps : < caps; .. >) p =
  match FS.read_opt caps (Fpath.v (Printf.sprintf "/proc/%d/segment" p)) with
  | Some s when String.length s > 5 && String.sub s 0 5 = "Stack" ->
      (match List.filter (fun w -> w <> "") (String.split_on_char ' ' (String.sub s 5 (String.length s - 5))) with
       | _ :: t :: _ -> (try Int64.of_string ("0x" ^ t) with Failure _ -> 0L)
       | _ -> 0L)
  | _ -> 0L

let attach (caps : < caps; .. >) p =
  if !prog = None then error "no map";
  let fd name = try FS.open_rw_fd caps (Printf.sprintf "/proc/%d/%s" p name) with Unix.Unix_error _ -> error "setproc: open /proc/%d/%s: process exited" p name in
  (match !mem with Some m -> Unix.close m | None -> ());
  (match !regs with Some r -> Unix.close r | None -> ());
  mem := Some (fd "mem");
  regs := Some (fd "regs");
  stacktop := top caps p;
  pid := p;
  set "pid" (Value.int 'D' (Int64.of_int p));
  install caps p

(*****************************************************************************)
(* The variables *)
(*****************************************************************************)

(* principia's 5db: the registers, their offsets in the Ureg *)
let reglist = [
  "TYPE", 60; "PSR", 64; "PC", 68; "SP", 52; "R15", 68; "R14", 56; "R13", 52; "R12", 48; "R11", 44;
  "R10", 40; "R9", 36; "R8", 32; "R7", 28; "R6", 24; "R5", 20; "R4", 16; "R3", 12; "R2", 8; "R1", 4; "R0", 0 ]

let registers () =
  List.iter (fun (name, off) -> set name (Value.int 'X' (Int64.of_int off))) reglist;
  set "registers" (Value.list (List.map (fun (n, _) -> Value.string n) reglist));
  (* 5db's bpinst, BKPT *)
  set "bpinst" (Value.string "\x70\x00\x20\xe1")

let program (caps : < caps; .. >) path =
  let file = match FS.read_opt caps (Fpath.v path) with Some f -> f | None -> error "%s: can't open %s: file does not exist" path path in
  prog := Some (header file path);
  Eval.print [ Value.string (path ^ ":arm plan 9 executable") ];
  set "objtype" (Value.string "arm");
  set "textfile" (Value.string path);
  registers ()

let symbols () =
  let l = List.filter_map (fun (s : Symbols.sym) ->
    if String.contains "TLDBbdlt" s.typ && s.name <> "" && s.name.[0] <> '.' then begin
      set s.name (Value.int 'X' (Int64.of_int s.value));
      Some (Value.list [ Value.string s.name; Value.int 'c' (Int64.of_int (Char.code s.typ)); Value.int 'X' (Int64.of_int s.value) ])
    end else None)
    (match !prog with Some { table = Some t; _ } -> t.syms | _ -> []) in
  set "symbols" (Value.list l);
  if l = [] then Eval.print [ Value.string "no symbol information" ]

(*****************************************************************************)
(* The builtins *)
(*****************************************************************************)

let int name = function [ { kind = Int i; _ } ] -> i | _ -> error "%s(integer)" name

(* 5db's armexcep: a trap's name by the Ureg's type *)
let excep t =
  match Int64.to_int t land 0x1f with
  | 0x11 -> "Fiq interrupt" | 0x12 -> "Mirq interrupt" | 0x13 -> "SVC/SWI Exception"
  | 0x17 -> "Prefetch Abort/Breakpoint" | 0x18 -> "Data Abort"
  | 0x1b -> "Undefined instruction/Breakpoint" | 0x1f -> "Sys trap" | _ -> "Undefined trap"

(* the function around an address: its start, and the next's *)
let fnbound v =
  let fs = List.sort compare (List.map (fun (s : Symbols.sym) -> Int64.of_int s.value) (syms true)) in
  let rec go = function
    | a :: (b :: _ as rest) -> if a <= v && v < b then Some (a, b) else go rest
    | _ -> None in
  go fs

let file_line v =
  match !prog with
  | Some { table = Some t; _ } -> Symbols.file_line t (Int64.to_int v)
  | _ -> None

(* the instructions that may run after the one at an address (machdata's
 * foll): a branch's target and, conditional, the next; the next *)
let follow v =
  if !mem = None then error "follow(addr): can't read instruction: get4: invalid map";
  let w = !Eval.load true v 4 in
  let ins = Int64.to_int (be32 (String.init 4 (fun i -> w.[3 - i])) 0) in
  let next = Int64.add v 4L in
  if (ins lsr 25) land 7 = 5 then begin
    let off = ins land 0xffffff in
    let off = if off land 0x800000 <> 0 then off - 0x1000000 else off in
    let target = Int64.add v (Int64.of_int (8 + (off * 4))) in
    if ins lsr 28 = 0xe then [ target ] else [ target; next ]
  end else [ next ]

(* libmach's risctrace: the frames from (pc, sp, link), each the list
 * {its function, where it was called from (the return less 8, arm's
 * pc), its parameters, its locals}, each of those {name, value}: a
 * function's frame its .frame (0 at its first instruction), its return
 * address the link's (a leaf, or before its save) or the word at its
 * sp; to _main, not said, 40 frames at most *)
let strace pc sp link =
  let entries = match !prog with Some { table = Some t; _ } -> t.syms | _ -> [] in
  (* a function's symbol, and the entries after it (.frame, its
   * parameters p, its locals a), to the next function *)
  let rec locals = function
    | (s : Symbols.sym) :: rest when not (String.contains "TtLl" s.typ) -> s :: locals rest
    | _ -> [] in
  let rec find_fn v = function
    | (s : Symbols.sym) :: rest when String.contains "TtLl" s.typ && Int64.of_int s.value = v -> Some (s, locals rest)
    | _ :: rest -> find_fn v rest
    | [] -> None in
  let word a = let w = !Eval.load true a 4 in Int64.of_string ("0x" ^ String.concat "" (List.map (fun i -> Printf.sprintf "%02x" (Char.code w.[i])) [ 3; 2; 1; 0 ])) in
  let var name v = Value.list [ Value.string name; Value.int 'X' v ] in
  let in_text v = match !prog with Some p -> v >= p.txtaddr && v < Int64.add p.txtaddr p.txtsz | None -> false in
  let rec go pc sp n acc =
    match (if in_text pc then findsym pc else None) with
    | Some (s : Symbols.sym) when n <= 40 && s.name <> "_main" && s.name <> "_mainp" ->
        let start = Int64.of_int s.value in
        let autos = match find_fn start entries with Some (_, l) -> l | None -> [] in
        let frame = if pc = start then Some 0L else
          (match List.find_opt (fun (e : Symbols.sym) -> e.typ = 'm' && e.name = ".frame") autos with
           | Some e -> Some (Int64.of_int e.value) | None -> None) in
        (match frame with
         | None -> List.rev acc
         | Some size ->
             let next = if s.typ = 'L' || s.typ = 'l' || pc <= Int64.add start 4L then Some link
               else (try Some (word sp) with Eval.Error _ -> None) in
             (match next with
              | None -> List.rev acc
              | Some ret ->
                  if ret = 0L || (ret = pc && size = 0L) then List.rev acc
                  else begin
                    let sp = Int64.add sp size in
                    let read off = try Some (word off) with Eval.Error _ -> None in
                    let pick typ f = List.filter_map (fun (e : Symbols.sym) ->
                      if e.typ = typ && e.name <> "" && e.name.[0] <> '.' then
                        Option.map (var e.name) (read (f (Int64.of_int e.value))) else None) autos in
                    (* (libmach's localsym: the table's order reversed, the
                     * last written first) *)
                    let params = List.rev (pick 'p' (fun o -> Int64.add (Int64.add sp 4L) o)) in
                    let locals = List.rev (pick 'a' (fun o -> Int64.sub sp o)) in
                    let fr = Value.list [ Value.int 'X' start; Value.int 'Y' (Int64.sub ret 8L); Value.list params; Value.list locals ] in
                    go ret sp (n + 1) (fr :: acc)
                  end))
    | _ -> List.rev acc in
  match go pc sp 0 [] with
  | [] -> error "no stack frame"
  | frames -> Value.list frames

let attached () = List.map fst !ctls

let init (caps : < caps; .. >) =
  Eval.load := load;
  Eval.store := store;
  Eval.symbol := symoff;
  let def name f = Hashtbl.replace Eval.builtins name f in
  let none = Value.empty in
  def "setproc" (fun vs -> attach caps (Int64.to_int (int "setproc" vs)); none);
  def "start" (fun vs -> msg (Int64.to_int (int "start" vs)) "start"; none);
  let stopping name = def name (fun vs ->
    let p = Int64.to_int (int name vs) in
    msg p name; notes caps p; dostop p; none) in
  stopping "stop"; stopping "startstop"; stopping "waitstop";
  def "kill" (fun vs -> let p = Int64.to_int (int "kill" vs) in msg p "kill"; deinstall p; none);
  def "status" (fun vs ->
    let p = Int64.to_int (int "status" vs) in
    match FS.read_opt caps (Fpath.v (Printf.sprintf "/proc/%d/status" p)) with
    | Some s ->
        (match List.filter (fun w -> w <> "") (String.split_on_char ' ' s) with
         | _ :: _ :: state :: _ -> Value.string state
         | _ -> error "bad status for %d" p)
    | None -> error "open /proc/%d/status: process exited" p);
  def "reason" (fun vs -> Value.string (excep (int "reason" vs)));
  def "fnbound" (fun vs ->
    match fnbound (int "fnbound" vs) with
    | Some (a, b) -> Value.list [ Value.int 'X' a; Value.int 'X' b ]
    | None -> none);
  def "pcfile" (fun vs -> match file_line (int "pcfile" vs) with Some (f, _) -> Value.string f | None -> Value.string "?file?");
  def "pcline" (fun vs -> match file_line (int "pcline" vs) with Some (_, l) -> Value.int 'D' (Int64.of_int l) | None -> Value.int 'D' 0L);
  def "strace" (function
    | [ { kind = Int pc; _ }; { kind = Int sp; _ }; { kind = Int link; _ } ] -> strace pc sp link
    | [ _; _; _ ] -> error "strace(pc, sp, link): bad type"
    | _ -> error "strace(pc, sp, link): arg count");
  def "follow" (fun vs -> Value.list (List.map (Value.int 'X') (follow (int "follow" vs))));
  def "newproc" (fun vs ->
    let aout = match !prog with Some p -> p.path | None -> error "no program" in
    let args = match vs with
      | [ { kind = String s; _ } ] -> List.filter (fun w -> w <> "") (String.split_on_char ' ' (String.map (fun c -> if c = '\t' then ' ' else c) s))
      | [] -> []
      | _ -> error "newproc(string)" in
    match CapUnix.fork caps () with
    | 0 ->
        (try
          let fd = FS.open_rw_fd caps (Printf.sprintf "/proc/%d/ctl" (Unix.getpid ())) in
          ignore (Unix.write fd (Bytes.of_string "hang") 0 4);
          Unix.close fd;
          CapUnix.execv caps aout (Array.of_list (aout :: args)); exit 1
        with _ -> exit 1)
    | child ->
        install caps child;
        msg child "waitstop";
        notes caps child;
        attach caps child;
        dostop child;
        Value.int 'D' (Int64.of_int child))
