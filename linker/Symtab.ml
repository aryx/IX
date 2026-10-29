(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Symtab.mli *)

open Program

(* a value of 4 bytes, the high first *)
let be32 b (v : int) = for k = 3 downto 0 do Buffer.add_char b (Char.chr ((v lsr (8 * k)) land 255)) done

(* an entry (5l's putsymb): a static's letter in lower case *)
let put b version typ value name =
  be32 b value;
  Buffer.add_char b (Char.chr (Char.code (if version <> 0 then Char.lowercase_ascii typ else typ) + 0x80));
  Buffer.add_string b name;
  Buffer.add_char b '\000'

(* a path's entry: its files' numbers, 2 bytes each, after a NUL and
 * before two *)
let put_hist b (files : int list) line =
  be32 b line;
  Buffer.add_char b (Char.chr (Char.code 'z' + 0x80));
  Buffer.add_char b '\000';
  List.iter (fun k -> Buffer.add_char b (Char.chr ((k lsr 8) land 255)); Buffer.add_char b (Char.chr (k land 255))) files;
  Buffer.add_string b "\000\000"

let symbols (t : _ Program.t) =
  let b = Buffer.create 4096 in
  (match Hashtbl.find_opt t.syms ("etext", 0) with Some ({ kind = Text; _ } as s) -> put b 0 'T' s.value s.name | _ -> ());
  let syms = Hashtbl.fold (fun _ s acc -> match s.kind with Data | Bss | File -> s :: acc | Undefined | Text -> acc) t.syms [] in
  let syms = List.sort (fun a b -> compare (Link.bucket t.arch a.name a.version, - a.created) (Link.bucket t.arch b.name b.version, - b.created)) syms in
  List.iter (fun s -> match s.kind with
    | Data -> put b s.version 'D' (s.value + t.data_start) s.name
    | Bss -> put b s.version 'B' (s.value + t.data_start) s.name
    (* (the name without its "<") *)
    | File -> put b 0 'f' s.value (String.sub s.name 1 (String.length s.name - 1))
    | Undefined | Text -> ()) syms;
  List.iter (fun (p : _ prog) ->
    match p.op, p.args with
    | Func, Asm.Mem { name = Some n; _ } :: _ ->
        let s = Link.sym_of t p.version n in
        List.iter (function Hist (files, line) -> put_hist b files line | Param _ | Local _ -> ()) p.autos;
        put b s.version (if p.leaf then 'L' else 'T') s.value s.name;
        put b 0 'm' (p.frame + 4) ".frame";
        List.iter (function Local (n, o) -> put b 0 'a' (- o) n | Param (n, o) -> put b 0 'p' o n | Hist _ -> ()) p.autos
    | _ -> ()) t.progs;
  Buffer.contents b

(* the smallest step of the pc, an instruction (5l's MINLC) *)
let minlc = 4

let lines (t : _ Program.t) =
  let b = Buffer.create 4096 in
  let byte v = Buffer.add_char b (Char.chr (v land 255)) in
  let oldpc = ref t.text_start and oldlc = ref 0 in
  List.iter (fun (p : _ prog) ->
    let line = snd p.where in
    if line <> !oldlc && p.op <> Func && p.op <> Nop then begin
      let v = ref ((p.pc - !oldpc) / minlc) in
      while !v > 0 do let s = min !v 127 in byte (s + 128); v := !v - s done;
      let s = line - !oldlc in
      oldlc := line;
      oldpc := p.pc + minlc;
      if s > 64 || s < -64 then (byte 0; be32 b s)
      else if s > 0 then byte s
      else byte (64 - s)
    end) t.progs;
  while Buffer.length b land 1 = 1 do byte 129 done;
  Buffer.contents b
