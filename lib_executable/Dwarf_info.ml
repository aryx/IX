(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Dwarf_info.mli *)

type value = Int of int | Str of string | Ref of int | Block of string | Flag

type die = { off : int; tag : int; attrs : (int * value) list; children : die list }

type cur = { s : string; mutable o : int }

let u8 c = let v = Char.code c.s.[c.o] in c.o <- c.o + 1; v
let un c n = let v = ref 0 in for k = 0 to n - 1 do v := !v lor (u8 c lsl (8 * k)) done; !v
let uleb c =
  let rec go v sh = let b = u8 c in let v = v lor ((b land 0x7f) lsl sh) in if b land 0x80 <> 0 then go v (sh + 7) else v in
  go 0 0
let sleb c =
  let rec go v sh =
    let b = u8 c in
    let v = v lor ((b land 0x7f) lsl sh) in
    if b land 0x80 <> 0 then go v (sh + 7)
    else if b land 0x40 <> 0 && sh + 7 < 63 then v lor (-1 lsl (sh + 7)) else v in
  go 0 0
let cstr c = match String.index_from_opt c.s c.o '\000' with
  | Some e -> let v = String.sub c.s c.o (e - c.o) in c.o <- e + 1; v
  | None -> c.o <- String.length c.s; ""
let strat s o = if o >= 0 && o < String.length s then (match String.index_from_opt s o '\000' with Some e -> String.sub s o (e - o) | None -> "") else ""
let block c n = let v = String.sub c.s c.o n in c.o <- c.o + n; Block v

(* an abbreviation: its tag, whether it has children, its attributes
 * and their forms (an implicit constant's value with it) *)
type abbrev = { atag : int; kids : bool; specs : (int * int * int) list }

let abbrevs s o =
  let c = { s; o } in
  let t = Hashtbl.create 64 in
  let rec go () =
    match uleb c with
    | 0 -> ()
    | code ->
        let atag = uleb c in
        let kids = u8 c <> 0 in
        let rec specs acc =
          match uleb c, uleb c with
          | 0, 0 -> List.rev acc
          | a, 0x21 -> let k = sleb c in specs ((a, 0x21, k) :: acc)
          | a, f -> specs ((a, f, 0) :: acc) in
        Hashtbl.replace t code { atag; kids; specs = specs [] };
        go () in
  (try go () with Invalid_argument _ -> ());
  t

(* a value of a form (DW_FORM_...); a reference made absolute (unit:
 * its unit's offset) *)
let rec form c ~asize ~unit_ ~str ~line_str f k =
  match f with
  | 0x01 -> Int (un c asize)
  | 0x0b | 0x11 -> let v = u8 c in if f = 0x11 then Ref (unit_ + v) else Int v
  | 0x05 | 0x12 -> let v = un c 2 in if f = 0x12 then Ref (unit_ + v) else Int v
  | 0x06 | 0x13 -> let v = un c 4 in if f = 0x13 then Ref (unit_ + v) else Int v
  | 0x07 | 0x14 -> let v = un c 8 in if f = 0x14 then Ref (unit_ + v) else Int v
  | 0x15 -> Ref (unit_ + uleb c)
  | 0x10 | 0x17 -> Int (un c 4)                  (* ref_addr, sec_offset (32-bit DWARF) *)
  | 0x0d -> Int (sleb c)
  | 0x0f -> Int (uleb c)
  | 0x08 -> Str (cstr c)
  | 0x0e -> Str (strat str (un c 4))
  | 0x1f -> Str (strat line_str (un c 4))
  | 0x0c -> Int (u8 c)
  | 0x19 -> Flag
  | 0x21 -> Int k
  | 0x18 | 0x09 -> let n = uleb c in block c n
  | 0x0a -> let n = u8 c in block c n
  | 0x03 -> let n = un c 2 in block c n
  | 0x04 -> let n = un c 4 in block c n
  | 0x1e -> block c 16
  | 0x16 -> let f = uleb c in form c ~asize ~unit_ ~str ~line_str f k
  | f -> failwith (Printf.sprintf "DWARF: form 0x%x" f)

let read file (e : Elf_file.t) =
  let bytes name = match Elf_file.section e name with Some s -> Elf_file.bytes file s | None -> "" in
  let info = bytes ".debug_info" and abbrev = bytes ".debug_abbrev" in
  let str = bytes ".debug_str" and line_str = bytes ".debug_line_str" in
  let c = { s = info; o = 0 } in
  let units = ref [] in
  (try
    while c.o + 11 <= String.length info do
      let unit_ = c.o in
      let len = un c 4 in
      let next = c.o + len in
      let version = un c 2 in
      let aoff, asize =
        if version >= 5 then (let _unit_type = u8 c in let asize = u8 c in let aoff = un c 4 in aoff, asize)
        else (let aoff = un c 4 in let asize = u8 c in aoff, asize) in
      let table = abbrevs abbrev aoff in
      (* the entries, a tree: an entry with children has them up to a 0 *)
      let rec entries acc =
        if c.o >= next then List.rev acc
        else
          let off = c.o in
          match uleb c with
          | 0 -> List.rev acc
          | code ->
              let a = match Hashtbl.find_opt table code with Some a -> a | None -> failwith "DWARF: abbreviation" in
              let attrs = List.map (fun (at, f, k) -> at, form c ~asize ~unit_ ~str ~line_str f k) a.specs in
              let children = if a.kids then entries [] else [] in
              entries ({ off; tag = a.atag; attrs; children } :: acc) in
      units := entries [] @ !units;
      c.o <- next
    done
  with Failure _ | Invalid_argument _ -> ());
  List.rev !units

let attr (d : die) a = List.assoc_opt a d.attrs
let name d = match attr d 0x03 with Some (Str s) -> Some s | _ -> None
let int d a = match attr d a with Some (Int n) -> Some n | _ -> None
let ref_ d a = match attr d a with Some (Ref r) -> Some r | _ -> None

let index units =
  let t = Hashtbl.create 256 in
  let rec add d = Hashtbl.replace t d.off d; List.iter add d.children in
  List.iter add units;
  t
