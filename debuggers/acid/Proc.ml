(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Proc.mli *)

open Ast

type caps = < Cap.open_in; Cap.open_out; Cap.fork; Cap.exec; Cap.kill >

let error fmt = Printf.ksprintf (fun s -> raise (Eval.Error s)) fmt

(*****************************************************************************)
(* The program *)
(*****************************************************************************)

(* the a.out's header (Exe's, -H2): its text at 0x1020, after the
 * header, its data on the page after the text; or an ELF's (Linux's:
 * gcc's, mini-ld -H7's), its loads', its symbols moved by bias once a
 * process of it runs (a PIE's, gcc's default, is put anywhere) *)
type program = {
  path : string;
  file : string;
  txtaddr : int64;
  txtsz : int64;
  dataddr : int64;
  datsz : int64;
  table : Symbols.t option;
  arch : string;            (* arm, arm64 *)
  elf : Elf_file.t option;
  bias : int64;
}

let prog : program option ref = ref None

(* the disassembler's symbols, the program's *)
let das_table = ref (Das.table [])

let be32 s o =
  Int64.logor (Int64.shift_left (Int64.of_int (Char.code s.[o])) 24)
    (Int64.of_int ((Char.code s.[o + 1] lsl 16) lor (Char.code s.[o + 2] lsl 8) lor Char.code s.[o + 3]))

let elf_header file path (e : Elf_file.t) =
  let seg = function Some (g : Elf_file.segment) -> Int64.of_int g.vaddr, Int64.of_int g.filesz | None -> 0L, 0L in
  let txtaddr, txtsz = seg (Elf_file.text_segment e) and dataddr, datsz = seg (Elf_file.data_segment e) in
  let syms = Elf_file.symbols file e in
  let arch = match e.machine with 183 -> "arm64" | 40 -> "arm" | m -> error "%s: an ELF of machine %d, not arm's nor arm64's" path m in
  { path; file; txtaddr; txtsz; dataddr; datsz; arch; elf = Some e; bias = 0L;
    table = Some { syms; text_start = Int64.to_int txtaddr; text_end = Int64.to_int (Int64.add txtaddr txtsz); lines = "" } }

let header file path =
  match Elf_file.read file with
  | Some e -> elf_header file path e
  | None ->
  if String.length file < 32 || be32 file 0 <> 0x647L then error "%s: not an arm plan 9 executable" path;
  let text = be32 file 4 and data = be32 file 8 in
  let txtaddr = 0x1020L in
  { path; file; txtaddr; txtsz = text;
    dataddr = Int64.logand (Int64.add (Int64.add txtaddr text) 0xfffL) (Int64.lognot 0xfffL);
    datsz = data; table = Symbols.read file; arch = "arm"; elf = None; bias = 0L }

let arm64 () = match !prog with Some p -> p.arch = "arm64" | None -> false

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

(* libmach's symoff (the a format): name+0xoff, the name, or the number;
 * on arm64 an address of 64 bits (Das's are 5db's, 32) *)
let symoff v =
  if (match !prog with Some p -> p.arch = "arm64" | None -> false) then
    match (if v = 0L then None else findsym v) with
    | Some s when Int64.sub v (Int64.of_int s.value) = 0L -> s.name
    | Some s when String.contains "Tt" s.typ || Int64.sub v (Int64.of_int s.value) < 4096L ->
        Printf.sprintf "%s+0x%Lx" s.name (Int64.sub v (Int64.of_int s.value))
    | _ -> Printf.sprintf "0x%Lx" v
  else Das.symoff !das_table false v

(*****************************************************************************)
(* The process *)
(*****************************************************************************)

