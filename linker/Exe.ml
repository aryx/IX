(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Exe.mli *)

type format = Elf | Plan9 | Macho | Raw

type image = { text : Bytes.t; data : Bytes.t; bss : int; text_start : int; data_start : int; entry : int;
               pointers : int list; round : int; syms : string; lines : string;
               elf_syms : (string * int * int * bool * bool) list }

let headr = function
  | Raw, _ -> 0
  | Plan9, Asm.Arm -> 32
  | Plan9, Asm.Arm64 -> 40
  | Macho, _ -> 3 * 1024
  | Elf, Asm.Arm -> Link.rnd (52 + (3 * 32)) 16
  | Elf, Asm.Arm64 -> Link.rnd (64 + (3 * 56)) 16

let page = 4096

(* the bytes of a file, grown as written at an offset (5l's seek and
 * cput) *)
type out = { mutable b : Bytes.t; mutable len : int }

let at o off (s : Bytes.t) =
  if Bytes.length s > 0 then
  let n = off + Bytes.length s in
  if n > Bytes.length o.b then (let b = Bytes.make (max n (2 * Bytes.length o.b)) '\000' in Bytes.blit o.b 0 b 0 o.len; o.b <- b);
  (Bytes.blit s 0 o.b off (Bytes.length s);
   o.len <- max o.len n)

