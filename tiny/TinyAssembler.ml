(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *
 * See TinyAssembler.mli
 *)
module ISA = TinyMachineISA

let usage = "usage: tiny-assembler [-o file.o] file.tm"
(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|

tiny-machine's assembly (TinyMachineISA's instructions, li, la, call, ret...,
the machine's csrr, csrw, eret, csrrw, amoswap, wfi, and .word .byte .ascii
.asciz .space .align .text .data) to an object, file.o by default, for
tiny-linker. In tiny/tests/TinyCPU_tests/, for example:
  tiny-assembler hello.tm                  hello.o: its words, its labels, the
                                           places a label's address goes
  tiny-linker -o hello hello.o && tiny-cpu hello        Hello, world
An error names the file and the line: hello.tm:3: not a register: r16
|}

(*****************************************************************************)
(* The numbers *)
(*****************************************************************************)

(* A number is a 32-bit word, kept as its two halves of 16 bits: tiny-ml's
 * ints have 31, and a word of tiny-ml's code (a tagged max_int,
 * 2147483647) or of its strings' bytes needs the 32nd. (old: an int,
 * and m32 n.) Read as int_of_string does, in decimal or after 0x, its
 * bits past 32 dropped. *)
let halves s =
  let neg = String.length s > 0 && s.[0] = '-' in
  let s = if neg then String.sub s 1 (String.length s - 1) else s in
  let base, start =
    if String.length s > 2 && s.[0] = '0' && (s.[1] = 'x' || s.[1] = 'X')
    then 16, 2 else 10, 0 in
  let digit c =
    let k = Char.code c in
    if c >= '0' && c <= '9' then k - 48
    else if c >= 'a' && c <= 'f' then k - 87
    else if c >= 'A' && c <= 'F' then k - 55
    else 99 in
  let rec go i h l =
    if i = String.length s then Some (h, l)
    else
      let d = digit s.[i] in
      if d >= base then None
      else
        let l = (l * base) + d in
        go (i + 1) (((h * base) + (l lsr 16)) land 0xffff) (l land 0xffff) in
  if String.length s <= start then None
  else match go start 0 0 with
    | Some (h, l) when neg ->
        let l = ((l lxor 0xffff) + 1) in
        Some (((h lxor 0xffff) + (l lsr 16)) land 0xffff, l land 0xffff)
    | r -> r

(* a word as an int, when it fits in 31 bits (so on both sides) *)
let int_of (h, l) =
  if h < 0x4000 || h >= 0xc000 then (ISA.sext16 h * 0x10000) + l
  else ISA.error "number out of range"

(* -1 is two words of ffff; a small number one *)
let small (h, l) = (h = 0 && l < 0x8000) || (h = 0xffff && l >= 0x8000)

type expr = Num of (int * int) | Sym of string

(*****************************************************************************)
(* The items *)
(*****************************************************************************)

