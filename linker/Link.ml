(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Link.mli *)

open Program

let invert = Asm.invert and cond_bits = Asm.cond_bits
let cond_of_string = Asm.cond_of_string and string_of_cond = Asm.string_of_cond

let decode machine = function
  | "NOP" -> Some Nop
  | "B" -> Some B
  | "BL" -> Some Bl
  | "BCASE" -> Some Bcase
  | s when String.length s = 3 && s.[0] = 'B' && cond_of_string (String.sub s 1 2) <> None ->
      Option.map (fun c -> Bcond c) (cond_of_string (String.sub s 1 2))
  | s -> Option.map (fun m -> Ins m) (machine s)

let show_op show = function
  | Func -> "TEXT" | Nop -> "NOP" | B -> "B" | Bl -> "BL" | Bcond c -> "B" ^ string_of_cond c | Bcase -> "BCASE"
  | Ins m -> show m

exception Error of string

(* (the record's type said: without it, op is this module's prog's field for mini-ml) *)
let show show_m (p : _ prog) =
  let i : Asm.instr = { op = show_op show_m p.op; suffixes = p.suffixes; args = p.args } in
  Show_asm.show_item (Ins i)

let error fmt = Printf.ksprintf (fun s -> raise (Error s)) fmt

(* a shift's kind, as both machines encode it *)
let shift_bits : Asm.shift_kind -> int = function Lsl -> 0 | Lsr -> 1 | Asr -> 2 | Ror -> 3
(* v rounded up to a multiple of r, negatives too (5l's rnd) *)
let rnd v r = let v = v + r - 1 in let c = v mod r in v - (if c < 0 then c + r else c)

let create arch ~text_start =
  { arch; syms = Hashtbl.create 1024; ncreated = 0; progs = []; datas = [];
    text_start; data_start = 0; text_size = 0; data_size = 0; bss_size = 0; data_round = 4096; pie = false }

let lookup t name version =
  match Hashtbl.find_opt t.syms (name, version) with
  | Some s -> s
  | None ->
      let s = { name; version; kind = Undefined; value = 0; size = 0; created = t.ncreated; weak = false } in
      t.ncreated <- t.ncreated + 1;
      Hashtbl.replace t.syms (name, version) s;
      s

let sym_of t version (n : Asm.name) = lookup t n.sym (if n.static then version else 0)

(*****************************************************************************)
(* Objects and libraries *)
(*****************************************************************************)

(* GLOBL's flag for a name its object does not ask for (5l has none; C's
 * weak symbol): no library's member is taken to define it, and where
 * nothing does, a call to it is no call and its address is 0. It is
 * how a program of ML's links the units it uses and no other: its
 * start (mini-ml -start) calls each unit's initialization and lists
 * each one's roots, by such names, the stdlib's units are a library,
 * and a member is taken when the program's own code names something
 * of it. *)
let weak = 32

(* one object into the program (5l's ldobj): its instructions, its
 * TEXTs, GLOBLs and DATAs; each object has its own version, for its
 * name<>s *)
let add_object t ~decode:decode_machine version (o : Asm.obj) =
  let file = Fpath.to_string o.file in
  if o.arch <> t.arch then error "%s: an object for another machine" file;
  let items = o.items in
  (* the prog of each item that has a pc; the targets point at items *)
  let progs = Array.map (fun (it, line) ->
    let mk op suffixes args = Some { op; suffixes; args; pc = 0; target = None; version; where = (file, line); frame = 0; leaf = false } in
    match (it : Asm.item) with
    | Ins i -> (
        match decode decode_machine i.op with
        | Some op -> mk op i.suffixes i.args
        | None -> error "%s:%d: unknown opcode %s" file line i.op)
    | Text (n, flag, frame) ->
        let s = sym_of t version n in
        if s.kind = Text then error "%s:%d: %s defined twice" file line n.sym;
        s.kind <- Text;
        (match mk Func [] [ Asm.Mem { base = SB; name = Some n; off = 0L; index = None }; Asm.Imm (Int64.of_int flag) ] with
         | Some p -> p.frame <- Int64.to_int frame; Some p
         | None -> None)
    | Globl (n, flag, _) when flag land weak <> 0 -> (sym_of t version n).weak <- true; None
    | Globl (n, _, size) ->
        let s = sym_of t version n in
        if s.kind = Undefined then s.kind <- Bss;
        s.size <- max s.size (Int64.to_int size);
        None
    | Data (n, off, width, value) ->
        let s = sym_of t version n in
        t.datas <- { dsym = s; off = Int64.to_int off; width; value; dversion = version } :: t.datas;
        None) items in
  (* the symbols named, in the order of the object (as 5l meets them) *)
  Array.iter (fun (it, _) ->
    match (it : Asm.item) with
    | Ins i ->
        (* n(SB) only: n+4(FP) and n-8(SP) name a parameter and a local *)
        List.iter (function Asm.Mem { base = SB; name = Some n; _ } | Addr { base = SB; name = Some n; _ } -> ignore (sym_of t version n) | _ -> ()) i.args
    | Data (_, _, _, Addr { name = Some n; _ }) -> ignore (sym_of t version n)
    | _ -> ()) items;
  Array.iteri (fun i p ->
    match p with
    | Some p -> p.args <- List.map (function Asm.Target j -> (match progs.(j) with Some q -> p.target <- Some q | None -> ()); Asm.Target j | a -> a) p.args
    | None -> ignore i) progs;
  (* opti: while the objects are loaded t.progs is the last instruction
   * first, and an object's are put before it; load turns it over at
   * its end.
   * old: t.progs <- List.rev_append (List.rev t.progs) (List.filter_map Fun.id (Array.to_list progs))
   * the whole list made again, twice, for each object: 71 objects for
   * mini-rm, and of mini-ld's 35 collections linking it (by mini-ml,
   * each one copying the 54 MB alive) 12 were for these lists
   * (and before that t.progs @ ...: a call for each instruction already
   * there, half a million for a program of 2 MB, and the stack has 8 MB) *)
  Array.iter (function Some p -> t.progs <- p :: t.progs | None -> ()) progs

type library = (Asm.obj * string list) list   (* each object, and the names it defines *)

(* in its file, a member is its object's bytes (Asm's, as its .5 or .7
 * is), read as a value when it is taken
 * old: the objects themselves, all read with the library: linking
 * mini-rm, 50 MB of the stdlib's 69 units for the 30 it uses *)
type members = (string * string list) list

(* 2: its objects Asm's version 4; 3: a member its bytes *)
let lib_version = 3

(* a name defined: in text or in data *)
type def_kind = T | D

(* the names an object defines, for the library's index: its TEXTs,
 * its GLOBLs and DATAs (ar's objsym, 'T' and 'D') *)
let defined_names (o : Asm.obj) =
  Array.to_list o.items |> List.filter_map (fun (it, _) ->
    match (it : Asm.item) with
    | Text (n, _, _) when not n.static -> Some (T, n.sym)
    | Data (n, _, _, _) | Globl (n, _, _) when not n.static -> Some (D, n.sym)
    | _ -> None)
  |> List.sort_uniq compare

(* as ar: a text name defined again by a later object is not indexed
 * for it *)
let write_library caps out (objs : Asm.obj list) =
  let texts = Hashtbl.create 256 in
  let lib : library = List.map (fun (o : Asm.obj) ->
    let names = List.filter_map (fun (k, n) ->
      if k = T && Hashtbl.mem texts n then None else (if k = T then Hashtbl.replace texts n (); Some n)) (defined_names o) in
    (o, List.sort_uniq compare names)) objs in
  let members : members = List.map (fun (o, names) -> (Marshal.to_string (o : Asm.obj) [], names)) lib in
  FS.write caps out (Marshal.to_string (lib_version, members) [])

let read_members caps f =
  let v, (lib : members) = Marshal.from_string (FS.read caps f) 0 in
  if v <> lib_version then error "%s: a library of another version (to make again: remove it)" (Fpath.to_string f);
  lib

let member (bytes : string) : Asm.obj = Marshal.from_string bytes 0

let read_library caps f : library = List.map (fun (bytes, names) -> (member bytes, names)) (read_members caps f)

(* a name some object asked for, and none defined yet *)
let wanted t n =
  match Hashtbl.find_opt t.syms (n, 0) with Some s -> s.kind = Undefined && not s.weak | None -> false

let load caps t ~decode ~needs files =
  let add_object t version o = add_object t ~decode version o in
  let version = ref 0 in
  let next () = incr version; !version in
  let libs = ref [] in
  List.iter (fun f ->
    if Fpath.has_ext ".a" f then begin
      libs := !libs @ [ read_members caps f ]
    end
    else add_object t (next ()) (Asm.load caps f)) files;
  (* 5l's loadlib: take the members that define an undefined name, until
   * no library adds one *)
  let loaded = Hashtbl.create 64 in
  let rec again () =
    let added = ref false in
    List.iteri (fun li lib ->
      (* ar's index lists the objects last first *)
      List.iteri (fun mi (bytes, names) ->
        if not (Hashtbl.mem loaded (li, mi))
           && List.exists (wanted t) names
        then begin
          Hashtbl.replace loaded (li, mi) ();
          let o = member bytes in
          Logs.info (fun m -> m "from a library: %a, for %s" Fpath.pp o.file
            (String.concat " " (List.filter (wanted t) names)));
          add_object t (next ()) o;
          added := true
        end) (List.rev lib)) !libs;
    if !added then again ()
  in
  again ();
  (* then the names the machine's rewriting will call (5l's needsdiv) *)
  List.iter (fun n -> ignore (lookup t n 0)) (needs (List.rev t.progs));
  again ();
  (* (the first instruction first, from here on: see add_object) *)
  t.progs <- List.rev t.progs

(*****************************************************************************)
(* Branches *)
(*****************************************************************************)

let is_branch = function B | Bl -> true | Func | Nop | Bcond _ | Bcase | Ins _ -> false

let resolve t =
  (* BL f(SB) and B f(SB): to f's TEXT *)
  let texts = Hashtbl.create 64 in
  List.iter (fun p ->
    if p.op = Func then match p.args with Asm.Mem { name = Some n; _ } :: _ -> Hashtbl.replace texts (sym_of t p.version n) p | _ -> ()) t.progs;
  List.iter (fun p ->
    match p.args with
    | [ Asm.Mem { base = SB; name = Some n; _ } ] when is_branch p.op -> (
        let s = sym_of t p.version n in
        match Hashtbl.find_opt texts s with
        | Some q -> p.target <- Some q
        (* (a call to a weak name nothing defined: no call, see weak) *)
        | None when s.weak && s.kind = Undefined -> p.op <- Nop; p.args <- []
        | None -> let f, l = p.where in error "%s:%d: undefined: %s" f l n.sym)
    | _ -> ()) t.progs;
  (* a branch to an unconditional B goes where that B goes (brloop) *)
  let rec final q n =
    if n > 5000 then None
    else if q.op = B && q.suffixes = [] then (match q.target with Some r when r != q -> final r (n + 1) | _ -> if q.target = None then Some q else None)
    else Some q
  in
  List.iter (fun p -> match p.target with Some q -> p.target <- final q 0 | None -> ()) t.progs

(*****************************************************************************)
(* NOPs *)
(*****************************************************************************)

(* the NOPs out (5c -O0 leaves them), what branched to one to the next
 * instruction (5l's and 7l's noops) *)
let drop_nops t =
  let real = ref None and nops = ref [] in
  List.iter (fun (p : _ prog) -> if p.op = Nop then nops := (p, !real) :: !nops else real := Some p) (List.rev t.progs);
  if !nops <> [] then begin
    List.iter (fun (p : _ prog) -> match p.target with Some q when q.op = Nop -> p.target <- List.assq q !nops | _ -> ()) t.progs;
    t.progs <- List.filter (fun (p : _ prog) -> p.op <> Nop) t.progs
  end

(*****************************************************************************)
(* Data *)
(*****************************************************************************)

(* the linker's hash, whose buckets decide the data's order: 5l's
 * over a C long, masked; 7l's over an int32, complemented if negative *)
let bucket arch name version =
  match (arch : Asm.arch) with
  | Arm ->
      let h = ref (Int64.of_int version) in
      String.iter (fun c -> h := Int64.add (Int64.mul !h 3L) (Int64.of_int (Char.code c))) name;
      Int64.to_int (Int64.rem (Int64.logand !h 0xffffffL) 10007L)
  | Arm64 ->
      let h = ref (Int32.of_int version) in
      String.iter (fun c -> h := Int32.add (Int32.mul !h 3l) (Int32.of_int (Char.code c))) name;
      let h = if Int32.compare !h 0l < 0 then Int32.lognot !h else !h in
      Int32.to_int (Int32.rem h 10007l)

(* 5l's and 7l's dodata: small symbols (<= 64 bytes, bss included)
 * first, then the data, then the bss; 7l aligns what is 8 bytes or
 * more to 8, 16 or more to 16 *)
let layout_data t =
  List.iter (fun d -> if d.dsym.kind = Bss || d.dsym.kind = Undefined then d.dsym.kind <- Data) t.datas;
  let syms = Hashtbl.fold (fun _ s acc -> if s.kind = Data || s.kind = Bss then s :: acc else acc) t.syms [] in
  (* in bucket order, each newest first *)
  let syms = List.sort (fun a b -> compare (bucket t.arch a.name a.version, - a.created) (bucket t.arch b.name b.version, - b.created)) syms in
  let orig = ref 0 in
  let place s =
    if t.arch = Arm64 then orig := (if s.size >= 16 then rnd !orig 16 else if s.size >= 8 then rnd !orig 8 else !orig);
    s.value <- !orig;
    orig := !orig + s.size
  in
  let small = Hashtbl.create 64 in
  List.iter (fun s ->
    s.size <- rnd (if s.size = 0 then 1 else s.size) 4;
    if s.size <= 64 then (place s; Hashtbl.replace small s ()))
    syms;
  List.iter (fun s -> if s.kind = Data && not (Hashtbl.mem small s) then place s) syms;
  List.iter (fun s -> if Hashtbl.mem small s then s.kind <- Data) syms;
  t.data_size <- rnd !orig 8;
  orig := t.data_size;
  List.iter (fun s -> if s.kind = Bss then place s) syms;
  t.bss_size <- rnd !orig 8 - t.data_size;
  let define name kind value =
    let s = lookup t name 0 in
    if s.kind = Undefined then (s.kind <- kind; s.value <- value)
  in
  (* R12 is setR12 on arm (data + 4092), R28 setSB on arm64 (data + 0) *)
  (match t.arch with Arm -> define "setR12" Data 4092 | Arm64 -> define "setSB" Data 0);
  define "bdata" Data 0;
  define "edata" Data t.data_size;
  define "end" Bss (t.data_size + t.bss_size);
  define "etext" Text 0

(* a double's bits as a single's, as 5l rounds them (5l's ieeedtof):
 * half up, not to even. In an int64, its low 32 bits: an int has 31 in
 * a 32-bit program. *)
(* old: in ints, with h land 0x80000000 for the sign *)
let single_bits x =
  let d = Int64.bits_of_float x in
  let h = Int64.to_int (Int64.shift_right_logical d 52) and m = Int64.logand d 0xfffffffffffffL in
  if Int64.shift_right_logical d 32 = 0L then 0L
  else begin
    let exp = ref ((h land 0x7ff) - 1022) in
    (* the mantissa's top 23 bits, and the next one to round by *)
    let v = ref (Int64.to_int (Int64.shift_right_logical m 29)) in
    if Int64.logand (Int64.shift_right_logical m 28) 1L = 1L then begin
      incr v;
      if !v land 0x800000 <> 0 then (v := (!v land 0x7fffff) lsr 1; incr exp)
    end;
    if !exp <= -126 || !exp >= 130 then error "double fp to single fp overflow";
    Int64.logor (Int64.of_int (!v lor (((!exp + 126) land 0xff) lsl 23))) (if h land 0x800 <> 0 then 0x80000000L else 0L)
  end

(* a float constant as data, in a symbol named by its bits, for the
 * machines that can't have it immediate (5l's and 7l's ldobj) *)
let float_constant t x ~single =
  let bits = Int64.bits_of_float x in
  let width, name =
    if single then 4, Printf.sprintf "$%Lx" (single_bits x)
    else 8, Printf.sprintf "$%Lx.%Lx" (Int64.logand bits 0xffffffffL) (Int64.shift_right_logical bits 32) in
  let s = lookup t name 0 in
  if s.kind = Undefined then begin
    s.kind <- Bss;
    s.size <- width;
    t.datas <- { dsym = s; off = 0; width; value = Asm.Fimm x; dversion = 0 } :: t.datas
  end;
  Asm.Mem { base = SB; name = Some { sym = name; static = false }; off = 0L; index = None }

(* an address as data: a text symbol's is absolute, a data symbol's is
 * the data's start plus its offset *)
let address t version (m : Asm.mem) =
  match m.name with
  | Some n ->
      let s = sym_of t version n in
      (match s.kind with
       | Text -> s.value + Int64.to_int m.off
       | Data | Bss -> s.value + t.data_start + Int64.to_int m.off
       | Undefined when s.weak -> 0
       | Undefined -> error "undefined: %s" n.sym)
  | None -> Int64.to_int m.off

let data_bytes t =
  let b = Bytes.make t.data_size '\000' in
  List.iter (fun d ->
    let a = d.dsym.value + d.off in
    if d.dsym.kind = Data && a >= 0 && a + d.width <= t.data_size then
      match d.value with
      | Asm.Str s -> for i = 0 to d.width - 1 do Bytes.set b (a + i) (if i < String.length s then s.[i] else '\000') done
      | Imm n ->
          (* claude: in 64 bits: through an int, bit 63 was bit 62's copy *)
          Binary.set_le b a d.width n
      | Addr m ->
          let v = address t d.dversion m in
          Binary.set_le b a d.width (Int64.of_int v)
      | Fimm x ->
          let bits = if d.width = 4 then single_bits x else Int64.bits_of_float x in
          Binary.set_le b a d.width bits
      | _ -> error "DATA %s: a value of an unknown kind" d.dsym.name) t.datas;
  b

(* the offsets in the data of its addresses, which a PIE loader slides
 * (goken's liblk/macho.c machorebase) *)
let pointers t =
  List.filter_map (fun d ->
    match d.value with
    | Asm.Addr { name = Some n; _ } when d.dsym.kind = Data ->
        let s = sym_of t d.dversion n in
        if s.kind = Undefined then None else Some (d.dsym.value + d.off)
    | _ -> None) t.datas
  |> List.sort compare

let entry t name =
  match Hashtbl.find_opt t.syms (name, 0) with
  | Some { kind = Text; value; _ } -> value
  | _ -> error "entry %s: not defined" name