let pid = ref 0
let mem : Unix.file_descr option ref = ref None
let regs : Unix.file_descr option ref = ref None
let stacktop = ref 0L
(* the processes attached, their ctl files (acid's ptab); on Linux
 * none, the process's ptrace's *)
let ctls : (int * Unix.file_descr option) list ref = ref []

(* Linux: a process's last stop, its signal (TYPE in its registers) *)
let linux = Ptrace.available
let stops : (int * int) list ref = ref []

(* arm's Ureg: 18 words; arm64's user_pt_regs on Linux (x0 to x30, sp,
 * pc, pstate: 34 words) and TYPE after it, the signal *)
let regsize () = if arm64 () then 280L else 72L

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
  | Some _, Some m, None when core && linux ->
      if within 0L (regsize ()) then
        let r = Ptrace.getregs !pid ^ Bytes.to_string (let b = Bytes.make 8 '\000' in Bytes.set_int64_le b 0 (Int64.of_int (match List.assoc_opt !pid !stops with Some s -> s | None -> 0)); b) in
        String.sub r (Int64.to_int addr) n
      else got (pread m addr n)
  | Some p, Some m, Some r when core ->
      if within 0L (regsize ()) then got (pread r addr n)
      else if within p.txtaddr (Int64.add p.txtaddr p.txtsz) || within p.dataddr !stacktop then got (pread m addr n)
      else fail ()
  | Some ({ elf = Some e; _ } as p), _, _ ->
      (match Elf_file.file_offset e (Int64.to_int (Int64.sub addr p.bias)) with
       | Some off when off + n <= String.length p.file -> String.sub p.file off n
       | _ -> fail ())
  | Some p, _, _ ->
      let off =
        if within p.txtaddr (Int64.add p.txtaddr p.txtsz) then Int64.sub addr 0x1000L
        else if within p.dataddr (Int64.add p.dataddr p.datsz) then Int64.add (Int64.add 32L p.txtsz) (Int64.sub addr p.dataddr)
        else fail () in
      String.sub p.file (Int64.to_int off) n
  | None, _, _ -> (if core then error "no map for *" else error "no map for @")

let store addr s =
  match !mem, !regs with
  | Some m, None when linux ->
      if addr < 272L then begin
        let r = Bytes.of_string (Ptrace.getregs !pid) in
        Bytes.blit_string s 0 r (Int64.to_int addr) (min (String.length s) (272 - Int64.to_int addr));
        Ptrace.setregs !pid (Bytes.to_string r)
      end
      else if addr >= regsize () then pwrite m addr s
  | Some m, Some r -> if addr < regsize () then pwrite r addr s else pwrite m addr s
  | _ -> error "no map for *"

let set name v = Eval.set_global name v

let install (caps : < caps; .. >) p =
  if not (List.mem_assoc p !ctls) then begin
    let fd = if linux then None else
      Some (try FS.open_rw_fd caps (Printf.sprintf "/proc/%d/ctl" p) with Unix.Unix_error _ -> error "pid=%d: open ctl: process exited" p) in
    ctls := (p, fd) :: !ctls;
    set "proclist" (Value.list (List.map (fun (p, _) -> Value.int 'D' (Int64.of_int p)) !ctls))
  end

let deinstall p =
  (match List.assoc_opt p !ctls with Some (Some fd) -> (try Unix.close fd with Unix.Unix_error _ -> ()) | _ -> ());
  stops := List.remove_assoc p !stops;
  ctls := List.remove_assoc p !ctls;
  set "proclist" (Value.list (List.map (fun (p, _) -> Value.int 'D' (Int64.of_int p)) !ctls));
  if !pid = p then (pid := 0; set "pid" (Value.int 'D' 0L))

(* Linux: a ctl message by ptrace; a stop's signal kept (a breakpoint's
 * SIGTRAP is not given back to the process at the next start, another
 * is: a SIGSEGV kills it then, as without a debugger) *)
let linux_msg (caps : < caps; .. >) p m =
  let wait () =
    match Ptrace.wait p with
    | s when s > 0 -> stops := (p, s) :: List.remove_assoc p !stops
    | _ -> deinstall p; error "msg: pid=%d %s: process exited" p m in
  let start () =
    let s = match List.assoc_opt p !stops with Some s when s <> 5 && s <> 19 -> s | _ -> 0 in
    stops := List.remove_assoc p !stops;
    (try Ptrace.cont p s with Failure _ -> deinstall p; error "msg: pid=%d %s: process exited" p m) in
  match m with
  | "start" -> start ()
  | "startstop" -> start (); wait ()
  | "waitstop" -> if not (List.mem_assoc p !stops) then wait ()
  | "stop" -> if not (List.mem_assoc p !stops) then (Ptrace.signal caps p 19; wait ())
  | "kill" -> Ptrace.signal caps p 9; (try ignore (Ptrace.wait p) with Failure _ -> ())
  | _ -> error "msg: pid=%d: %s: not on Linux" p m

(* a message to a process's ctl *)
let msg (caps : < caps; .. >) p m =
  match List.assoc_opt p !ctls with
  | None -> error "msg: pid=%d: not found for %s" p m
  | Some None -> linux_msg caps p m
  | Some (Some fd) ->
      (try ignore (Unix.write fd (Bytes.of_string m) 0 (String.length m))
       with Unix.Unix_error _ -> deinstall p; error "msg: pid=%d %s: process exited" p m)

(* Linux's signals as Plan 9's notes say them *)
let signame = function
  | 5 -> "sys: breakpoint" | 11 -> "sys: trap: fault (SIGSEGV)" | 7 -> "sys: trap: bus error (SIGBUS)"
  | 4 -> "sys: trap: illegal instruction (SIGILL)" | 8 -> "sys: trap: arithmetic (SIGFPE)" | 6 -> "sys: abort (SIGABRT)"
  | 19 -> "sys: stop (SIGSTOP)" | 2 -> "interrupt (SIGINT)" | s -> Printf.sprintf "signal %d" s

(* its pending notes, read (and so taken) from its note file *)
let notes (caps : < caps; .. >) p =
  if linux then set "notes" (Value.list (match List.assoc_opt p !stops with Some s -> [ Value.string (signame s) ] | None -> []))
  else
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

(* Linux's maps, each {name, base, end, offset} (/proc/$pid/maps) *)
let linux_maps (caps : < caps; .. >) p =
  match FS.read_opt caps (Fpath.v (Printf.sprintf "/proc/%d/maps" p)) with
  | None -> []
  | Some s ->
      List.filter_map (fun l ->
        match List.filter (fun w -> w <> "") (String.split_on_char ' ' l) with
        | range :: perms :: off :: _ :: _ :: rest when String.length perms > 0 && perms.[0] = 'r' ->
            (match String.index_opt range '-' with
             | Some i ->
                 let hex x = Int64.of_string ("0x" ^ x) in
                 Some ((match rest with n :: _ -> n | [] -> "anon"), hex (String.sub range 0 i),
                       hex (String.sub range (i + 1) (String.length range - i - 1)), hex off)
             | None -> None)
        | _ -> None) (String.split_on_char '\n' s)

(* libmach's stacktop: the first line of its segment file, the stack's *)
let top (caps : < caps; .. >) p =
  if linux then (match List.find_opt (fun (n, _, _, _) -> n = "[stack]") (linux_maps caps p) with Some (_, _, e, _) -> e | None -> 0L)
  else
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
  regs := if linux then None else Some (fd "regs");
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

(* arm64's on Linux, user_pt_regs': R29 the frame pointer, R30 the
 * link; TYPE ours, the stop's signal *)
let reglist64 =
  [ "TYPE", 272; "PSR", 264; "PC", 256; "SP", 248; "LR", 240; "FP", 232 ]
  @ List.init 31 (fun i -> Printf.sprintf "R%d" (30 - i), 8 * (30 - i))

let regs_of () = if arm64 () then reglist64 else reglist

let registers () =
  List.iter (fun (name, off) -> set name (Value.int (if arm64 () then 'Y' else 'X') (Int64.of_int off))) (regs_of ());
  set "registers" (Value.list (List.map (fun (n, _) -> Value.string n) (regs_of ())));
  (* 5db's bpinst, BKPT; arm64's BRK #0 *)
  set "bpinst" (Value.string (if arm64 () then "\x00\x00\x20\xd4" else "\x70\x00\x20\xe1"))

let program (caps : < caps; .. >) path =
  let file = match FS.read_opt caps (Fpath.v path) with Some f -> f | None -> error "%s: can't open %s: file does not exist" path path in
  let p = header file path in
  prog := Some p;
  das_table :=
    Das.table (match p.table with Some (t : Symbols.t) -> t.syms | None -> []);
  Eval.print [ Value.string (path ^ (if p.elf <> None then ":" ^ p.arch ^ " linux executable" else ":arm plan 9 executable")) ];
  set "objtype" (Value.string p.arch);
  set "textfile" (Value.string path);
  registers ()

(* the program's own declarations of its types, acid's text, if it has
 * them (mini-ld -g's .acid: decision 14 of plan_debugger.md), from
 * its file *)
let declarations () =
  match !prog with
  | Some ({ table = Some t; _ } as p) ->
      (match List.find_opt (fun (s : Symbols.sym) -> s.name = ".acid" && String.contains "Dd" s.typ) t.syms with
       | Some s ->
           let off = Int64.to_int (Int64.add (Int64.add 32L p.txtsz) (Int64.sub (Int64.of_int s.value) p.dataddr)) in
           (match String.index_from_opt p.file off '\000' with
            | Some e when off >= 0 -> Some (String.sub p.file off (e - off))
            | _ -> None)
       | None -> None)
  | _ -> None

let symbols () =
  let l = List.filter_map (fun (s : Symbols.sym) ->
    if String.contains "TLDBbdlt" s.typ && s.name <> "" && s.name.[0] <> '.' then begin
      (* (a complex variable's address its format a: acid's symbols,
       * read after the libraries, 5c -a's complex T name among them) *)
      set s.name (Value.int (if Eval.complex_type s.name <> None then 'a' else 'X') (Int64.of_int s.value));
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

(* a word at an address, little-endian, of the process (core) or of
 * the program's file *)
let word core a =
  let w = !Eval.load core a 4 in
  List.fold_left (fun v k ->
    Int64.logor (Int64.shift_left v 8) (Int64.of_int (Char.code w.[k])))
    0L [ 3; 2; 1; 0 ]

let get core a = try Some (word core a) with Eval.Error _ -> None

(* a register's value, from the Ureg or user_pt_regs: 8 bytes on arm64 *)
let reg name =
  match List.assoc_opt name (regs_of ()) with
  | Some off when arm64 () -> Bytes.get_int64_le (Bytes.of_string (!Eval.load true (Int64.of_int off) 8)) 0
  | Some off -> word true (Int64.of_int off)
  | None -> error "rget: %s" name

let instruction core a =
  if arm64 () then Some (Das_arm64.instruction symoff (get core) a) else Das.instruction !das_table (get core) a

(* the instruction that runs after the one at an address (machdata's
 * foll, 5db's: its condition evaluated), the registers read from the
 * Ureg *)
let follow v =
  if !mem = None then error "follow(addr): can't read instruction: get4: invalid map";
  match (if arm64 () then Das_arm64.follow (get true) reg v else Das.follow (get true) reg v) with
  | Some a -> [ a ]
  | None -> error "follow(addr): can't read instruction"

(* libmach's risctrace: the frames from (pc, sp, link), each its
 * function's symbol, its table's entries (.frame, parameters p, locals
 * a), its sp once its frame is left, its return address: a function's
 * frame its .frame (0 at its first instruction), its return address the
 * link's (a leaf, or before its save) or the word at its sp; to _main,
 * not said, 40 frames at most *)
let walk pc sp link =
  let entries = match !prog with Some { table = Some t; _ } -> t.syms | _ -> [] in
  (* a function's symbol, and the entries after it, to the next function *)
  let rec locals = function
    | (s : Symbols.sym) :: rest when not (String.contains "TtLl" s.typ) -> s :: locals rest
    | _ -> [] in
  let rec find_fn v = function
    | (s : Symbols.sym) :: rest when String.contains "TtLl" s.typ && Int64.of_int s.value = v -> Some (s, locals rest)
    | _ :: rest -> find_fn v rest
    | [] -> None in
  let word a = word true a in
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
                  else let sp = Int64.add sp size in go ret sp (n + 1) ((s, autos, sp, ret) :: acc)))
    | _ -> List.rev acc in
  go pc sp 0 []

(* a parameter's address, past the return address over the frame; a
 * local's, under the frame's top *)
let param_addr sp off = Int64.add (Int64.add sp 4L) (Int64.of_int off)
let auto_addr sp off = Int64.sub sp (Int64.of_int off)

(* the frames as acid's lists: {its function, where it was called from
 * (the return less 8, arm's pc), its parameters, its locals}, each of
 * those {name, value} *)
let strace pc sp link =
  (* (arm64's: no table of the frames' parameters and locals yet) *)
  if arm64 () then Value.empty else
  let var name v = Value.list [ Value.string name; Value.int 'X' v ] in
  let frame ((s : Symbols.sym), autos, sp, ret) =
    let read off = try Some (word true off) with Eval.Error _ -> None in
    let pick typ f = List.filter_map (fun (e : Symbols.sym) ->
      if e.typ = typ && e.name <> "" && e.name.[0] <> '.' then
        Option.map (var e.name) (read (f sp e.value)) else None) autos in
    (* (libmach's localsym: the table's order reversed, the last
     * written first) *)
    let params = List.rev (pick 'p' param_addr) in
    let locals = List.rev (pick 'a' auto_addr) in
    Value.list [ Value.int 'X' (Int64.of_int s.value); Value.int 'Y' (Int64.sub ret 8L); Value.list params; Value.list locals ] in
  match walk pc sp link with
  | [] -> error "no stack frame"
  | frames -> Value.list (List.map frame frames)

(* f:v, libmach's localaddr: v's address in the innermost frame of f,
 * from the stopped process's registers *)
let local_addr f v =
  if !mem = None then error "colon: no process";
  if arm64 () then error "colon: %s:%s: no table of arm64's locals" f v;
  match List.find_opt (fun ((s : Symbols.sym), _, _, _) -> s.name = f) (walk (reg "PC") (reg "SP") (reg "R14")) with
  | None -> error "colon: function %s not in the stack" f
  | Some (_, autos, sp, _) ->
      match List.find_opt (fun (e : Symbols.sym) -> e.name = v && (e.typ = 'p' || e.typ = 'a')) autos with
      | Some e when e.typ = 'p' -> param_addr sp e.value
      | Some e -> auto_addr sp e.value
      | None -> error "colon: %s has no local %s" f v

(* a PIE's symbols moved where Linux put it: its entry's address,
 * auxv's AT_ENTRY, less the file's *)
let rebias (caps : < caps; .. >) p =
  match !prog with
  | Some ({ elf = Some e; table = Some t; _ } as pr) ->
      let auxv = match FS.read_opt caps (Fpath.v (Printf.sprintf "/proc/%d/auxv" p)) with Some a -> a | None -> "" in
      let rec entry o = if o + 16 > String.length auxv then None
        else let b = Bytes.of_string (String.sub auxv o 16) in
          if Bytes.get_int64_le b 0 = 9L then Some (Bytes.get_int64_le b 8) else entry (o + 16) in
      (match entry 0 with
       | Some a when Int64.sub a (Int64.of_int e.entry) <> pr.bias ->
           let b = Int64.sub a (Int64.of_int e.entry) in
           let d = Int64.to_int (Int64.sub b pr.bias) in
           let t = { t with syms = List.map (fun (s : Symbols.sym) -> { s with value = s.value + d }) t.syms;
                            text_start = t.text_start + d; text_end = t.text_end + d } in
           prog := Some { pr with bias = b; table = Some t; txtaddr = Int64.add pr.txtaddr (Int64.of_int d);
                                  dataddr = Int64.add pr.dataddr (Int64.of_int d) };
           das_table := Das.table t.syms;
           symbols ()
       | _ -> ())
  | _ -> ()

let attached () = List.map fst !ctls

let init (caps : < caps; .. >) =
  (* (a process gone between two reads: acid's error, not a crash) *)
  let exited f = try f () with Unix.Unix_error _ -> error "process exited" in
  Eval.load := (fun core a n -> exited (fun () -> load core a n));
  Eval.store := (fun a s -> exited (fun () -> store a s));
  Eval.symbol := symoff;
  Eval.local_addr := local_addr;
  Value.das := instruction;
  let def name f = Hashtbl.replace Eval.builtins name (fun vs -> exited (fun () -> f vs)) in
  let none = Value.empty in
  def "setproc" (fun vs -> attach caps (Int64.to_int (int "setproc" vs)); none);
  def "start" (fun vs -> msg caps (Int64.to_int (int "start" vs)) "start"; none);
  let stopping name = def name (fun vs ->
    let p = Int64.to_int (int name vs) in
    msg caps p name; notes caps p; dostop p; none) in
  stopping "stop"; stopping "startstop"; stopping "waitstop";
  def "kill" (fun vs -> let p = Int64.to_int (int "kill" vs) in msg caps p "kill"; deinstall p; none);
  def "status" (fun vs ->
    let p = Int64.to_int (int "status" vs) in
    if linux then
      (* (stat's third field, its state: t traced and stopped) *)
      match FS.read_opt caps (Fpath.v (Printf.sprintf "/proc/%d/stat" p)) with
      | Some st ->
          (match String.rindex_opt st ')' with
           | Some i when i + 2 < String.length st ->
               Value.string (match st.[i + 2] with 't' | 'T' -> "Stopped" | 'Z' | 'X' -> "Broken" | 'R' -> "Running" | _ -> "Pending")
           | _ -> error "bad status for %d" p)
      | None -> error "open /proc/%d/status: process exited" p
    else
    match FS.read_opt caps (Fpath.v (Printf.sprintf "/proc/%d/status" p)) with
    (* (its fields of fixed widths, devproc's: the name 28, the user 28,
     * the state 12; by place, not by blanks: a user may be empty) *)
    | Some s when String.length s >= 68 -> Value.string (String.trim (String.sub s 56 12))
    | Some s ->
        (match List.filter (fun w -> w <> "") (String.split_on_char ' ' s) with
         | _ :: _ :: state :: _ -> Value.string state
         | _ -> error "bad status for %d" p)
    | None -> error "open /proc/%d/status: process exited" p);
  def "reason" (fun vs ->
    let t = int "reason" vs in
    Value.string (if linux then (match Int64.to_int t with 5 -> "Breakpoint/Trace trap" | s -> signame s) else excep t));
  (* the maps, each {name, base, end, offset}: the process's (its text,
   * its data to the stack's top) or else the file's, as load reads them
   * (acid's map(), without its argument that moves one) *)
  def "map" (fun _ ->
    let seg name b e f = Value.list [ Value.string name; Value.int 'X' b; Value.int 'X' e; Value.int 'X' f ] in
    match !prog, !mem with
    | Some _, Some _ when linux ->
        Value.list (List.map (fun (n, b, e, f) -> seg n b e f) (linux_maps caps !pid))
    | Some p, Some _ -> Value.list [ seg "text" p.txtaddr (Int64.add p.txtaddr p.txtsz) p.txtaddr; seg "data" p.dataddr !stacktop p.dataddr ]
    | Some p, None ->
        Value.list [ seg "text" p.txtaddr (Int64.add p.txtaddr p.txtsz) 32L;
                     seg "data" p.dataddr (Int64.add p.dataddr p.datsz) (Int64.add 32L p.txtsz) ]
    | None, _ -> Value.empty);
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
  (* "file:line": its first address (libmach's file2pc), a breakpoint's *)
  def "filepc" (fun vs ->
    match vs with
    | [ { kind = String w; _ } ] ->
        (match String.rindex_opt w ':' with
         | Some i ->
             let file = String.sub w 0 i and line = int_of_string_opt (String.sub w (i + 1) (String.length w - i - 1)) in
             (match !prog, line with
              | Some { table = Some t; _ }, Some l ->
                  (match Symbols.file_pc t file l with
                   | Some pc -> Value.int 'V' (Int64.of_int pc)
                   | None -> error "filepc: can't find address for: %s" w)
              | _ -> error "filepc: can't find address for: %s" w)
         | None -> error "filepc(\"file:line\")")
    | _ -> error "filepc(\"file:line\")");
  def "follow" (fun vs -> Value.list (List.map (Value.int 'X') (follow (int "follow" vs))));
  def "newproc" (fun vs ->
    let aout = match !prog with Some p -> p.path | None -> error "no program" in
    let args = match vs with
      | [ { kind = String s; _ } ] -> List.filter (fun w -> w <> "") (String.split_on_char ' ' (String.map (fun c -> if c = '\t' then ' ' else c) s))
      | [] -> []
      | _ -> error "newproc(string)" in
    if linux then begin
      let child = try Ptrace.spawn caps aout (Array.of_list (aout :: args)) with Failure m -> error "newproc: %s" m in
      stops := (child, 5) :: List.remove_assoc child !stops;
      install caps child;
      attach caps child;
      rebias caps child;
      notes caps child;
      dostop child;
      Value.int 'D' (Int64.of_int child)
    end else
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
        msg caps child "waitstop";
        notes caps child;
        attach caps child;
        dostop child;
        Value.int 'D' (Int64.of_int child))
