(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyLinker.mli *)

open TinyMachineISA

let usage = "usage: tiny-linker [-a megabytes] [-map] -o out file.o..."

(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|

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
type item = Label of string | Align of int | Space of int | Code of string * (int * string * string) list | Piece

let unhex s =
  let digit c = let k = Char.code c in if c <= '9' then k - 48 else k - 87 in
  String.init (String.length s / 2) (fun i -> Char.chr ((16 * digit s.[2 * i]) + digit s.[(2 * i) + 1]))

let read name text =
  if not (String.length text >= 11 && String.sub text 0 11 = "tiny-object") then error (name ^ ": not an object of tiny-assembler's");
  let items = ref [] in
  List.iteri (fun n l ->
    match String.split_on_char ' ' l, !items with
    | [ "tiny-object" ], [] | [ "" ], _ -> ()
    | [ "label"; s ], _ -> items := Label s :: !items
    | [ "align"; k ], _ -> items := Align (int_of_string k) :: !items
    | [ "space"; k ], _ -> items := Space (int_of_string k) :: !items
    | [ "piece" ], _ -> items := Piece :: !items
    | [ "code"; h ], _ -> items := Code (unhex h, []) :: !items
    | [ "reloc"; off; k; t ], Code (s, rs) :: rest -> items := Code (s, (int_of_string off, k, t) :: rs) :: rest
    | _ -> error (name ^ ":" ^ string_of_int (n + 1) ^ ": not an object's line")) (String.split_on_char '\n' text);
  List.rev !items

(*****************************************************************************)
(* The link *)
(*****************************************************************************)

(* the first pass: each item its address, each label its own (and the
 * labels in their order, which is their addresses') *)
let layout (items : item list) =
  let labels = Hashtbl.create 64 and order = ref [] in
  let pc = ref 0 and placed = ref [] in
  List.iter (fun it ->
    match it with
    | Label l -> if Hashtbl.mem labels l then error ("label " ^ l ^ " defined twice"); Hashtbl.replace labels l !pc; order := (l, !pc) :: !order
    | Align n -> let a = (!pc + n - 1) / n * n in placed := (!pc, Space (a - !pc)) :: !placed; pc := a
    | Space n -> placed := (!pc, it) :: !placed; pc := !pc + n
    | Code (s, _) -> placed := (!pc, it) :: !placed; pc := !pc + String.length s
    | Piece -> ()) items;
  labels, List.rev !order, List.rev !placed

(* a word in the code's bytes, the low first; an instruction's, which
 * fits in an int on both sides (its opcode under 0x40) *)
let get_word s off = List.fold_right (fun i w -> (w lsl 8) lor Char.code (Bytes.get s (off + i))) [ 0; 1; 2; 3 ] 0
(* a value's 32 bits, from an int that has 31 (tiny-ml's) or 63:
 * an address, or a word made by encode (old: Bytes.set_int32_le) *)
let set_word s off v = List.iter (fun i -> Bytes.set s (off + i) (Char.chr ((v asr (8 * i)) land 0xff))) [ 0; 1; 2; 3 ]

(* a word with an address, or what an address makes, in its place: the
 * whole word, or the instruction made again with it as its immediate,
 * so that encode says what does not fit *)
let fill s off kind pc v =
  let imm v i = match i with
    | Alui (op, d, a, _) -> Alui (op, d, a, v) | Lui (d, _) -> Lui (d, v)
    | Load (s, d, a, _) -> Load (s, d, a, v) | Store (s, d, a, _) -> Store (s, d, a, v)
    | Branch (c, d, a, _) -> Branch (c, d, a, v) | Jal (d, _) -> Jal (d, v)
    | Jalr (d, a, _) -> Jalr (d, a, v) | Sys _ -> Sys v
    | Alu _ -> error ("no immediate in " ^ hex (get_word s off)) in
  let v = match kind with
    | "word" | "abs" -> v | "hi" -> (v asr 16) land 0xffff | "lo" -> v land 0xffff
    | "pc" -> if v land 3 <> 0 then error ("unaligned target " ^ hex v); (v - (pc + 4)) / 4
    | k -> error ("not a kind of place: " ^ k) in
  if kind = "word" then set_word s off v
  else match decode (get_word s off) with
    | Some i -> set_word s off (encode (imm v i))
    | None -> error ("not an instruction at " ^ hex pc)

(* What nothing reaches, left out. A piece is what follows a piece line
 * (tiny-ml's: a function, a static block) up to the next one, or the
 * object's end; an object without one is one piece, and is kept, as is
 * what comes before an object's first piece line. A piece is kept when
 * a kept one names one of its labels, so what is kept is what the
 * objects without pieces reach (the start, the C runtime, which calls
 * ml_start). Each piece kept starts on a word. *)
let sweep (objects : item list list) =
  let pieces = List.concat_map (fun items ->
    let rec split cur acc l = match l with
      | [] -> List.rev (List.rev cur :: acc)
      | Piece :: l -> split [ Align 4 ] (List.rev cur :: acc) l
      | it :: l -> split (it :: cur) acc l in
    match split [] [] items with
    | first :: rest -> (true, first) :: List.map (fun p -> false, p) rest
    | [] -> []) objects in
  let pieces = Array.of_list pieces in
  let where = Hashtbl.create 256 in
  for i = 0 to Array.length pieces - 1 do
    List.iter (fun it -> match it with Label l -> if Hashtbl.mem where l then error ("label " ^ l ^ " defined twice"); Hashtbl.replace where l i | _ -> ()) (snd pieces.(i))
  done;
  let kept = Array.map fst pieces in
  let rec keep i =
    List.iter (fun it -> match it with
      | Code (_, relocs) ->
          List.iter (fun (_, _, t) -> match Hashtbl.find_opt where t with Some j when not kept.(j) -> kept.(j) <- true; keep j | _ -> ()) relocs
      | _ -> ()) (snd pieces.(i)) in
  (* (the roots, as they were before keep marks more) *)
  let roots = Array.copy kept in
  for i = 0 to Array.length roots - 1 do if roots.(i) then keep i done;
  List.concat (List.filteri (fun i _ -> kept.(i)) (List.map snd (Array.to_list pieces)))

let link (objects : (string * string) list) =
  let labels, order, placed = layout (sweep (List.map (fun (f, text) -> read f text) objects)) in
  let resolve t =
    match int_of_string_opt t, Hashtbl.find_opt labels t with
    | Some n, _ -> n
    | None, Some n -> n
    | None, None -> error ("undefined label " ^ t) in
  let b = Buffer.create 4096 in
  List.iter (fun (a, it) ->
    match it with
    | Space n -> Buffer.add_string b (String.make n '\000')
    | Code (s, relocs) ->
        let s = Bytes.of_string s in
        List.iter (fun (off, k, t) -> try fill s off k (a + off) (resolve t) with Error e -> error (e ^ " (" ^ t ^ ")")) relocs;
        Buffer.add_string b (Bytes.to_string s)
    | Label _ | Align _ | Piece -> ()) placed;
  (* (old: the table's labels sorted by address, those at one address in
   * the table's order, which is OCaml's or TinyLibCore's) *)
  Buffer.contents b, order

(* An executable for tiny-kernel: a header of three words, then the
 * image, linked at 0. The words are a magic number, the image's size,
 * and how much memory the program asks for, in bytes; tiny-kernel gives
 * it a partition of that size. This plays the role of Unix's a.out
 * header, whose bss size said how much memory a program needed beyond
 * its file. (old: the header of tiny-os v6's executables, whose third
 * word was the address where the image was linked, 0x800000.) *)
let aout_magic = 0x7a0ce5

let aout memory image =
  let h = Bytes.make 12 '\000' in
  List.iteri (fun i v -> set_word h (4 * i) v) [ aout_magic; String.length image; memory ];
  Bytes.to_string h ^ image

let main (caps : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. >) =
  let write f text = let fd = TinyLibSystem.open_out caps f in TinyLibSystem.write fd text; TinyLibSystem.close fd in
  let megabytes n = match int_of_string_opt n with Some n -> n > 0 && n <= 100 | None -> false in
  let rec args mb map l = match l with
    | "-a" :: n :: r when megabytes n -> args (Some (int_of_string n)) map r
    | "-map" :: r -> args mb true r
    | "-o" :: out :: files when files <> [] -> Some (mb, map, out, files)
    | _ -> None in
  match List.tl (TinyLibSystem.argv caps) with
  | ("-h" | "--help") :: _ -> TinyLibSystem.print caps help; 0
  | l ->
      match args None false l with
      | None -> TinyLibSystem.eprint caps (usage ^ "   (-h: how)\n"); 2
      | Some (mb, map, out, files) ->
          try
            let image, labels = link (List.map (fun f -> f, TinyLibSystem.read_file caps f) files) in
            write out (match mb with Some n -> aout (n * 0x100000) image | None -> image);
            (* (old: Printf's %x) *)
            if map then write (out ^ ".map") (String.concat "" (List.map (fun (l, a) -> let h = hex a in String.sub h 2 (String.length h - 2) ^ " " ^ l ^ "\n") labels));
            0
          with Error e -> TinyLibSystem.eprint caps ("tiny-linker: " ^ e ^ "\n"); 1

let () = TinyLibSystem.main "tiny-linker" main
