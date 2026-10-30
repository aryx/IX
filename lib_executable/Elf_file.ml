(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Elf_file.mli *)

type section = { sname : string; styp : int; sflags : int; addr : int; offset : int; size : int; link : int; entsize : int }
type segment = { vaddr : int; foffset : int; filesz : int; memsz : int; pflags : int }

type t = { bits : int; machine : int; entry : int; sections : section list; segments : segment list }

(* little-endian numbers of 1, 2, 4 and 8 bytes *)
let u8 s o = Char.code s.[o]
let u16 s o = u8 s o lor (u8 s (o + 1) lsl 8)
let u32 s o = u16 s o lor (u16 s (o + 2) lsl 16)
let u64 s o = u32 s o lor (u32 s (o + 4) lsl 32)

let is_elf s = String.length s >= 52 && String.sub s 0 4 = "\x7fELF" && u8 s 5 = 1

let cstring s o = match String.index_from_opt s o '\000' with Some e -> String.sub s o (e - o) | None -> ""

let read s =
  if not (is_elf s) then None
  else
    let b64 = u8 s 4 = 2 in
    (* a field of the size of an address, an offset *)
    let word o = if b64 then u64 s o else u32 s o in
    let machine = u16 s 18 in
    let entry = word 24 in
    let phoff = word (if b64 then 32 else 28) and shoff = word (if b64 then 40 else 32) in
    let h = if b64 then 52 else 40 in
    let phentsize = u16 s (h + 2) and phnum = u16 s (h + 4) in
    let shentsize = u16 s (h + 6) and shnum = u16 s (h + 8) and shstrndx = u16 s (h + 10) in
    let ok o n = o >= 0 && o + n <= String.length s in
    let segments = List.filter_map (fun i ->
      let o = phoff + (i * phentsize) in
      if not (ok o phentsize) || u32 s o <> 1 (* PT_LOAD *) then None
      else if b64 then
        Some { vaddr = u64 s (o + 16); foffset = u64 s (o + 8); filesz = u64 s (o + 32); memsz = u64 s (o + 40); pflags = u32 s (o + 4) }
      else
        Some { vaddr = u32 s (o + 8); foffset = u32 s (o + 4); filesz = u32 s (o + 16); memsz = u32 s (o + 20); pflags = u32 s (o + 24) })
      (List.init phnum Fun.id) in
    let raw = List.filter_map (fun i ->
      let o = shoff + (i * shentsize) in
      if not (ok o shentsize) then None
      else if b64 then
        Some (u32 s o, { sname = ""; styp = u32 s (o + 4); sflags = u64 s (o + 8); addr = u64 s (o + 16); offset = u64 s (o + 24);
                         size = u64 s (o + 32); link = u32 s (o + 40); entsize = u64 s (o + 56) })
      else
        Some (u32 s o, { sname = ""; styp = u32 s (o + 4); sflags = u32 s (o + 8); addr = u32 s (o + 12); offset = u32 s (o + 16);
                         size = u32 s (o + 20); link = u32 s (o + 24); entsize = u32 s (o + 36) }))
      (List.init shnum Fun.id) in
    let names = match List.nth_opt raw shstrndx with Some (_, sec) -> sec.offset | None -> -1 in
    let sections = List.map (fun (n, sec) -> { sec with sname = (if names >= 0 && ok (names + n) 1 then cstring s (names + n) else "") }) raw in
    Some { bits = (if b64 then 64 else 32); machine; entry; sections; segments }

let section e name = List.find_opt (fun sec -> sec.sname = name) e.sections

let bytes s (sec : section) =
  if sec.styp = 8 (* SHT_NOBITS *) || sec.offset + sec.size > String.length s then "" else String.sub s sec.offset sec.size

let file_offset e a =
  List.find_map (fun g -> if a >= g.vaddr && a < g.vaddr + g.filesz then Some (g.foffset + (a - g.vaddr)) else None) e.segments

let text_segment e = List.find_opt (fun g -> g.pflags land 1 <> 0) e.segments
let data_segment e = List.find_opt (fun g -> g.pflags land 1 = 0 && g.pflags land 2 <> 0) e.segments

(* the letters nm prints: a function T, an object D or B by its
 * section, lower case when local *)
let symbols s e =
  match section e ".symtab" with
  | None -> []
  | Some st ->
      let strs = match List.nth_opt e.sections st.link with Some sec -> sec.offset | None -> 0 in
      let n = if st.entsize = 0 then 0 else st.size / st.entsize in
      List.filter_map (fun i ->
        let o = st.offset + (i * st.entsize) in
        let name, info, shndx, value =
          if e.bits = 64 then cstring s (strs + u32 s o), u8 s (o + 4), u16 s (o + 6), u64 s (o + 8)
          else cstring s (strs + u32 s o), u8 s (o + 12), u16 s (o + 14), u32 s (o + 4) in
        let typ = info land 15 and bind = info lsr 4 in
        let letter =
          match typ, List.nth_opt e.sections shndx with
          | 2, _ -> Some 'T'
          | 1, Some sec -> Some (if sec.styp = 8 then 'B' else 'D')
          | 0, Some sec when name <> "" && shndx > 0 && shndx < 0xff00 && name.[0] <> '$' ->
              (* (an assembler's label: gcc's _start, a hand-written function) *)
              Some (if sec.sflags land 4 <> 0 then 'T' else if sec.styp = 8 then 'B' else 'D')
          | _ -> None in
        match letter with
        | Some c when name <> "" && shndx <> 0 (* not an undefined one, a library's *) -> Some ({ value; typ = (if bind = 0 then Char.lowercase_ascii c else c); name } : Symbols.sym)
        | _ -> None)
        (List.init n Fun.id)
