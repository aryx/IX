(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Frame64.mli *)

type frame = { start : int64; pc : int64; cfa : int64; ret : int64 }

type var = { vname : string; param : bool; addr : int64; size : int }

(* where a function's return is once its prologue has run (by fixed,
 * an instruction's address): in a frame record (Fp: the CFA that far
 * above R29), at 0(RSP) (Sp), or still in R30 (Link); drop: how far
 * the prologue moved the SP (the CFA less the SP) *)
type how = Fp of int64 | Sp | Link
type prologue = { fixed : int64; drop : int64; how : how }

(* SUB $n, RSP's n, if w is one *)
let sub_sp w =
  if w land 0xff8003ff <> 0xd10003ff then None
  else let n = (w lsr 10) land 0xfff in Some (if w land 0x400000 <> 0 then n lsl 12 else n)

(* STP (R29, R30), m(RSP)'s m (pre: STP.W's, the SP moved by it) *)
let stp_fp ~pre w =
  if w land 0xffc07fff <> (if pre then 0xa9807bfd else 0xa9007bfd) then None
  else let i = (w lsr 15) land 0x7f in Some (8 * (if i land 0x40 <> 0 then i - 0x80 else i))

(* ADD $m, RSP, R29's m (MOV RSP, R29 is m = 0) *)
let add_fp w = if w land 0xffc003ff = 0x910003fd then Some ((w lsr 10) land 0xfff) else None

let prologue read4 start =
  let word a = match read4 a with Some w -> Int64.to_int w land 0xffffffff | None -> 0 in
  let w0 = word start and w1 = word (Int64.add start 4L) and w2 = word (Int64.add start 8L) in
  let i64 = Int64.of_int in
  match sub_sp w0, stp_fp ~pre:true w0 with
  (* 7c's MOVD.W R30, -n(RSP) *)
  | _ when w0 land 0xffe00fff = 0xf8000ffe ->
      let imm = (w0 lsr 12) land 0x1ff in
      { fixed = start; drop = i64 (if imm land 0x100 <> 0 then 0x200 - imm else - imm); how = Sp }
  | Some n, _ when w1 = 0xf90003fe -> { fixed = Int64.add start 4L; drop = i64 n; how = Sp }
  | Some n, _ -> (
      match stp_fp ~pre:false w1, add_fp w2 with
      | Some m, Some m' when m = m' -> { fixed = Int64.add start 8L; drop = i64 n; how = Fp (i64 (n - m)) }
      | _ -> { fixed = start; drop = i64 n; how = Link })
  | None, Some m -> (
      match add_fp w1 with
      | Some m' -> { fixed = Int64.add start 4L; drop = i64 (- m); how = Fp (i64 (- m - m')) }
      | None -> { fixed = start; drop = 0L; how = Link })
  | None, None -> { fixed = start; drop = 0L; how = Link }

let walk read8 read4 fstart isstart pc sp link fp =
  let rec go pc sp fp n acc =
    match fstart pc with
    | Some start when n < 40 -> (
        let p = prologue read4 start in
        (* the frame's CFA, where it returns to, the caller's R29 *)
        let r =
          if pc <= p.fixed then
            (if n > 0 then None else Some ((if pc > start then Int64.add sp p.drop else sp), link, fp))
          else
            match p.how with
            | Fp off -> (
                match read8 (Int64.add fp 8L), read8 fp with
                | Some ret, Some fp' -> Some (Int64.add fp off, ret, fp')
                | _ -> None)
            | Sp -> Option.map (fun ret -> (Int64.add sp p.drop, ret, fp)) (read8 sp)
            | Link -> if n > 0 then None else Some (Int64.add sp p.drop, link, fp)
        in
        match r with
        | None -> List.rev acc
        | Some (cfa, ret, fp') ->
            let acc = { start; pc; cfa; ret } :: acc in
            if isstart start || ret = 0L then List.rev acc
            else go (Int64.sub ret 4L) cfa fp' (n + 1) acc)
    | _ -> List.rev acc
  in
  go pc sp fp 0 []

(* the table's entries after a function's symbol: p at CFA+8+off (7c's
 * FP, the return's slot above the frame), a at CFA-off; their sizes
 * unsaid, a word; the last written first (libmach's localsym) *)
let plan9 (autos : Symbols.sym list) cfa =
  List.rev @@ List.filter_map (fun (e : Symbols.sym) ->
    if e.name = "" || e.name.[0] = '.' then None
    else if e.typ = 'p' then Some { vname = e.name; param = true; addr = Int64.add cfa (Int64.of_int (8 + e.value)); size = 8 }
    else if e.typ = 'a' then Some { vname = e.name; param = false; addr = Int64.sub cfa (Int64.of_int e.value); size = 8 }
    else None) autos

(* DW_TAG_s and DW_AT_s *)
let t_subprogram = 0x2e and t_param = 0x05 and t_variable = 0x34 and t_block = 0x0b
let at_low_pc = 0x11 and at_frame_base = 0x40 and at_location = 0x02 and at_type = 0x49 and at_size = 0x0b

let sleb s o =
  let rec go o v sh =
    let b = Char.code s.[o] in
    let v = v lor ((b land 0x7f) lsl sh) in
    if b land 0x80 <> 0 then go (o + 1) v (sh + 7)
    else if b land 0x40 <> 0 then v lor (-1 lsl (sh + 7)) else v in
  go o 0 0

(* the entries by their offsets, kept for the program's units *)
let indexed : (Dwarf_info.die list * (int, Dwarf_info.die) Hashtbl.t) option ref = ref None

let dwarf (units : Dwarf_info.die list) start cfa =
  let idx = match !indexed with
    | Some (u, i) when u == units -> i
    | _ -> let i = Dwarf_info.index units in indexed := Some (units, i); i in
  (* a type's size, through its typedefs, const and volatile *)
  let rec size (d : Dwarf_info.die) =
    match Dwarf_info.int d at_size, Dwarf_info.ref_ d at_type with
    | Some n, _ -> n
    | None, Some r -> (match Hashtbl.find_opt idx r with Some t -> size t | None -> 8)
    | None, None -> 8 in
  let rec find (d : Dwarf_info.die) =
    if d.tag = t_subprogram && Dwarf_info.int d at_low_pc = Some start then Some d
    else List.find_map find d.children in
  match List.find_map find units with
  | Some f when Dwarf_info.attr f at_frame_base = Some (Dwarf_info.Block "\x9c") ->
      (* (a lexical block's variables the function's too) *)
      let rec vars (d : Dwarf_info.die) =
        List.concat_map (fun (c : Dwarf_info.die) ->
          if c.tag = t_block then vars c
          else
            match Dwarf_info.name c, Dwarf_info.attr c at_location with
            | Some n, Some (Dwarf_info.Block b)
              when (c.tag = t_param || c.tag = t_variable) && String.length b > 1 && b.[0] = '\x91' ->
                [ { vname = n; param = c.tag = t_param; addr = Int64.add cfa (Int64.of_int (sleb b 1)); size = size c } ]
            | _ -> []) d.children in
      vars f
  | _ -> []
