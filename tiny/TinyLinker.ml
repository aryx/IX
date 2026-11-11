(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *
 * See TinyLinker.mli
 *)
(* (|||: an option's value, or a default) *)
open Common
module M = TinyLibMachine
module TSys = TinyLibSystem

(* what tiny-linker asks for: the objects read, the image written *)
type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

(* an address in the image, from 0 *)
type address = int

let usage =
  "usage: tiny-linker [-a megabytes] [-n] [-s] [-map] [-debug] -o out file.o|lib.a..."
(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|

tiny-assembler's objects to an image for tiny-cpu or tiny-machine: the files one
after the other from address 0, their labels one name space, each place a
label's address goes filled. With -a, an executable for tiny-kernel that asks
for that much memory: a header (a magic number, the image's size, the memory),
then the image. With -n, the text first, the data from the next 4 KB, and the
text's size in a fourth word (another magic number): tiny-kernel's segments
share the text between the runs of a program. With -s, an executable too (of 1 MB unless -a says), with its
labels after the image, but the compilers' local ones (what debug reads). With
-map, out.map too: each label's address, by address (what tiny-prof reads).
With -debug, each object's items said (-v, -quiet: TSys.logging's).
A library, tiny-ar's archive (lib.a), is its objects, all linked, in its order.
A label's line is its address in hexadecimal and its name. In
tiny/tests/TinyCPU_tests/, for example:
  tiny-assembler hello.tm && tiny-linker -o hello hello.o
  tiny-cpu hello                           Hello, world
  tiny-linker -a 10 -o prog start.o prog.o  an a.out of 10 MB, for tiny-kernel
An error names the label: undefined label main
|}

(*****************************************************************************)
(* The link *)
(*****************************************************************************)

(* the first pass: each item its address, each label its own (and the
 * labels in their order, which is their addresses'), and where the data
 * starts (-n; 0 otherwise) *)
type layout = {
  labels : (M.label, address) Hashtbl.t;
  order : (M.label * address) list;
  placed : (address * M.line) list;
  data_at : address;
}

let layout (items : M.line list) : layout =
  let labels = Hashtbl.create 64 and order = ref [] in
  let pc = ref 0 and placed = ref [] and data_at = ref 0 in
  items |> List.iter (fun (it : M.line) ->
    match it with
    | Label l ->
        if Hashtbl.mem labels l then
          M.error (Printf.sprintf "label %s defined twice" l);
        Hashtbl.replace labels l !pc;
        order := (l, !pc) :: !order
    | Align n ->
        let a = (!pc + n - 1) / n * n in
        placed := (!pc, M.Space (a - !pc)) :: !placed;
        pc := a
    | Space n -> placed := (!pc, it) :: !placed; pc := !pc + n
    | Chunk (s, _) ->
        placed := (!pc, it) :: !placed; pc := !pc + String.length s
    | SectionData -> data_at := !pc
    | Piece | SectionCode -> ()
    (* (one type for lines and objects: an instruction or a datum not
     * encoded is not an object's, which tiny-assembler's are) *)
    | _ -> M.error ("not an object's line: " ^ String.trim (M.print_line it)));
  { labels; order = List.rev !order; placed = List.rev !placed;
    data_at = !data_at }

(* a word in the code's bytes, the low first; an instruction's, which
 * fits in an int on both sides (its opcode under 0x40) *)
let get_word s off : M.instr_word =
  List.fold_right (fun i w -> (w lsl 8) lor Char.code (Bytes.get s (off + i)))
    [ 0; 1; 2; 3 ] 0
(* a word put at off, its bytes libmach's: an address, an instruction's
 * word, a header's number, each 32 bits *)
let set_word s off (w : M.word) = Bytes.blit_string (M.word_bytes w) 0 s off 4

(* a word with an address, or what an address makes, in its place: the
 * whole word, or the instruction made again with it as its immediate,
 * so that encode says what does not fit *)
let fill s off (kind : M.place) (pc : address) (v : address) =
  let imm v (i : M.instr) : M.instr = match i with
    | Alui (op, d, a, _) -> Alui (op, d, a, v) | Lui (d, _) -> Lui (d, v)
    | Load (s, d, a, _) -> Load (s, d, a, v)
    | Store (s, d, a, _) -> Store (s, d, a, v)
    | Branch (c, d, a, _) -> Branch (c, d, a, v) | Jal (d, _) -> Jal (d, v)
    | Jalr (d, a, _) -> Jalr (d, a, v) | Sys _ -> Sys v
    | Alu _ -> M.error ("no immediate in " ^ M.hex (get_word s off)) in
  let v = match kind with
    | Full | Abs -> v | Hi -> (v asr 16) land 0xffff
    | Lo -> v land 0xffff
    | Pc ->
        if v land 3 <> 0 then M.error ("unaligned target " ^ M.hex v);
        (v - (pc + 4)) / 4 in
  if kind = M.Full then set_word s off (Int32.of_int v)
  else match M.decode (get_word s off) with
    | Some i -> set_word s off (Int32.of_int (M.encode (imm v i)))
    | None -> M.error ("not an instruction at " ^ M.hex pc)

(* What nothing reaches, left out. A piece is what follows a piece line
 * (tiny-ml's: a function, a static block) up to the next one, or the
 * object's end; an object without one is one piece, and is kept, as is
 * what comes before an object's first piece line. A piece is kept when
 * a kept one names one of its labels, so what is kept is what the
 * objects without pieces reach (the start, the C runtime, which calls
 * ml_start). Each piece kept starts on a word. *)
let sweep (objects : M.line list list) =
  let pieces = List.concat_map (fun items ->
    let rec split cur acc (l : M.line list) = match l with
      | [] -> List.rev (List.rev cur :: acc)
      | Piece :: l -> split [ M.Align 4 ] (List.rev cur :: acc) l
      | it :: l -> split (it :: cur) acc l in
    match split [] [] items with
    | first :: rest -> (true, first) :: List.map (fun p -> false, p) rest
    | [] -> []) objects in
  let pieces = Array.of_list pieces in
  let where = Hashtbl.create 256 in
  for i = 0 to Array.length pieces - 1 do
    List.iter (fun (it : M.line) ->
      match it with
      | Label l ->
          if Hashtbl.mem where l then
            M.error (Printf.sprintf "label %s defined twice" l);
          Hashtbl.replace where l i
      | _ -> ()) (snd pieces.(i))
  done;
  let kept = Array.map fst pieces in
  let rec keep i =
    snd pieces.(i) |> List.iter (fun (it : M.line) -> match it with
      | Chunk (_, relocs) ->
          List.iter (fun ((_, _, t) : int * M.place * M.target) ->
            match (match t with Name l -> Hashtbl.find_opt where l
                              | Address _ -> None) with
            | Some j when not kept.(j) -> kept.(j) <- true; keep j
            | _ -> ()) relocs
      | _ -> ()) in
  (* (the roots, as they were before keep marks more) *)
  let roots = Array.copy kept in
  for i = 0 to Array.length roots - 1 do if roots.(i) then keep i done;
  Array.to_list pieces
  |> List.map snd
  |> List.filteri (fun i _ -> kept.(i))
  |> List.concat

(* Each piece its section: an object starts in the text, and a piece
 * goes on in the section its object was in (sweep keeps or drops it
 * whole, with its section) *)
let sectioned (items : M.line list) : M.line list =
  let section in_data : M.line =
    if in_data then SectionData else SectionCode in
  (* (tail-recursive: an image's items are many, the kernel's tens of
   * thousands, and tiny-kernel's stack is small: old, it :: go l,
   * a frame an item, ld's stack overflowed on it) *)
  let rec go in_data (l : M.line list) (acc : M.line list) =
    match l with
    | [] -> List.rev acc
    | Piece :: l -> go in_data l (section in_data :: Piece :: acc)
    | SectionCode :: l -> go false l (SectionCode :: acc)
    | SectionData :: l -> go true l (SectionData :: acc)
    | it :: l -> go in_data l (it :: acc) in
  go false items [ SectionCode ]

(* -n: the text first, then the data from the next 4 KB (a page: the
 * kernel's segments, plan_tiny_memory.md), Unix's 0410 (whose ld -n
 * rounded the data to the PDP-11's 8 KB). One SectionData is left
 * between them, where layout notes the data's start *)
let gather (items : M.line list) : M.line list =
  let text = ref [] and data = ref [] and in_data = ref false in
  let add it = if !in_data then data := it :: !data else text := it :: !text in
  List.iter (fun (it : M.line) ->
    match it with
    | SectionCode -> in_data := false; add (M.Align 4)
    | SectionData -> in_data := true; add (M.Align 4)
    | it -> add it) items;
  List.rev !text @ [ M.Align 4096; M.SectionData ] @ List.rev !data

(* the image's order: the objects', or the text first (-n) *)
type sections = In_order | Text_first

(* a link's result: the image; the labels, each with its address, by
 * address; where the data starts, with the text first (-n; None in
 * the objects' order, the sections then ignored) *)
type linked = {
  image : string;
  addresses : (M.label * address) list;
  data_start : address option;
}

(* (old: a triple, the data's start 0 when not split) *)
let link (sections : sections) (objects : M.line list list) : linked =
  let items = sweep (List.map sectioned objects) in
  let lay =
    layout
      (match sections with Text_first -> gather items | In_order -> items) in
  let resolve (t : M.target) : address =
    match t with
    | Address n -> n
    | Name l ->
        (match Hashtbl.find_opt lay.labels l with
         | Some n -> n | None -> M.error ("undefined label " ^ l)) in
  let b = Buffer.create 4096 in
  (* a target as an error says it *)
  let said (t : M.target) =
    match t with Name l -> l | Address n -> M.hex n in
  lay.placed |> List.iter (fun ((a, it) : address * M.line) ->
    match it with
    | Space n -> Buffer.add_string b (String.make n '\000')
    | Chunk (s, relocs) ->
        let s = Bytes.of_string s in
        List.iter (fun (off, k, t) ->
          try fill s off k (a + off) (resolve t)
          with M.Error e ->
            M.error (e ^ " (" ^ said t ^ ")")) relocs;
        Buffer.add_string b (Bytes.to_string s)
    | _ -> ());
  (* (old: the table's labels sorted by address, those at one address in
   * the table's order, which is OCaml's or TinyLibCore's) *)
  { image = Buffer.contents b; addresses = lay.order;
    data_start =
      (match sections with Text_first -> Some lay.data_at | In_order -> None) }

(* An executable for tiny-kernel: a header of three words, then the
 * image, linked at 0. The words are a magic number, the image's size,
 * and how much memory the program asks for, in bytes; tiny-kernel gives
 * it a partition of that size. This plays the role of Unix's a.out
 * header, whose bss size said how much memory a program needed beyond
 * its file. (old: the header of tiny-os v6's executables, whose third
 * word was the address where the image was linked, 0x800000.) *)
let aout_magic = 0x7a0ce5
(* -n's: a fourth word, the text's size (the data's start). As Unix's
 * 0407 and 0410, the magic number says the layout *)
let aout_split = 0x7a0ce6

let aout (memory : int) (l : linked) : string =
  let words =
    match l.data_start with
    | Some d -> [ aout_split; String.length l.image; memory; d ]
    | None -> [ aout_magic; String.length l.image; memory ] in
  let h = Bytes.make (4 * List.length words) '\000' in
  List.iteri (fun i v -> set_word h (4 * i) (Int32.of_int v)) words;
  Bytes.to_string h ^ l.image

(*****************************************************************************)
(* main *)
(*****************************************************************************)

(* the command line's options: -a's megabytes, -n (Text_first), -s,
 * -map *)
(* what the output file is: the image alone; an a.out for tiny-kernel,
 * asking for that much memory in bytes (-a); or one with its labels
 * after the image, but the compilers' local ones (-s, 1 MB unless -a) *)
type output = Image | Aout of int | Aout_labels of int

(* the labels' lines, each its address in hexadecimal and its name *)
let label_lines (ls : (M.label * address) list) : string =
  String.concat ""
    (List.map (fun (l, a) -> Printf.sprintf "%x %s\n" a l) ls)

(* -map's: every label's line *)
let map (l : linked) : string = label_lines l.addresses

(* the output file's bytes *)
let contents (out : output) (l : linked) : string =
  match out with
  | Image -> l.image
  | Aout memory -> aout memory l
  | Aout_labels memory ->
      aout memory l
      ^ label_lines
          (List.filter (fun (x, _) -> not (M.local x)) l.addresses)

(* an object file's items (TinyLibMachine's of_object), each said with
 * -debug; an archive's objects, all of them, in its order, as if each
 * were given (a library: no member left out, the sweep below does it) *)
let read (chan : Chan.i) : M.line list list =
  let f = Chan.origin chan in
  let items name s =
    let items =
      try M.of_object s with M.Error e -> M.error (name ^ ": " ^ e) in
    List.iter (fun it ->
      Logs.debug (fun m -> m "%s: %s" name (M.show_line it))) items;
    items in
  let s = In_channel.input_all chan.ic in
  if M.is_archive s then
    let members =
      try M.of_archive s with M.Error e -> M.error (f ^ ": " ^ e) in
    List.map (fun (name, o) -> items (f ^ "(" ^ name ^ ")") o) members
  else [ items f s ]

type options = {
  megabytes : int option;
  sections : sections;
  symbols : bool;
  map : bool;
}

(* -a's and -s's output *)
let output (o : options) : output =
  match o.megabytes, o.symbols with
  | None, false -> Image
  | Some n, false -> Aout (n * 0x100000)
  | m, true -> Aout_labels ((m ||| 1) * 0x100000)

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let write = TSys.write_file caps in
  let megabytes n =
    match int_of_string_opt n with
    | Some n -> n > 0 && n <= 100
    | None -> false in
  let rec args o l = match l with
    | "-a" :: n :: r when megabytes n ->
        args { o with megabytes = Some (int_of_string n) } r
    | "-n" :: r -> args { o with sections = Text_first } r
    | "-s" :: r -> args { o with symbols = true } r
    | "-map" :: r -> args { o with map = true } r
    | "-o" :: out :: files when files <> [] ->
        Some (o, Fpath.v out, Fpath_.of_strings files)
    | _ -> None in
  let none =
    { megabytes = None; sections = In_order; symbols = false; map = false } in
  match List.tl (Array.to_list argv) with
  | ("-h" | "--help") :: _ -> TSys.print caps help; Exit.OK
  | l ->
      match args none (TSys.logging l) with
      | None ->
          TSys.eprint caps (usage ^ "   (-h: how)\n"); Exit.Code 2
      | Some (o, out, files) ->
          try
            (* the pipeline: the objects' paths, their channels, their
             * items, linked, the output's bytes *)
            let objects = List.concat_map (TSys.with_open_in caps read) files in
            let linked = link o.sections objects in
            write out (contents (output o) linked);
            if o.map then
              write (Fpath.v (Fpath.to_string out ^ ".map")) (map linked);
            Exit.OK
          with M.Error e -> Exit.Err e

let () = TSys.main "tiny-linker" main
