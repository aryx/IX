(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Elf.mli *)

type machine = Arm | Aarch64 | Other of int
type segment = { offset : int; vaddr : int; paddr : int; filesz : int; memsz : int; exec : bool }
type t = { machine : machine; entry : int; segments : segment list }

exception Bad of string

let parse s =
  if String.length s < 52 || String.sub s 0 4 <> "\x7fELF" then raise (Bad "not an ELF file");
  if s.[5] <> '\001' then raise (Bad "not little-endian");
  let wide = match s.[4] with '\001' -> false | '\002' -> true | _ -> raise (Bad "bad class") in
  let u16 o = String.get_uint16_le s o in
  let u32 o = Bits.of_int32 (String.get_int32_le s o) in
  (* 64-bit fields: the low 32 bits, the programs being small *)
  let addr o = if wide then u32 o else u32 o in
  let machine = match u16 18 with 40 -> Arm | 183 -> Aarch64 | n -> Other n in
  let entry = addr 24 in
  let phoff = if wide then u32 32 else u32 28 in
  let phentsize = u16 (if wide then 54 else 42) and phnum = u16 (if wide then 56 else 44) in
  let segments = List.filter_map (fun i ->
    let p = phoff + (i * phentsize) in
    if u32 p <> 1 then None
    else if wide then Some { offset = u32 (p + 8); vaddr = u32 (p + 16); paddr = u32 (p + 24); filesz = u32 (p + 32); memsz = u32 (p + 40); exec = u32 (p + 4) land 1 <> 0 }
    else Some { offset = u32 (p + 4); vaddr = u32 (p + 8); paddr = u32 (p + 12); filesz = u32 (p + 16); memsz = u32 (p + 20); exec = u32 (p + 24) land 1 <> 0 })
    (List.init phnum Fun.id) in
  { machine; entry; segments }

(* the symbol table (SHT_SYMTAB, its names in the section it links to):
 * the symbols of a section (not undefined, absolute or common), not
 * the ARM mapping symbols ($a, $d, $x) *)
let symbols s =
  if String.length s < 52 || String.sub s 0 4 <> "\x7fELF" then raise (Bad "not an ELF file");
  let wide = String.length s > 4 && s.[4] = '\002' in
  let u16 o = String.get_uint16_le s o in
  let u32 o = Bits.of_int32 (String.get_int32_le s o) in
  let u64 o = String.get_int64_le s o in
  let word o = if wide then Int64.to_int (u64 o) else u32 o in
  let shoff = word (if wide then 40 else 32) in
  let shentsize = u16 (if wide then 58 else 46) and shnum = u16 (if wide then 60 else 48) in
  let section i = shoff + (i * shentsize) in
  let offset sh = word (sh + if wide then 24 else 16) and size sh = word (sh + if wide then 32 else 20) in
  let cstring o = String.sub s o (String.index_from s o '\000' - o) in
  List.concat_map (fun i ->
    let sh = section i in
    if shoff = 0 || u32 (sh + 4) <> 2 then []
    else begin
      let strtab = offset (section (u32 (sh + if wide then 40 else 24))) in
      let entsize = if wide then 24 else 16 in
      List.filter_map (fun k ->
        let e = offset sh + (k * entsize) in
        let name = cstring (strtab + u32 e) in
        let shndx = u16 (e + if wide then 6 else 14) in
        let value = if wide then u64 (e + 8) else Int64.of_int (u32 (e + 4)) in
        if name = "" || name.[0] = '$' || shndx = 0 || shndx >= 0xff00 then None else Some (value, name))
        (List.init (size sh / entsize) Fun.id)
    end)
    (List.init shnum Fun.id)
