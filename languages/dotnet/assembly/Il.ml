(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Il.mli *)

type kind = K_i1 | K_u1 | K_i2 | K_u2 | K_i4 | K_u4 | K_i8 | K_u8
          | K_i | K_u | K_r4 | K_r8 | K_ref

type binop = Add | Sub | Mul | Div | Div_un | Rem | Rem_un
           | And | Or | Xor | Shl | Shr | Shr_un
           | Add_ovf | Add_ovf_un | Mul_ovf | Mul_ovf_un | Sub_ovf | Sub_ovf_un

type cmp = Eq | Ne | Ge | Gt | Le | Lt

type op =
  | Nop
  | Break
  | Ldarg of int | Ldarga of int | Starg of int
  | Ldloc of int | Ldloca of int | Stloc of int
  | Ldnull
  | Ldc_i4 of int32 | Ldc_i8 of int64 | Ldc_r of float
  | Dup | Pop
  | Jmp of int | Call of int | Calli of int | Callvirt of int
  | Ret
  | Br of int
  | Brfalse of int | Brtrue of int
  | Bcmp of cmp * bool * int
  | Switch of int array
  | Ldind of kind | Stind of kind
  | Binop of binop
  | Neg | Not
  | Conv of kind * bool * bool
  | Conv_r_un
  | Cpobj of int | Ldobj of int | Stobj of int
  | Ldstr of int
  | Newobj of int
  | Castclass of int | Isinst of int
  | Unbox of int | Unbox_any of int | Box of int
  | Throw | Rethrow
  | Ldfld of int | Ldflda of int | Stfld of int
  | Ldsfld of int | Ldsflda of int | Stsfld of int
  | Newarr of int | Ldlen
  | Ldelema of int
  | Ldelem of kind | Ldelem_any of int
  | Stelem of kind | Stelem_any of int
  | Refanyval of int | Mkrefany of int | Refanytype
  | Ckfinite
  | Ldtoken of int
  | Endfinally
  | Leave of int
  | Ceq | Cgt of bool | Clt of bool
  | Ldftn of int | Ldvirtftn of int
  | Arglist | Localloc | Endfilter
  | Initobj of int
  | Cpblk | Initblk
  | Sizeof of int
  | Constrained of int
  | Prefix of string

type instr = {
  at : int;
  name : string;
  op : op;
}

exception Bad_il of string