(* where a label's address goes in a word, the linker's to fill: the
 * whole word (.word), the immediate (addi's, a load's offset...), its
 * high or low half (la: lui then ori), or a branch's offset in words *)
type kind = Word | Abs | Hi | Lo | Pc

let kinds = [ Word, "word"; Abs, "abs"; Hi, "hi"; Lo, "lo"; Pc, "pc" ]

(* an item: an instruction's words, made from what the operands resolve
 * to, given the word's index in the item and the place's kind; .word's
 * words; or bytes, zeros, a label, an alignment, which the linker does
 * (an address's, not the file's) *)
type item =
  | Label of string
  | Words of int * ((int -> kind -> expr -> int) -> int list)
  | Data of expr list | Bytes_ of string | Space of int | Align of int | Piece
  | Section of string

let reg s =
  match String.trim s with
  | "zero" -> 0 | "sp" -> ISA.sp | "lr" -> ISA.lr
  | s when String.length s >= 2 && s.[0] = 'r' ->
      (match int_of_string_opt (String.sub s 1 (String.length s - 1)) with
       | Some n when n >= 0 && n < 16 -> n
       | _ -> ISA.error ("not a register: " ^ s))
  | s -> ISA.error ("not a register: " ^ s)

let expr s =
  let s = String.trim s in
  if String.length s = 3 && s.[0] = '\'' && s.[2] = '\'' then
    Num (0, Char.code s.[1])
  else match halves s with Some n -> Num n | None -> Sym s

(* "off(ra)" or "(ra)" *)
let mem_operand s =
  let s = String.trim s in
  match String.index_opt s '(' with
  | Some i when s.[String.length s - 1] = ')' ->
      let off = String.trim (String.sub s 0 i) in
      reg (String.sub s (i + 1) (String.length s - i - 2)),
      (if off = "" then Num (0, 0) else expr off)
  | _ -> ISA.error ("not a memory operand: " ^ s)

let one f = Words (4, fun res -> [ ISA.encode (f (res 0)) ])

(* the machine's own instructions (TinyMachineDevices runs them): a
 * register of control by its name *)
let machine name args =
  let csr s =
    match List.assoc_opt (String.trim s)
            (List.mapi (fun k n -> n, k) (Array.to_list ISA.csr_names)) with
    | Some k -> k | None -> ISA.error ("not a register of control: " ^ s) in
  let w op d a k =
    Words (4, fun _ -> [ (op lsl 24) lor (d lsl 20) lor (a lsl 16) lor k ]) in

  match name, args with
  | "csrr", [ d; c ] -> w 0x3a (reg d) 0 (csr c)
  | "csrw", [ c; a ] -> w 0x3b 0 (reg a) (csr c)
  | "eret", [] -> w 0x3c 0 0 0
  | "wfi", [] -> w 0x37 0 0 0
  | "csrrw", [ d; c; a ] -> w 0x3e (reg d) (reg a) (csr c)
  | "amoswap", [ d; a; b ] ->
      let b = String.trim b in
      if String.length b < 2 || b.[0] <> '(' || b.[String.length b - 1] <> ')'
      then ISA.error "amoswap's address: (rN)";
      w 0x3d (reg d) (reg a) (reg (String.sub b 1 (String.length b - 2)))
  | _ -> ISA.error ("bad instruction: " ^ name ^ " " ^ String.concat ", " args)

(* the instructions named by a table: the ALU's, their immediate forms,
 * the branches (old: each name looked for in the three arrays at each
 * line, and imm_name's string made for each operation) *)
type named = Op of ISA.alu | Imm of ISA.alu | Test of ISA.cmp
let named = Hashtbl.create 64
let () =
  Array.iter (fun op ->
    Hashtbl.replace named ISA.alu_names.(ISA.index ISA.alus op) (Op op);
    if ISA.has_imm op then Hashtbl.replace named (ISA.imm_name op) (Imm op))
    ISA.alus;
  Array.iter (fun c ->
    Hashtbl.replace named ISA.cmp_names.(ISA.index ISA.cmps c) (Test c))
    ISA.cmps

let rec instruction name args : item =
  let args =
    List.map String.trim
      (if String.trim args = "" then [] else String.split_on_char ',' args) in
  match Hashtbl.find_opt named name, args with
  | Some (Op op), [ d; a; b ] ->
      one (fun _ -> ISA.Alu (op, reg d, reg a, reg b))
  | Some (Imm op), [ d; a; v ] ->
      one (fun res -> ISA.Alui (op, reg d, reg a, res Abs (expr v)))
  | Some (Test c), [ d; a; t ] ->
      one (fun res -> ISA.Branch (c, reg d, reg a, res Pc (expr t)))
  | _ -> others name args

(* the others, by their names *)
and others name args =
  match name, args with
  | "lui", [ d; v ] ->
      one (fun res -> ISA.Lui (reg d, res Abs (expr v) land 0xffff))
  | ("ldw" | "ldb" | "stw" | "stb"), [ d; m ] ->
      one (fun res ->
        let a, off = mem_operand m in
        let s = if name.[2] = 'w' then ISA.W else ISA.B in
        if name.[0] = 'l' then ISA.Load (s, reg d, a, res Abs off)
        else ISA.Store (s, reg d, a, res Abs off))
  | "jal", [ d; t ] -> one (fun res -> ISA.Jal (reg d, res Pc (expr t)))
  | "jalr", [ d; m ] ->
      one (fun res ->
        let a, off = mem_operand m in ISA.Jalr (reg d, a, res Abs off))
  | "sys", [ n ] -> one (fun res -> ISA.Sys (res Abs (expr n)))
  (* the pseudo-instructions *)
  | "li", [ d; v ] when (match expr v with Num n -> small n | Sym _ -> false) ->
      one (fun res -> ISA.Alui (ISA.Add, reg d, 0, res Abs (expr v)))
  | ("li" | "la"), [ d; v ] ->
      Words (8, fun res ->
        [ ISA.encode (ISA.Lui (reg d, res 0 Hi (expr v)));
          ISA.encode (ISA.Alui (ISA.Or, reg d, reg d, res 1 Lo (expr v))) ])
  | "mov", [ d; a ] -> one (fun _ -> ISA.Alui (ISA.Add, reg d, reg a, 0))
  | "call", [ t ] -> one (fun res -> ISA.Jal (ISA.lr, res Pc (expr t)))
  | "j", [ t ] -> one (fun res -> ISA.Jal (0, res Pc (expr t)))
  | "ret", [] -> one (fun _ -> ISA.Jalr (0, ISA.lr, 0))
  | "nop", [] -> one (fun _ -> ISA.Alui (ISA.Add, 0, 0, 0))
  | _ -> machine name args

(* a string's escapes: backslash and n, t or 0, or the character *)
let unescape s =
  let b = Buffer.create (String.length s) in
  let rec go i =
    if i < String.length s then
      if s.[i] = '\\' && i + 1 < String.length s then
        (Buffer.add_char b
           (match s.[i + 1] with
            | 'n' -> '\n' | 't' -> '\t' | '0' -> '\000' | c -> c);
         go (i + 2))
      else (Buffer.add_char b s.[i]; go (i + 1)) in
  go 0; Buffer.contents b

let directive d args : item =
  match d with
  | ".word" -> Data (List.map expr (String.split_on_char ',' args))
  | ".byte" ->
      Bytes_ (String.concat "" (List.map (fun e ->
        match expr e with
        | Num (_, l) -> String.make 1 (Char.chr (l land 0xff))
        | Sym _ -> ISA.error ".byte takes numbers")
        (String.split_on_char ',' args)))
  | ".ascii" | ".asciz" ->
      let a = String.trim args in
      if String.length a < 2 || a.[0] <> '"' || a.[String.length a - 1] <> '"'
      then ISA.error ("not a string: " ^ a);
      Bytes_ (unescape (String.sub a 1 (String.length a - 2))
              ^ if d = ".asciz" then "\000" else "")
  | ".space" -> Space (int_of_string (String.trim args))
  | ".align" -> Align (int_of_string (String.trim args))
  | ".piece" -> Piece
  | ".text" -> Section "text"
  | ".data" -> Section "data"
  | _ -> ISA.error ("unknown directive " ^ d)

(* a line: labels, then an instruction or a directive; ; starts a comment *)
let parse_line line : item list =
  let line = match String.index_opt line ';' with
    | Some i when not (String.contains (String.sub line 0 i) '"') ->
        String.sub line 0 i
    | _ -> line in
  let rec go s acc =
    let s = String.trim s in
    match String.index_opt s ':' with
    | Some i when not (String.contains (String.sub s 0 i) ' ')
                  && not (String.contains (String.sub s 0 i) '"') ->
        go (String.sub s (i + 1) (String.length s - i - 1))
          (Label (String.sub s 0 i) :: acc)
    | _ when s = "" -> List.rev acc
    | _ ->
        let first c =
          match String.index_opt s c with
          | Some i -> i
          | None -> String.length s in
        let i = min (first ' ') (first '\t') in
        let name = String.sub s 0 i
        and rest = String.sub s i (String.length s - i) in
        List.rev acc
        @ [ (if name.[0] = '.' then directive name rest
             else instruction name rest) ] in
  go line []

(*****************************************************************************)
(* The object *)
(*****************************************************************************)

(* a byte, a word's bytes (the low first: the memory's order), in
 * hexadecimal, added to the object (old: Printf's %02x, then strings
 * joined by ^, a new string at each) *)
let add_hex b n =
  Buffer.add_char b "0123456789abcdef".[n lsr 4];
  Buffer.add_char b "0123456789abcdef".[n land 15]
let add_word b (h, l) =
  add_hex b (l land 0xff); add_hex b (l lsr 8);
  add_hex b (h land 0xff); add_hex b (h lsr 8)

(* a word in decimal, signed (a branch's number as a reloc's target) *)
let decimal (h, l) =
  let rec digits h l acc =
    if h = 0 && l = 0 then acc
    else
      let r = ((h mod 10) * 0x10000) + l in
      digits (h / 10) (r / 10) (string_of_int (r mod 10) ^ acc) in
  if (h, l) = (0, 0) then "0"
  else if h < 0x8000 then digits h l ""
  else
    let l' = (l lxor 0xffff) + 1 in
    "-" ^ digits (((h lxor 0xffff) + (l' lsr 16)) land 0xffff) (l' land 0xffff)
            ""

(* A file's items as lines, in their order, for tiny-linker
 * (TinyLinker.mli has the format): a word whose operand is a number is
 * made here, one whose operand is a label is made with 0 there and a
 * reloc line says what goes in it; a branch to a number too, its
 * offset being from an address the link chooses *)
let assemble (chan : Chan.i) =
  let b = Buffer.create 4096 in

  let line s = Buffer.add_string b (s ^ "\n") in
  let at n e = Chan.origin chan ^ ":" ^ string_of_int (n + 1) ^ ": " ^ e in
  let target e = match e with Num n -> decimal n | Sym s -> s in
  let relocs_of rs =
    (* (by offset: a list's words are made from the last) *)
    List.iter (fun (off, k, e) ->
        line ("reloc " ^ string_of_int off ^ " " ^ List.assoc k kinds ^ " "
              ^ target e))
      (List.sort (fun (a, _, _) (b, _, _) -> compare a b) rs) in

  line "tiny-object";
  (* each file on a word's boundary: one may end with bytes, the next
   * begin with code *)
  line "align 4";
  In_channel.input_all chan.ic 
  |> String.split_on_char '\n'
  |> List.iteri (fun n l ->
    let items = try parse_line l with ISA.Error e -> ISA.error (at n e) in
    items |> List.iter (fun it ->
      match it with
      | Label l -> line ("label " ^ l)
      | Align k -> line (Printf.sprintf "align %d" k)
      | Piece -> line "piece"
      | Section k -> line k
      | Space k -> line (Printf.sprintf "space %d" k)
      | Bytes_ s ->
          Buffer.add_string b "code ";
          String.iter (fun c -> add_hex b (Char.code c)) s;
          Buffer.add_char b '\n'
      | Data es ->
          Buffer.add_string b "code ";
          List.iter (fun e ->
            add_word b (match e with Num n -> n | Sym _ -> (0, 0))) es;
          Buffer.add_char b '\n';
          relocs_of (List.concat (List.mapi (fun i e ->
            match e with Sym _ -> [ (4 * i, Word, e) ] | Num _ -> []) es))
      | Words (_, f) ->
          let relocs = ref [] in
          let res i k e =
            match k, e with
            | Pc, _ | _, Sym _ -> relocs := (4 * i, k, e) :: !relocs; 0
            | Hi, Num (h, _) -> h
            | Lo, Num (_, l) -> l
            | _, Num n -> int_of n in
          let ws = try f res with ISA.Error e -> ISA.error (at n e) in
          Buffer.add_string b "code ";
          List.iter (fun w -> add_word b (w lsr 16, w land 0xffff)) ws;
          Buffer.add_char b '\n';
          relocs_of !relocs
       )
     )
  ;
  Buffer.contents b

let main (caps : < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. >)
    (argv : string array) : Exit.t =
  let assemble_to (f : Fpath.t) (out : Fpath.t) : Exit.t =
    f |> TinyLibSystem.with_open_in caps assemble
      |> TinyLibSystem.write_file caps out
    ;
    Exit.OK in
  (* x.tm's object: x.o, here *)
  let default f = Fpath.set_ext ".o" (Fpath.base f) in
  let tm f = Filename.check_suffix f ".tm" in
  try
    match List.tl (Array.to_list argv) with
    | ("-h" | "--help") :: _ -> TinyLibSystem.print caps help; Exit.OK
    | [ "-o"; out; f ] when tm f -> assemble_to (Fpath.v f) (Fpath.v out)
    | [ f ] when tm f -> assemble_to (Fpath.v f) (default (Fpath.v f))
    | _ -> TinyLibSystem.eprint caps (usage ^ "   (-h: how)\n"); Exit.Code 2
  (* (said after the program's name by TinyLibSystem.main) *)
  with ISA.Error e -> Exit.Err e

let () = TinyLibSystem.main "tiny-assembler" main
