(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See CLI.mli *)

(* a machine's passes, over its opcodes *)
type 'm machine = {
  decode : string -> 'm option;
  show : 'm -> string;
  prepare : 'm Program.t -> unit;
  needs : 'm Program.prog list -> string list;
  ends : 'm Program.prog -> bool;
  rewrite : 'm Program.t -> unit;
  layout : 'm Program.t -> unit;
  encode : 'm Program.t -> Bytes.t;
}

let arm = { decode = Arm.decode; show = Arm.show; prepare = Arm.prepare; needs = Arm.needs; ends = Arm.ends;
            rewrite = Arm.rewrite; layout = Arm.layout; encode = Arm.encode }
let arm64 = { decode = Arm64.decode; show = Arm64.show; prepare = Arm64.prepare; needs = (fun _ -> []); ends = Arm64.ends;
              rewrite = Arm64.rewrite; layout = Arm64.layout; encode = Arm64.encode }

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

let print = Console.print and eprint = Console.eprint

(* -h: how, by examples, each one as it runs *)
let help = {|usage: mini-ld -m 5|7 [-H2|-H6|-H7|-H0 -T address] [-nofollow] [-v] [-E entry] [-o out] files...
5l and 7l's twin (-m 5: arm; 7: arm64): mini-asm's and mini-cc's objects, and
libraries, linked into an executable, a.out by default (-o: another), goken's
bytes: an ELF (-H7, the default), Plan 9's a.out (-H2), Mach-O (-H6), or no
header (-H0, a kernel's image: its text at -T's address, 0x80000 on the Pi 4). The
entry is _main (-E: another); -v lists each instruction, its address and word;
-nofollow lays the code in the objects' order, not along its flow as 5l: the
same behavior, not goken's bytes. With goken's hello (tests/s/hello_arch/):
  mini-asm -m 5 hello_linux_arm.s
  mini-ld -m 5 -E _start hello_linux_arm.5         a.out
  mini-5i a.out                                    Hello, world
  mini-ar u my.a hello.5                           a library, of mini-cc's hello
  mini-ld -m 5 -o hello my.a w/t/libc.a            (goken's libc: mini-cc -h)
An error names the file and the line: hello.c:0: undefined: print
|}

(* 5l's layout along the flow (Follow), unless -nofollow *)
let follow = ref true

(* -T and -R: the text's address and what the data's is rounded to
 * (5l's INITTEXT, INITRND), for an image without a header *)
let text_at = ref 0
let round = ref 4

(* -v: the listing (a flag here, not link's eighth parameter: mini-ml on
 * arm has 7) *)
let verbose = ref false

let link (m : _ machine) caps arch format entry out files =
  let t = Link.create arch ~text_start:0 in
  let headr = Exe.headr (format, arch) in
  (* 5l's and 7l's INITTEXT: after the header *)
  t.text_start <- (match format, arch with
    | Exe.Elf, Asm.Arm -> 0x8000 + headr | Exe.Elf, Asm.Arm64 -> 0x400000 + headr
    | Exe.Plan9, Asm.Arm -> 4096 + headr | Exe.Plan9, Asm.Arm64 -> 0x10000 + headr
    | Exe.Macho, _ -> (1 lsl 32) + headr
    | Exe.Raw, _ -> !text_at);
  t.data_round <- (match format, arch with
    | Exe.Macho, _ -> 0x4000 | Exe.Plan9, Asm.Arm64 -> 0x10000 | Exe.Raw, _ -> !round | _ -> 4096);
  t.pie <- format = Exe.Macho;
  (* the entry is the first name needed, before any object (5l's main) *)
  ignore (Link.lookup t entry 0);
  Link.load caps t ~decode:m.decode ~needs:m.needs files;
  m.prepare t;
  Link.resolve t;
  Link.layout_data t;
  if !follow then Follow.follow t ~ends:m.ends;
  Link.drop_nops t;
  m.rewrite t;
  m.layout t;
  let text = m.encode t in
  (* the listing, as 5l -a *)
  if !verbose then
    List.iter (fun (p : _ Program.prog) ->
      let w = if p.pc >= t.text_start && p.pc + 4 <= t.text_start + t.text_size then Bytes.get_int32_le text (p.pc - t.text_start) else 0l in
      print caps @@ Printf.sprintf "%08x: %08lx\t%s\n" p.pc w (Link.show m.show p)) t.progs;
  let data = Link.data_bytes t in
  Exe.write caps format arch out
    { text; data; bss = t.bss_size; text_start = t.text_start; data_start = t.data_start; entry = Link.entry t entry;
      pointers = Link.pointers t; round = t.data_round }

let main (caps : < caps; .. >) (argv : string array) : int =
  let arch = ref Asm.Arm and format = ref Exe.Elf and entry = ref "_main" and out = ref "a.out"
  and files = ref [] in
  let rec args = function
    | "-m" :: "5" :: rest -> arch := Asm.Arm; args rest
    | "-m" :: "7" :: rest -> arch := Asm.Arm64; args rest
    | "-H7" :: rest -> format := Exe.Elf; args rest
    | "-H2" :: rest -> format := Exe.Plan9; args rest
    | "-H6" :: rest -> format := Exe.Macho; args rest
    | "-H0" :: rest -> format := Exe.Raw; args rest
    (* (through Int64: a kernel's address has its top bits set, 0xffffff8000080000) *)
    | "-T" :: a :: rest -> text_at := Int64.to_int (Int64.of_string a); args rest
    | "-R" :: n :: rest -> round := int_of_string n; args rest
    | "-E" :: e :: rest -> entry := e; args rest
    | "-o" :: o :: rest -> out := o; args rest
    | "-s" :: rest -> args rest
    | "-v" :: rest -> verbose := true; args rest
    | "-nofollow" :: rest -> follow := false; args rest
    | f :: rest -> files := f :: !files; args rest
    | [] -> ()
  in
  args (List.tl (Array.to_list argv));
  let files = List.rev !files in
  match files with
  | _ when List.mem "-h" files || List.mem "--help" files -> print caps help; 0
  | [] -> eprint caps "usage: mini-ld -m 5|7 [-H2|-H6|-H7|-H0 -T address] [-nofollow] [-E entry] [-o out] files...   (-h: how)\n"; 1
  | _ -> (
      try
        let path s = match Files.path s with Ok p -> p | Error m -> failwith m in
        let files = List.map path files and out = path !out in
        (match !arch with
          | Asm.Arm -> link arm caps !arch !format !entry out files
          | Asm.Arm64 -> link arm64 caps !arch !format !entry out files);
        0
      with Link.Error m | Sys_error m | Failure m -> eprint caps ("mini-ld: " ^ m ^ "\n"); 1)
