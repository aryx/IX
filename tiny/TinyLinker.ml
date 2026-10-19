(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyLinker.mli *)

open TinyMachineCPU

(* -h: how, by examples, each one as it runs *)
let help = {|usage: tiny-linker [-a megabytes] [-map] -o out file.o...

tiny-assembler's objects to an image for tiny-cpu or tiny-machine: the files one
after the other from address 0, their labels one name space, each place a
label's address goes filled. With -a, an executable for tiny-kernel that asks
for that much memory: a header (a magic number, the image's size, the memory),
then the image. With -map, out.map too: each label's address, by address (what
tiny-prof reads). In tiny/tests/TinyCPU_tests/, for example:
  tiny-assembler hello.tm && tiny-linker -o hello hello.o
  tiny-cpu hello                           Hello, world
  tiny-linker -a 10 -o prog start.o prog.o      an a.out of 10 MB for tiny-kernel
An error names the label: undefined label main
|}

(*****************************************************************************)
(* The objects *)
(*****************************************************************************)

(* an object's items (TinyAssembler's lines): a code's bytes come with
 * the places in them to fill, each its offset, its kind, its label or
 * number *)
type item = Label of string | Align of int | Space of int | Code of string * (int * string * string) list

let unhex s = String.init (String.length s / 2) (fun i -> Char.chr (int_of_string ("0x" ^ String.sub s (2 * i) 2)))

let read name text =
  if not (String.length text >= 11 && String.sub text 0 11 = "tiny-object") then error "%s: not an object of tiny-assembler's" name;
  let items = ref [] in
  List.iteri (fun n l ->
    match String.split_on_char ' ' l, !items with
    | [ "tiny-object" ], [] | [ "" ], _ -> ()
    | [ "label"; s ], _ -> items := Label s :: !items
    | [ "align"; k ], _ -> items := Align (int_of_string k) :: !items
    | [ "space"; k ], _ -> items := Space (int_of_string k) :: !items
    | [ "code"; h ], _ -> items := Code (unhex h, []) :: !items
    | [ "reloc"; off; k; t ], Code (s, rs) :: rest -> items := Code (s, (int_of_string off, k, t) :: rs) :: rest
    | _ -> error "%s:%d: not an object's line" name (n + 1)) (String.split_on_char '\n' text);
  List.rev !items

(*****************************************************************************)
(* The link *)
(*****************************************************************************)

(* the first pass: each item its address, each label its own *)
let layout (items : item list) =
  let labels = Hashtbl.create 64 in
  let pc = ref 0 and placed = ref [] in
  List.iter (fun it ->
    match it with
    | Label l -> if Hashtbl.mem labels l then error "label %s defined twice" l; Hashtbl.replace labels l !pc
    | Align n -> let a = (!pc + n - 1) / n * n in placed := (!pc, Space (a - !pc)) :: !placed; pc := a
    | Space n -> placed := (!pc, it) :: !placed; pc := !pc + n
    | Code (s, _) -> placed := (!pc, it) :: !placed; pc := !pc + String.length s) items;
  labels, List.rev !placed

(* a word with an address, or what an address makes, in its place: the
 * whole word, or the instruction made again with it as its immediate,
 * so that encode says what does not fit *)
let fill w kind pc v =
  let imm v = function
    | Alui (op, d, a, _) -> Alui (op, d, a, v) | Lui (d, _) -> Lui (d, v)
    | Load (s, d, a, _) -> Load (s, d, a, v) | Store (s, d, a, _) -> Store (s, d, a, v)
    | Branch (c, d, a, _) -> Branch (c, d, a, v) | Jal (d, _) -> Jal (d, v)
    | Jalr (d, a, _) -> Jalr (d, a, v) | Sys _ -> Sys v
    | Alu _ -> error "no immediate in 0x%x" w in
  let v = match kind with
    | "word" | "abs" -> v | "hi" -> m32 v lsr 16 | "lo" -> m32 v land 0xffff
    | "pc" -> if v land 3 <> 0 then error "unaligned target 0x%x" v; (v - (pc + 4)) / 4
    | k -> error "not a kind of place: %s" k in
  if kind = "word" then m32 v
  else match decode w with Some i -> encode (imm v i) | None -> error "not an instruction at 0x%x" pc

let link (objects : (string * string) list) =
  let labels, placed = layout (List.concat_map (fun (f, text) -> read f text) objects) in
  let resolve t =
    match int_of_string_opt t, Hashtbl.find_opt labels t with
    | Some n, _ | None, Some n -> n
    | None, None -> error "undefined label %s" t in
  let b = Buffer.create 4096 in
  List.iter (fun (a, it) ->
    match it with
    | Space n -> Buffer.add_string b (String.make n '\000')
    | Code (s, relocs) ->
        let s = Bytes.of_string s in
        List.iter (fun (off, k, t) ->
          let w = Int32.to_int (Bytes.get_int32_le s off) land 0xffffffff in
          let w = try fill w k (a + off) (resolve t) with Error e -> error "%s (%s)" e t in
          Bytes.set_int32_le s off (Int32.of_int w)) relocs;
        Buffer.add_bytes b s
    | Label _ | Align _ -> ()) placed;
  Buffer.contents b, List.sort (fun (_, a) (_, b) -> compare a b) (Hashtbl.fold (fun l a acc -> (l, a) :: acc) labels [])

(* An executable for tiny-kernel: a header of three words, then the
 * image, linked at 0. The words are a magic number, the image's size,
 * and how much memory the program asks for, in bytes; tiny-kernel gives
 * it a partition of that size. This plays the role of Unix's a.out
 * header, whose bss size said how much memory a program needed beyond
 * its file. (old: the header of tiny-os v6's executables, whose third
 * word was the address where the image was linked, 0x800000.) *)
let aout_magic = 0x7a0ce5

let aout ~memory image =
  let b = Buffer.create (String.length image + 12) in
  List.iter (fun v -> Buffer.add_int32_le b (Int32.of_int v)) [ aout_magic; String.length image; memory ];
  Buffer.add_string b image;
  Buffer.contents b

let main (caps : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. >) =
  let rec args mb map = function
    | "-a" :: n :: r when (match int_of_string_opt n with Some n -> n > 0 && n <= 100 | None -> false) -> args (Some (int_of_string n)) map r
    | "-map" :: r -> args mb true r
    | "-o" :: out :: (_ :: _ as files) -> Some (mb, map, out, files)
    | _ -> None in
  match List.tl (Array.to_list (CapSys.argv caps)) with
  | ("-h" | "--help") :: _ -> Console.print caps help; 0
  | l ->
      match args None false l with
      | None -> Console.eprint caps "usage: tiny-linker [-a megabytes] [-map] -o out file.o...   (-h: how)\n"; 2
      | Some (mb, map, out, files) ->
          try
            let image, labels = link (List.map (fun f -> f, FS.read caps (Fpath.v f)) files) in
            FS.write caps (Fpath.v out) (match mb with Some n -> aout ~memory:(n * 0x100000) image | None -> image);
            if map then FS.write caps (Fpath.v (out ^ ".map")) (String.concat "" (List.map (fun (l, a) -> Printf.sprintf "%x %s\n" a l) labels));
            0
          with Error e | Sys_error e -> Console.eprint caps ("tiny-linker: " ^ e ^ "\n"); 1

let () = Cap.main (fun caps -> CapStdlib.exit caps (main caps))