(* a header's fields, little-endian: W 2 bytes, L 4, Q 8, S bytes *)
open Binary
let fields (fs : field list) = Bytes.of_string (le fs)

(* ELF, as goken's liblk/elf.c (elf32, elf64) writes it: three program
 * headers (text, data and bss, an empty one for Plan 9's symbols) and
 * three sections, the table after the data as 5l puts it. 5l puts it
 * at HEADR+text+data, which is inside the data's page when the data is
 * large: there, and only there, mini-ld puts it after the data *)
let elf arch (i : image) =
  let is64 = arch = Asm.Arm64 in
  let h = headr (Elf, arch) and tsize = Bytes.length i.text and dsize = Bytes.length i.data in
  let doff = Link.rnd (h + tsize) page in
  (* the headers and the names: 22 bytes, of which the header says 14 (5l's) *)
  let names = "\000.text\000.data\000.strtab\000\000" in
  let shsize = (if is64 then 3 * 64 else 3 * 40) + String.length names in
  let shoff = h + tsize + dsize in
  let shoff = if dsize > 0 && shoff + shsize > doff && shoff < doff + dsize then doff + dsize else shoff in
  let addr v = if is64 then Q v else L v in
  let phdr typ off va filesz memsz prot align =
    if is64 then fields [ L typ; L prot; Q off; Q va; Q va; Q filesz; Q memsz; Q align ]
    else fields [ L typ; L off; L va; L va; L filesz; L memsz; L prot; L align ]
  in
  let shdr name typ flags va off size align =
    if is64 then fields [ L name; L typ; Q flags; Q va; Q off; Q size; L 0; L 0; Q align; Q 0 ]
    else fields [ L name; L typ; L flags; L va; L off; L size; L 0; L 0; L align; L 0 ]
  in
  let ehsize, phsize, shentsize = if is64 then 64, 56, 64 else 52, 32, 40 in
  let header = fields
      [ S "\127ELF"; S (String.make 1 (Char.chr (if is64 then 2 else 1))); S "\001\001\000\000"; S (String.make 7 '\000');
        W 2 (* EXEC *); W (if is64 then 183 else 40); L 1; addr i.entry; addr ehsize; addr shoff;
        L (if is64 then 0 else 0x5000200) (* EABI 5, for Linux *);
        W ehsize; W phsize; W 3; W shentsize; W 3; W 2 ] in
  let o = { b = Bytes.create 0; len = 0 } in
  at o 0 header;
  at o ehsize (phdr 1 h i.text_start tsize tsize 5 page);
  at o (ehsize + phsize) (phdr 1 doff i.data_start dsize (dsize + i.bss) (if is64 then 6 else 7) page);
  at o (ehsize + (2 * phsize)) (phdr 0 (h + tsize + dsize) 0 0 0 4 4);
  at o h i.text;
  at o doff i.data;
  at o shoff (Bytes.cat
    (Bytes.concat Bytes.empty
       [ shdr 1 1 6 i.text_start h tsize 0x10000; shdr 7 1 3 i.data_start doff dsize 0x10000;
         shdr 13 3 (1 lsl 5) 0 (shoff + shsize - String.length names) 14 1 ])
    (Bytes.of_string names));
  Bytes.sub o.b 0 o.len

(* -g's ELF (plan_debugger.md, stage 8a), not goken's (which has no
 * symbols): the same loads, and sections a debugger reads, after the
 * data, then their headers:
 *
 *     0 null  1 .text  2 .data  3 .bss  4 .shstrtab
 *     5 .symtab  6 .strtab        ELF's names (nm, gdb, perf): the
 *                                 locals first, as ELF wants
 *     7 .plan9.syms  8 .plan9.lines  Plan 9's two tables (Symtab), the
 *                                 files and lines mini-acid reads *)
let elf_g arch (i : image) =
  let is64 = arch = Asm.Arm64 in
  let h = headr (Elf, arch) and tsize = Bytes.length i.text and dsize = Bytes.length i.data in
  let doff = Link.rnd (h + tsize) page in
  let names = "\000.text\000.data\000.bss\000.shstrtab\000.symtab\000.strtab\000.plan9.syms\000.plan9.lines\000" in
  let name s = let rec find k = if String.sub names k (String.length s + 1) = s ^ "\000" then k else find (k + 1) in find 1 in
  let addr v = if is64 then Q v else L v in
  (* the symbols: locals first; 16 bytes each on 32 bits, 24 on 64 *)
  let syms = List.stable_sort (fun (_, _, _, _, g1) (_, _, _, _, g2) -> compare g1 g2) i.elf_syms in
  let strtab = Buffer.create 4096 in
  Buffer.add_char strtab '\000';
  let entry (n, v, size, func, global) =
    let off = Buffer.length strtab in
    Buffer.add_string strtab n; Buffer.add_char strtab '\000';
    let info = ((if global then 1 else 0) lsl 4) lor (if func then 2 else 1) in
    let shndx = if func then 1 else if v >= i.data_start + dsize then 3 else 2 in
    if is64 then fields [ L off; S (String.make 1 (Char.chr info)); S "\000"; W shndx; Q v; Q size ]
    else fields [ L off; L v; L size; S (String.make 1 (Char.chr info)); S "\000"; W shndx ] in
  let symtab = Bytes.concat Bytes.empty (Bytes.make (if is64 then 24 else 16) '\000' :: List.map entry syms) in
  let nlocal = 1 + List.length (List.filter (fun (_, _, _, _, g) -> not g) syms) in
  let strtab = Buffer.contents strtab in
  let base = doff + dsize in
  let off_names = base in
  let off_symtab = Link.rnd (off_names + String.length names) 8 in
  let off_strtab = off_symtab + Bytes.length symtab in
  let off_syms = off_strtab + String.length strtab in
  let off_lines = off_syms + String.length i.syms in
  let shoff = Link.rnd (off_lines + String.length i.lines) 8 in
  let phdr typ off va filesz memsz prot align =
    if is64 then fields [ L typ; L prot; Q off; Q va; Q va; Q filesz; Q memsz; Q align ]
    else fields [ L typ; L off; L va; L va; L filesz; L memsz; L prot; L align ] in
  let shdr nm typ flags va off size link info align entsize =
    if is64 then fields [ L nm; L typ; Q flags; Q va; Q off; Q size; L link; L info; Q align; Q entsize ]
    else fields [ L nm; L typ; L flags; L va; L off; L size; L link; L info; L align; L entsize ] in
  let ehsize, phsize, shentsize = if is64 then 64, 56, 64 else 52, 32, 40 in
  let header = fields
      [ S "\127ELF"; S (String.make 1 (Char.chr (if is64 then 2 else 1))); S "\001\001\000\000"; S (String.make 7 '\000');
        W 2; W (if is64 then 183 else 40); L 1; addr i.entry; addr ehsize; addr shoff;
        L (if is64 then 0 else 0x5000200);
        W ehsize; W phsize; W 2; W shentsize; W 9; W 4 ] in
  let o = { b = Bytes.create 0; len = 0 } in
  at o 0 header;
  at o ehsize (phdr 1 h i.text_start tsize tsize 5 page);
  at o (ehsize + phsize) (phdr 1 doff i.data_start dsize (dsize + i.bss) (if is64 then 6 else 7) page);
  at o h i.text;
  at o doff i.data;
  at o off_names (Bytes.of_string names);
  at o off_symtab symtab;
  at o off_strtab (Bytes.of_string strtab);
  at o off_syms (Bytes.of_string i.syms);
  at o off_lines (Bytes.of_string i.lines);
  at o shoff (Bytes.concat Bytes.empty
    [ Bytes.make shentsize '\000';
      shdr (name ".text") 1 6 i.text_start h tsize 0 0 16 0;
      shdr (name ".data") 1 3 i.data_start doff dsize 0 0 16 0;
      shdr (name ".bss") 8 3 (i.data_start + dsize) (doff + dsize) i.bss 0 0 16 0;
      shdr (name ".shstrtab") 3 0 0 off_names (String.length names) 0 0 1 0;
      shdr (name ".symtab") 2 0 0 off_symtab (Bytes.length symtab) 6 nlocal 8 (if is64 then 24 else 16);
      shdr (name ".strtab") 3 0 0 off_strtab (String.length strtab) 0 0 1 0;
      shdr (name ".plan9.syms") 1 0 0 off_syms (String.length i.syms) 0 0 1 0;
      shdr (name ".plan9.lines") 1 0 0 off_lines (String.length i.lines) 0 0 1 0 ]);
  Bytes.sub o.b 0 o.len

(* Plan 9's a.out (5l's and 7l's asmb, H_PLAN9): a big-endian header,
 * the text, the data right after it; arm64's header adds the entry in
 * 64 bits *)
let plan9 arch (i : image) =
  let magic, entry, extra = match arch with
    | Asm.Arm -> 0x647, i.entry, []
    | Asm.Arm64 -> 0x8000 lor ((4 * 28 * 28) + 7), i.entry land 0x0fffffff, [ Q i.entry ] in
  let header = [ L magic; L (Bytes.length i.text); L (Bytes.length i.data); L i.bss; L (String.length i.syms); L entry; L 0;
                 L (String.length i.lines) ] in
  Bytes.concat Bytes.empty [ Bytes.of_string (be (header @ extra)); i.text; i.data; Bytes.of_string i.syms; Bytes.of_string i.lines ]

(* Mach-O for arm64 macOS (goken's liblk/macho.c): the header and load
 * commands in the first 3 KB, which __TEXT maps with the text; then
 * __DATA, and __LINKEDIT with the rebase stream of the data's
 * pointers. The kernel wants what a static executable lacks: PIE, dyld
 * and libSystem named, LC_MAIN; codesign adds the signature *)
let macho (i : image) =
  let h = headr (Macho, Asm.Arm64) and round = i.round in
  let tsize = Bytes.length i.text and dsize = Bytes.length i.data in
  let va = i.text_start - h in
  let v = Link.rnd (h + tsize) round and w = Link.rnd (dsize + i.bss) round in
  (* the rebase stream: pointers, then DONE, to 8 bytes *)
  let rebase =
    if i.pointers = [] then ""
    else begin
      let b = Buffer.create 64 in
      let rec uleb x = let c = x land 0x7f and x = x lsr 7 in Buffer.add_char b (Char.chr (if x <> 0 then c lor 0x80 else c)); if x <> 0 then uleb x in
      Buffer.add_char b '\017';
      List.iter (fun o -> Buffer.add_char b '"'; uleb o; Buffer.add_char b 'Q') i.pointers;
      Buffer.add_char b '\000';
      while Buffer.length b land 7 <> 0 do Buffer.add_char b '\000' done;
      Buffer.contents b
    end
  in
  let name s = S (s ^ String.make (16 - String.length s) '\000') in
  let seg nm ~vaddr ~vsize ~off ~size ~prot sects =
    fields ([ L 25; L (72 + (80 * List.length sects)); name nm; Q vaddr; Q vsize; Q off; Q size; L prot; L prot;
              L (List.length sects); L 0 ]
            @ List.concat_map (fun (sn, addr, size, off, align, flag) ->
                [ name sn; name nm; Q addr; Q size; L off; L align; L 0; L 0; L flag; L 0; L 0; L 0 ]) sects)
  in
  (* a load command of n words, strings included, n made even *)
  let load cmd n ws =
    let n = if n land 1 = 1 then n + 1 else n in
    let body = fields ws in
    Bytes.cat (fields [ L cmd; L (4 * (n + 2)) ]) (Bytes.cat body (Bytes.make ((4 * n) - Bytes.length body) '\000'))
  in
  let dsz = Link.rnd dsize round in
  let segs =
    [ seg "__PAGEZERO" ~vaddr:0 ~vsize:va ~off:0 ~size:0 ~prot:0 [];
      seg "__TEXT" ~vaddr:va ~vsize:v ~off:0 ~size:v ~prot:5 [ "__text", i.text_start, tsize, h, 2, 0x400 ];
      seg "__DATA" ~vaddr:i.data_start ~vsize:w ~off:v ~size:dsz ~prot:3
        [ "__data", i.data_start, dsize, v, 3, 0; "__bss", i.data_start + dsize, i.bss, 0, 0, 1 ];
      seg "__LINKEDIT" ~vaddr:(i.data_start + w) ~vsize:(Link.rnd (String.length rebase) round) ~off:(v + dsz)
        ~size:(String.length rebase) ~prot:1 [] ] in
  let dylib = "/usr/lib/libSystem.B.dylib" in
  let e = i.entry - i.text_start + h in
  let loads =
    (if rebase = "" then [] else [ load 0x80000022 10 [ L (v + dsz); L (String.length rebase) ] ])
    @ [ load 0x32 4 [ L 1; L (11 lsl 16); L (11 lsl 16); L 0 ];
        load 2 4 []; load 11 18 [];
        load 14 6 [ L 12; S "/usr/lib/dyld" ];
        load 12 (4 + ((String.length dylib + 1 + 7) / 8 * 2)) [ L 24; L 0; L (1 lsl 16); L (1 lsl 16); S dylib ];
        load 0x80000028 4 [ L e; L (e lsr 32) ] ] in
  let cmds = Bytes.concat Bytes.empty (segs @ loads) in
  if 32 + Bytes.length cmds > h then Link.error "HEADR too small";
  let header = fields [ L 0xfeedfacf; L ((1 lsl 24) lor 12); L 0; L 2; L (List.length segs + List.length loads);
                        L (Bytes.length cmds); L (1 lor 4 lor 0x80 lor 0x200000); L 0 ] in
  let o = { b = Bytes.create 0; len = 0 } in
  at o 0 (Bytes.cat header cmds);
  at o h i.text;
  at o v i.data;
  (* the data padded to its pages, then __LINKEDIT *)
  at o (v + dsz) (Bytes.of_string rebase);
  if o.len < v + dsz && dsize > 0 then at o (v + dsz - 1) (Bytes.make 1 '\000');
  Bytes.sub o.b 0 o.len

let write caps format arch file i =
  (* raw (7l's -H0): the text, the data right after it, as a board's firmware loads a kernel *)
  let b = match format with Elf when i.elf_syms <> [] -> elf_g arch i | Elf -> elf arch i | Plan9 -> plan9 arch i | Macho -> macho i | Raw -> Bytes.cat i.text i.data in
  FS.write_perm caps 0o755 file (Bytes.to_string b)