(* an operand's size and meaning *)
type operand =
  | No
  | S8              (* a signed byte: ldc.i4.s *)
  | U8              (* an unsigned byte: ldarg.s's number *)
  | U16
  | I32
  | I64
  | F32
  | F64
  | Tok
  | Br8             (* a branch, its distance from the next instruction *)
  | Br32
  | Sw              (* a count, then that many Br32 *)

(* Partition III, by their bytes; a code above 0xFF is 0xFE's second *)
let table : (int * string * operand) list = [
  0x00, "nop", No; 0x01, "break", No;
  0x02, "ldarg.0", No; 0x03, "ldarg.1", No; 0x04, "ldarg.2", No; 0x05, "ldarg.3", No;
  0x06, "ldloc.0", No; 0x07, "ldloc.1", No; 0x08, "ldloc.2", No; 0x09, "ldloc.3", No;
  0x0A, "stloc.0", No; 0x0B, "stloc.1", No; 0x0C, "stloc.2", No; 0x0D, "stloc.3", No;
  0x0E, "ldarg.s", U8; 0x0F, "ldarga.s", U8; 0x10, "starg.s", U8;
  0x11, "ldloc.s", U8; 0x12, "ldloca.s", U8; 0x13, "stloc.s", U8;
  0x14, "ldnull", No;
  0x15, "ldc.i4.m1", No; 0x16, "ldc.i4.0", No; 0x17, "ldc.i4.1", No;
  0x18, "ldc.i4.2", No; 0x19, "ldc.i4.3", No; 0x1A, "ldc.i4.4", No;
  0x1B, "ldc.i4.5", No; 0x1C, "ldc.i4.6", No; 0x1D, "ldc.i4.7", No;
  0x1E, "ldc.i4.8", No; 0x1F, "ldc.i4.s", S8;
  0x20, "ldc.i4", I32; 0x21, "ldc.i8", I64; 0x22, "ldc.r4", F32; 0x23, "ldc.r8", F64;
  0x25, "dup", No; 0x26, "pop", No;
  0x27, "jmp", Tok; 0x28, "call", Tok; 0x29, "calli", Tok; 0x2A, "ret", No;
  0x2B, "br.s", Br8; 0x2C, "brfalse.s", Br8; 0x2D, "brtrue.s", Br8;
  0x2E, "beq.s", Br8; 0x2F, "bge.s", Br8; 0x30, "bgt.s", Br8; 0x31, "ble.s", Br8;
  0x32, "blt.s", Br8; 0x33, "bne.un.s", Br8; 0x34, "bge.un.s", Br8;
  0x35, "bgt.un.s", Br8; 0x36, "ble.un.s", Br8; 0x37, "blt.un.s", Br8;
  0x38, "br", Br32; 0x39, "brfalse", Br32; 0x3A, "brtrue", Br32;
  0x3B, "beq", Br32; 0x3C, "bge", Br32; 0x3D, "bgt", Br32; 0x3E, "ble", Br32;
  0x3F, "blt", Br32; 0x40, "bne.un", Br32; 0x41, "bge.un", Br32;
  0x42, "bgt.un", Br32; 0x43, "ble.un", Br32; 0x44, "blt.un", Br32;
  0x45, "switch", Sw;
  0x46, "ldind.i1", No; 0x47, "ldind.u1", No; 0x48, "ldind.i2", No;
  0x49, "ldind.u2", No; 0x4A, "ldind.i4", No; 0x4B, "ldind.u4", No;
  0x4C, "ldind.i8", No; 0x4D, "ldind.i", No; 0x4E, "ldind.r4", No;
  0x4F, "ldind.r8", No; 0x50, "ldind.ref", No;
  0x51, "stind.ref", No; 0x52, "stind.i1", No; 0x53, "stind.i2", No;
  0x54, "stind.i4", No; 0x55, "stind.i8", No; 0x56, "stind.r4", No;
  0x57, "stind.r8", No;
  0x58, "add", No; 0x59, "sub", No; 0x5A, "mul", No; 0x5B, "div", No;
  0x5C, "div.un", No; 0x5D, "rem", No; 0x5E, "rem.un", No; 0x5F, "and", No;
  0x60, "or", No; 0x61, "xor", No; 0x62, "shl", No; 0x63, "shr", No;
  0x64, "shr.un", No; 0x65, "neg", No; 0x66, "not", No;
  0x67, "conv.i1", No; 0x68, "conv.i2", No; 0x69, "conv.i4", No;
  0x6A, "conv.i8", No; 0x6B, "conv.r4", No; 0x6C, "conv.r8", No;
  0x6D, "conv.u4", No; 0x6E, "conv.u8", No;
  0x6F, "callvirt", Tok; 0x70, "cpobj", Tok; 0x71, "ldobj", Tok;
  0x72, "ldstr", Tok; 0x73, "newobj", Tok; 0x74, "castclass", Tok;
  0x75, "isinst", Tok; 0x76, "conv.r.un", No; 0x79, "unbox", Tok;
  0x7A, "throw", No;
  0x7B, "ldfld", Tok; 0x7C, "ldflda", Tok; 0x7D, "stfld", Tok;
  0x7E, "ldsfld", Tok; 0x7F, "ldsflda", Tok; 0x80, "stsfld", Tok;
  0x81, "stobj", Tok;
  0x82, "conv.ovf.i1.un", No; 0x83, "conv.ovf.i2.un", No;
  0x84, "conv.ovf.i4.un", No; 0x85, "conv.ovf.i8.un", No;
  0x86, "conv.ovf.u1.un", No; 0x87, "conv.ovf.u2.un", No;
  0x88, "conv.ovf.u4.un", No; 0x89, "conv.ovf.u8.un", No;
  0x8A, "conv.ovf.i.un", No; 0x8B, "conv.ovf.u.un", No;
  0x8C, "box", Tok; 0x8D, "newarr", Tok; 0x8E, "ldlen", No; 0x8F, "ldelema", Tok;
  0x90, "ldelem.i1", No; 0x91, "ldelem.u1", No; 0x92, "ldelem.i2", No;
  0x93, "ldelem.u2", No; 0x94, "ldelem.i4", No; 0x95, "ldelem.u4", No;
  0x96, "ldelem.i8", No; 0x97, "ldelem.i", No; 0x98, "ldelem.r4", No;
  0x99, "ldelem.r8", No; 0x9A, "ldelem.ref", No;
  0x9B, "stelem.i", No; 0x9C, "stelem.i1", No; 0x9D, "stelem.i2", No;
  0x9E, "stelem.i4", No; 0x9F, "stelem.i8", No; 0xA0, "stelem.r4", No;
  0xA1, "stelem.r8", No; 0xA2, "stelem.ref", No;
  0xA3, "ldelem", Tok; 0xA4, "stelem", Tok; 0xA5, "unbox.any", Tok;
  0xB3, "conv.ovf.i1", No; 0xB4, "conv.ovf.u1", No; 0xB5, "conv.ovf.i2", No;
  0xB6, "conv.ovf.u2", No; 0xB7, "conv.ovf.i4", No; 0xB8, "conv.ovf.u4", No;
  0xB9, "conv.ovf.i8", No; 0xBA, "conv.ovf.u8", No;
  0xC2, "refanyval", Tok; 0xC3, "ckfinite", No; 0xC6, "mkrefany", Tok;
  0xD0, "ldtoken", Tok;
  0xD1, "conv.u2", No; 0xD2, "conv.u1", No; 0xD3, "conv.i", No;
  0xD4, "conv.ovf.i", No; 0xD5, "conv.ovf.u", No;
  0xD6, "add.ovf", No; 0xD7, "add.ovf.un", No; 0xD8, "mul.ovf", No;
  0xD9, "mul.ovf.un", No; 0xDA, "sub.ovf", No; 0xDB, "sub.ovf.un", No;
  0xDC, "endfinally", No; 0xDD, "leave", Br32; 0xDE, "leave.s", Br8;
  0xDF, "stind.i", No; 0xE0, "conv.u", No;
  0xFE00, "arglist", No; 0xFE01, "ceq", No; 0xFE02, "cgt", No;
  0xFE03, "cgt.un", No; 0xFE04, "clt", No; 0xFE05, "clt.un", No;
  0xFE06, "ldftn", Tok; 0xFE07, "ldvirtftn", Tok;
  0xFE09, "ldarg", U16; 0xFE0A, "ldarga", U16; 0xFE0B, "starg", U16;
  0xFE0C, "ldloc", U16; 0xFE0D, "ldloca", U16; 0xFE0E, "stloc", U16;
  0xFE0F, "localloc", No; 0xFE11, "endfilter", No;
  0xFE12, "unaligned.", U8; 0xFE13, "volatile.", No; 0xFE14, "tail.", No;
  0xFE15, "initobj", Tok; 0xFE16, "constrained.", Tok;
  0xFE17, "cpblk", No; 0xFE18, "initblk", No; 0xFE19, "no.", U8;
  0xFE1A, "rethrow", No; 0xFE1C, "sizeof", Tok; 0xFE1D, "refanytype", No;
  0xFE1E, "readonly.", No;
]

let opcodes = List.map (fun (c, n, _) -> (c, n)) table

(* by their code: the one-byte ones, then 0xFE's *)
let one = Array.make 256 None
let two = Array.make 256 None
let () =
  List.iter (fun (c, n, o) ->
      if c < 0x100 then one.(c) <- Some (n, o) else two.(c land 0xFF) <- Some (n, o)) table

let kind_of (s : string) : kind =
  match s with
  | "i1" -> K_i1 | "u1" -> K_u1 | "i2" -> K_i2 | "u2" -> K_u2
  | "i4" -> K_i4 | "u4" -> K_u4 | "i8" -> K_i8 | "u8" -> K_u8
  | "i" -> K_i | "u" -> K_u | "r4" -> K_r4 | "r8" -> K_r8 | "ref" -> K_ref
  | _ -> raise (Bad_il ("a kind " ^ s))

let cmp_of (s : string) : cmp =
  match s with
  | "eq" -> Eq | "ne" -> Ne | "ge" -> Ge | "gt" -> Gt | "le" -> Le | "lt" -> Lt
  | _ -> raise (Bad_il ("a comparison " ^ s))

(* what was read after the opcode *)
type arg = A_none | A_int of int | A_i32 of int32 | A_i64 of int64
         | A_float of float | A_targets of int array

(* the op of a name and its operand; a branch's target already an
 * offset *)
let make (name : string) (arg : arg) : op =
  let n = match arg with A_int n -> n | _ -> 0 in
  let parts = String.split_on_char '.' name in
  match name, parts with
  | "nop", _ -> Nop
  | "break", _ -> Break
  | _, ["ldarg"; ("0" | "1" | "2" | "3" as k)] -> Ldarg (int_of_string k)
  | _, ["ldloc"; ("0" | "1" | "2" | "3" as k)] -> Ldloc (int_of_string k)
  | _, ["stloc"; ("0" | "1" | "2" | "3" as k)] -> Stloc (int_of_string k)
  | _, ("ldarg" :: _) -> Ldarg n
  | _, ("ldarga" :: _) -> Ldarga n
  | _, ("starg" :: _) -> Starg n
  | _, ("ldloc" :: _) -> Ldloc n
  | _, ("ldloca" :: _) -> Ldloca n
  | _, ("stloc" :: _) -> Stloc n
  | "ldnull", _ -> Ldnull
  | "ldc.i4.m1", _ -> Ldc_i4 Int32.minus_one
  | _, ["ldc"; "i4"; k] when k <> "s" -> Ldc_i4 (Int32.of_int (int_of_string k))
  | _, ("ldc" :: "i4" :: _) ->
      (match arg with A_i32 v -> Ldc_i4 v | _ -> Ldc_i4 (Int32.of_int n))
  | "ldc.i8", _ -> (match arg with A_i64 v -> Ldc_i8 v | _ -> assert false)
  | ("ldc.r4" | "ldc.r8"), _ -> (match arg with A_float v -> Ldc_r v | _ -> assert false)
  | "dup", _ -> Dup
  | "pop", _ -> Pop
  | "jmp", _ -> Jmp n
  | "call", _ -> Call n
  | "calli", _ -> Calli n
  | "callvirt", _ -> Callvirt n
  | "ret", _ -> Ret
  | _, ("br" :: _) -> Br n
  | _, ("brfalse" :: _) -> Brfalse n
  | _, ("brtrue" :: _) -> Brtrue n
  | _, (("beq" | "bge" | "bgt" | "ble" | "blt" | "bne") as c :: rest) ->
      Bcmp (cmp_of (String.sub c 1 2), List.mem "un" rest, n)
  | "switch", _ -> (match arg with A_targets t -> Switch t | _ -> assert false)
  | _, ["ldind"; k] -> Ldind (kind_of k)
  | _, ["stind"; k] -> Stind (kind_of k)
  | "add", _ -> Binop Add | "sub", _ -> Binop Sub | "mul", _ -> Binop Mul
  | "div", _ -> Binop Div | "div.un", _ -> Binop Div_un
  | "rem", _ -> Binop Rem | "rem.un", _ -> Binop Rem_un
  | "and", _ -> Binop And | "or", _ -> Binop Or | "xor", _ -> Binop Xor
  | "shl", _ -> Binop Shl | "shr", _ -> Binop Shr | "shr.un", _ -> Binop Shr_un
  | "add.ovf", _ -> Binop Add_ovf | "add.ovf.un", _ -> Binop Add_ovf_un
  | "mul.ovf", _ -> Binop Mul_ovf | "mul.ovf.un", _ -> Binop Mul_ovf_un
  | "sub.ovf", _ -> Binop Sub_ovf | "sub.ovf.un", _ -> Binop Sub_ovf_un
  | "neg", _ -> Neg
  | "not", _ -> Not
  | "conv.r.un", _ -> Conv_r_un
  | _, ["conv"; "ovf"; k] -> Conv (kind_of k, true, false)
  | _, ["conv"; "ovf"; k; "un"] -> Conv (kind_of k, true, true)
  | _, ["conv"; k] -> Conv (kind_of k, false, false)
  | "cpobj", _ -> Cpobj n | "ldobj", _ -> Ldobj n | "stobj", _ -> Stobj n
  | "ldstr", _ -> Ldstr n
  | "newobj", _ -> Newobj n
  | "castclass", _ -> Castclass n | "isinst", _ -> Isinst n
  | "unbox", _ -> Unbox n | "unbox.any", _ -> Unbox_any n | "box", _ -> Box n
  | "throw", _ -> Throw | "rethrow", _ -> Rethrow
  | "ldfld", _ -> Ldfld n | "ldflda", _ -> Ldflda n | "stfld", _ -> Stfld n
  | "ldsfld", _ -> Ldsfld n | "ldsflda", _ -> Ldsflda n | "stsfld", _ -> Stsfld n
  | "newarr", _ -> Newarr n | "ldlen", _ -> Ldlen
  | "ldelema", _ -> Ldelema n
  | "ldelem", _ -> Ldelem_any n | "stelem", _ -> Stelem_any n
  | _, ["ldelem"; k] -> Ldelem (kind_of k)
  | _, ["stelem"; k] -> Stelem (kind_of k)
  | "refanyval", _ -> Refanyval n | "mkrefany", _ -> Mkrefany n
  | "refanytype", _ -> Refanytype
  | "ckfinite", _ -> Ckfinite
  | "ldtoken", _ -> Ldtoken n
  | "endfinally", _ -> Endfinally
  | _, ("leave" :: _) -> Leave n
  | "ceq", _ -> Ceq | "cgt", _ -> Cgt false | "cgt.un", _ -> Cgt true
  | "clt", _ -> Clt false | "clt.un", _ -> Clt true
  | "ldftn", _ -> Ldftn n | "ldvirtftn", _ -> Ldvirtftn n
  | "arglist", _ -> Arglist | "localloc", _ -> Localloc
  | "endfilter", _ -> Endfilter
  | "initobj", _ -> Initobj n
  | "cpblk", _ -> Cpblk | "initblk", _ -> Initblk
  | "sizeof", _ -> Sizeof n
  | "constrained.", _ -> Constrained n
  | _ -> Prefix name

let decode (code : string) : instr array =
  let len = String.length code in
  let s8 p = let b = Char.code code.[p] in if b >= 128 then b - 256 else b in
  let i32 p =
    Int32.logor (Int32.of_int (Binary.le16 code p))
      (Int32.shift_left (Int32.of_int (Binary.le16 code (p + 2))) 16) in
  let int32 p = Int32.to_int (i32 p) in
  let out = ref [] in
  let p = ref 0 in
  (try
     while !p < len do
       let at = !p in
       let b = Char.code code.[at] in
       let entry, q =
         if b = 0xFE then (two.(Char.code code.[at + 1]), at + 2) else (one.(b), at + 1) in
       let name, operand = match entry with
         | Some e -> e
         | None -> raise (Bad_il (Printf.sprintf "an opcode 0x%x at IL_%04x" b at)) in
       let arg, next =
         match operand with
         | No -> (A_none, q)
         | S8 -> (A_int (s8 q), q + 1)
         | U8 -> (A_int (Char.code code.[q]), q + 1)
         | U16 -> (A_int (Binary.le16 code q), q + 2)
         | I32 -> (A_i32 (i32 q), q + 4)
         | I64 -> (A_i64 (String.get_int64_le code q), q + 8)
         | F32 -> (A_float (Int32.float_of_bits (i32 q)), q + 4)
         | F64 -> (A_float (Int64.float_of_bits (String.get_int64_le code q)), q + 8)
         | Tok -> (A_int (Binary.le32 code q), q + 4)
         | Br8 -> (A_int (q + 1 + s8 q), q + 1)
         | Br32 -> (A_int (q + 4 + int32 q), q + 4)
         | Sw ->
             let n = Binary.le32 code q in
             let next = q + 4 + 4 * n in
             (A_targets (Array.init n (fun i -> next + int32 (q + 4 + 4 * i))), next) in
       out := { at; name; op = make name arg } :: !out;
       p := next
     done
   with Invalid_argument _ -> raise (Bad_il "a method's IL cut short"));
  let instrs = Array.of_list (List.rev !out) in
  (* the targets: offsets to indexes *)
  let idx = Hashtbl.create (Array.length instrs) in
  Array.iteri (fun i ins -> Hashtbl.replace idx ins.at i) instrs;
  Hashtbl.replace idx len (Array.length instrs);
  let target t = match Hashtbl.find_opt idx t with
    | Some i -> i
    | None -> raise (Bad_il (Printf.sprintf "a branch to IL_%04x, inside an instruction" t)) in
  Array.map (fun ins ->
      let op = match ins.op with
        | Br t -> Br (target t)
        | Brfalse t -> Brfalse (target t)
        | Brtrue t -> Brtrue (target t)
        | Bcmp (c, u, t) -> Bcmp (c, u, target t)
        | Leave t -> Leave (target t)
        | Switch ts -> Switch (Array.map target ts)
        | op -> op in
      { ins with op }) instrs

let index (instrs : instr array) (at : int) : int =
  let rec go lo hi =
    if lo >= hi then (if lo = Array.length instrs && at >= 0 then lo else raise Not_found)
    else
      let mid = (lo + hi) / 2 in
      if instrs.(mid).at = at then mid
      else if instrs.(mid).at < at then go (mid + 1) hi
      else go lo mid in
  if Array.length instrs > 0 && at > instrs.(Array.length instrs - 1).at then Array.length instrs
  else go 0 (Array.length instrs)

(* the writer's side *)

let code_of =
  let h = Hashtbl.create 256 in
  List.iter (fun (c, n, _) -> Hashtbl.replace h n c) table;
  fun (name : string) -> match Hashtbl.find_opt h name with
    | Some c -> c
    | None -> raise (Bad_il ("no opcode " ^ name))

let kind_name (k : kind) : string =
  match k with
  | K_i1 -> "i1" | K_u1 -> "u1" | K_i2 -> "i2" | K_u2 -> "u2"
  | K_i4 -> "i4" | K_u4 -> "u4" | K_i8 -> "i8" | K_u8 -> "u8"
  | K_i -> "i" | K_u -> "u" | K_r4 -> "r4" | K_r8 -> "r8" | K_ref -> "ref"

let cmp_name (c : cmp) : string =
  match c with Eq -> "eq" | Ne -> "ne" | Ge -> "ge" | Gt -> "gt" | Le -> "le" | Lt -> "lt"

let binop_name (b : binop) : string =
  match b with
  | Add -> "add" | Sub -> "sub" | Mul -> "mul" | Div -> "div" | Div_un -> "div.un"
  | Rem -> "rem" | Rem_un -> "rem.un" | And -> "and" | Or -> "or" | Xor -> "xor"
  | Shl -> "shl" | Shr -> "shr" | Shr_un -> "shr.un"
  | Add_ovf -> "add.ovf" | Add_ovf_un -> "add.ovf.un" | Mul_ovf -> "mul.ovf"
  | Mul_ovf_un -> "mul.ovf.un" | Sub_ovf -> "sub.ovf" | Sub_ovf_un -> "sub.ovf.un"

let add_i32 (b : Buffer.t) (v : int32) : unit = Buffer.add_int32_le b v
let add_int (b : Buffer.t) (v : int) : unit = add_i32 b (Int32.of_int v)

let encode (b : Buffer.t) (op : op) : unit =
  let opc name =
    let c = code_of name in
    if c > 0xFF then (Buffer.add_char b '\xFE'; Buffer.add_char b (Char.chr (c land 0xFF)))
    else Buffer.add_char b (Char.chr c) in
  let tok name t = opc name; add_int b t in
  (* a short form (one byte operand) or the long one; the numbered ones
   * (ldarg.0) for 0 to 3 *)
  let var short long numbered n =
    if numbered && n <= 3 then opc (short ^ "." ^ string_of_int n)
    else if n < 256 then (opc (short ^ ".s"); Buffer.add_char b (Char.chr n))
    else (opc long; Buffer.add_uint16_le b n) in
  (* a branch's target an offset: its distance from the end of this one *)
  let br name t = opc name; let here = Buffer.length b + 4 in add_int b (t - here) in
  match op with
  | Nop -> opc "nop" | Break -> opc "break"
  | Ldarg n -> var "ldarg" "ldarg" true n
  | Ldarga n -> var "ldarga" "ldarga" false n
  | Starg n -> var "starg" "starg" false n
  | Ldloc n -> var "ldloc" "ldloc" true n
  | Ldloca n -> var "ldloca" "ldloca" false n
  | Stloc n -> var "stloc" "stloc" true n
  | Ldnull -> opc "ldnull"
  | Ldc_i4 v ->
      let n = Int32.to_int v in
      if Int32.compare v (Int32.of_int (-1)) = 0 then opc "ldc.i4.m1"
      else if Int32.compare v Int32.zero >= 0 && Int32.compare v (Int32.of_int 8) <= 0 then
        opc ("ldc.i4." ^ string_of_int n)
      else if Int32.compare v (Int32.of_int (-128)) >= 0 && Int32.compare v (Int32.of_int 127) <= 0 then
        (opc "ldc.i4.s"; Buffer.add_char b (Char.chr (n land 0xFF)))
      else (opc "ldc.i4"; add_i32 b v)
  | Ldc_i8 v -> opc "ldc.i8"; Buffer.add_int64_le b v
  | Ldc_r f -> opc "ldc.r8"; Buffer.add_int64_le b (Int64.bits_of_float f)
  | Dup -> opc "dup" | Pop -> opc "pop"
  | Jmp t -> tok "jmp" t | Call t -> tok "call" t | Calli t -> tok "calli" t
  | Callvirt t -> tok "callvirt" t
  | Ret -> opc "ret"
  | Br t -> br "br" t
  | Brfalse t -> br "brfalse" t
  | Brtrue t -> br "brtrue" t
  | Bcmp (Ne, _, t) -> br "bne.un" t
  | Bcmp (c, u, t) -> br (if u then "b" ^ cmp_name c ^ ".un" else "b" ^ cmp_name c) t
  | Switch ts ->
      opc "switch"; add_int b (Array.length ts);
      let here = Buffer.length b + 4 * Array.length ts in
      Array.iter (fun t -> add_int b (t - here)) ts
  | Ldind k -> opc ("ldind." ^ kind_name k)
  | Stind k -> opc ("stind." ^ kind_name k)
  | Binop o -> opc (binop_name o)
  | Neg -> opc "neg" | Not -> opc "not"
  | Conv (k, ovf, un) ->
      opc ("conv." ^ (if ovf then "ovf." else "") ^ kind_name k ^ (if un then ".un" else ""))
  | Conv_r_un -> opc "conv.r.un"
  | Cpobj t -> tok "cpobj" t | Ldobj t -> tok "ldobj" t | Stobj t -> tok "stobj" t
  | Ldstr t -> tok "ldstr" t
  | Newobj t -> tok "newobj" t
  | Castclass t -> tok "castclass" t | Isinst t -> tok "isinst" t
  | Unbox t -> tok "unbox" t | Unbox_any t -> tok "unbox.any" t | Box t -> tok "box" t
  | Throw -> opc "throw" | Rethrow -> opc "rethrow"
  | Ldfld t -> tok "ldfld" t | Ldflda t -> tok "ldflda" t | Stfld t -> tok "stfld" t
  | Ldsfld t -> tok "ldsfld" t | Ldsflda t -> tok "ldsflda" t | Stsfld t -> tok "stsfld" t
  | Newarr t -> tok "newarr" t | Ldlen -> opc "ldlen"
  | Ldelema t -> tok "ldelema" t
  | Ldelem k -> opc ("ldelem." ^ kind_name k)
  | Ldelem_any t -> tok "ldelem" t
  | Stelem k -> opc ("stelem." ^ kind_name k)
  | Stelem_any t -> tok "stelem" t
  | Refanyval t -> tok "refanyval" t | Mkrefany t -> tok "mkrefany" t
  | Refanytype -> opc "refanytype"
  | Ckfinite -> opc "ckfinite"
  | Ldtoken t -> tok "ldtoken" t
  | Endfinally -> opc "endfinally"
  | Leave t -> br "leave" t
  | Ceq -> opc "ceq"
  | Cgt u -> opc (if u then "cgt.un" else "cgt")
  | Clt u -> opc (if u then "clt.un" else "clt")
  | Ldftn t -> tok "ldftn" t | Ldvirtftn t -> tok "ldvirtftn" t
  | Arglist -> opc "arglist" | Localloc -> opc "localloc" | Endfilter -> opc "endfilter"
  | Initobj t -> tok "initobj" t
  | Cpblk -> opc "cpblk" | Initblk -> opc "initblk"
  | Sizeof t -> tok "sizeof" t
  | Constrained t -> tok "constrained." t
  | Prefix p -> opc p

let map_tokens (f : int -> int) (op : op) : op =
  match op with
  | Jmp t -> Jmp (f t) | Call t -> Call (f t) | Calli t -> Calli (f t)
  | Callvirt t -> Callvirt (f t) | Cpobj t -> Cpobj (f t) | Ldobj t -> Ldobj (f t)
  | Stobj t -> Stobj (f t) | Ldstr t -> Ldstr (f t) | Newobj t -> Newobj (f t)
  | Castclass t -> Castclass (f t) | Isinst t -> Isinst (f t) | Unbox t -> Unbox (f t)
  | Unbox_any t -> Unbox_any (f t) | Box t -> Box (f t)
  | Ldfld t -> Ldfld (f t) | Ldflda t -> Ldflda (f t) | Stfld t -> Stfld (f t)
  | Ldsfld t -> Ldsfld (f t) | Ldsflda t -> Ldsflda (f t) | Stsfld t -> Stsfld (f t)
  | Newarr t -> Newarr (f t) | Ldelema t -> Ldelema (f t)
  | Ldelem_any t -> Ldelem_any (f t) | Stelem_any t -> Stelem_any (f t)
  | Refanyval t -> Refanyval (f t) | Mkrefany t -> Mkrefany (f t)
  | Ldtoken t -> Ldtoken (f t) | Ldftn t -> Ldftn (f t) | Ldvirtftn t -> Ldvirtftn (f t)
  | Initobj t -> Initobj (f t) | Sizeof t -> Sizeof (f t) | Constrained t -> Constrained (f t)
  | op -> op

(* Partition III's stack transitions; [call tok] is a method's
 * (arguments with `this`, has it a result) *)
let stack_effect (call : int -> int * bool) (returns : bool) (op : op) : int * int =
  match op with
  | Nop | Break | Br _ | Leave _ | Endfinally | Prefix _ | Constrained _ -> (0, 0)
  | Ldarg _ | Ldarga _ | Ldloc _ | Ldloca _ | Ldnull | Ldc_i4 _ | Ldc_i8 _ | Ldc_r _
  | Ldstr _ | Ldsfld _ | Ldsflda _ | Ldtoken _ | Ldftn _ | Sizeof _ | Arglist -> (0, 1)
  | Starg _ | Stloc _ | Pop | Brfalse _ | Brtrue _ | Switch _ | Stsfld _ | Throw
  | Initobj _ | Endfilter -> (1, 0)
  | Dup -> (1, 2)
  | Call t | Callvirt t | Jmp t -> let n, r = call t in (n, if r then 1 else 0)
  | Calli _ -> (1, 0)
  | Newobj t -> let n, _ = call t in (n - 1, 1)
  | Ret -> ((if returns then 1 else 0), 0)
  | Bcmp _ | Stind _ | Stfld _ | Stobj _ | Cpobj _ -> (2, 0)
  | Binop _ | Ceq | Cgt _ | Clt _ | Ldelem _ | Ldelem_any _ | Ldelema _ -> (2, 1)
  | Stelem _ | Stelem_any _ | Cpblk | Initblk -> (3, 0)
  | Ldind _ | Neg | Not | Conv _ | Conv_r_un | Ldobj _ | Castclass _ | Isinst _
  | Unbox _ | Unbox_any _ | Box _ | Ldfld _ | Ldflda _ | Newarr _ | Ldlen
  | Refanyval _ | Mkrefany _ | Refanytype | Ckfinite | Ldvirtftn _ | Localloc -> (1, 1)
  | Rethrow -> (0, 0)
