(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *
 * See TinyAssembler.mli
 *)
module M = TinyLibMachine
module TSys = TinyLibSystem

(* what tiny-as asks for: its file read, its object written *)
type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

let usage = "usage: tiny-as [-o file.o | -S] file.s"
(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|

tiny-machine's assembly (TinyLibMachine's instructions, li, la, call, ret...,
the machine's csrr, csrw, eret, csrrw, amoswap, wfi, and .word .byte .ascii
.asciz .space .align .text .data) to an object, file.o by default, for
tiny-ld. In tiny/tests/TinyCPU_tests/, for example:
  tiny-as hello.s                          hello.o: its words, its labels, the
                                           places a label's address goes
  tiny-ld -o hello hello.o && tiny-cpu hello            Hello, world
An error names the file and the line: hello.s:3: not a register: r16
  tiny-as -S hello.s                       the lines as parsed, printed again
                                           (the compilers' -S text): they assemble
                                           to the same object
|}


(*****************************************************************************)
(* Parsing *)
(*****************************************************************************)
(* (old: TinyMachineAsm.parse, in TinyMachine/: tiny-as is the
 * only program that reads assembly; the compilers make lines) *)

(* A number is a 32-bit word, kept as its two halves of 16 bits: tiny-ml's
 * ints have 31, and a word of tiny-ml's code (a tagged max_int,
 * 2147483647) or of its strings' bytes needs the 32nd. (old: an int,
 * and m32 n.) Read as int_of_string does, in decimal or after 0x, its
 * bits past 32 dropped. *)
type halves = int * int   (* the high half, the low *)

let halves s : halves option =
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

(* a number as an int, when it fits in 31 bits (so on both sides) *)
let int_of ((h, l) : halves) : int =
  if h < 0x4000 || h >= 0xc000 then (M.sext16 h * 0x10000) + l
  else M.error "number out of range"

(* as a word, its two halves put together (old: an int64, h * 0x10000
 * added to l) *)
let word_of ((h, l) : halves) : M.word =
  Int32.logor (Int32.shift_left (Int32.of_int h) 16) (Int32.of_int l)

(* an operand: a number (a character too, 'c'), or a label *)
type arg = Arg_num of halves | Arg_sym of M.sym

let arg (s : string) : arg =
  let s = String.trim s in
  if String.length s = 3 && s.[0] = '\'' && s.[2] = '\'' then
    Arg_num (0, Char.code s.[1])
  else match halves s with Some n -> Arg_num n | None -> Arg_sym s

let target_of (a : arg) : M.target =
  match a with Arg_num n -> M.Address (int_of n) | Arg_sym s -> M.Name s

let parse_reg (s : string) : M.reg =
  match String.trim s with
  | "zero" -> 0 | "sp" -> M.sp | "lr" -> M.lr
  | s when String.length s >= 2 && s.[0] = 'r' ->
      (match int_of_string_opt (String.sub s 1 (String.length s - 1)) with
       | Some n when n >= 0 && n < 16 -> n
       | _ -> M.error ("not a register: " ^ s))
  | s -> M.error ("not a register: " ^ s)

(* "off(ra)" or "(ra)" *)
let mem_operand (s : string) : M.reg * arg =
  let s = String.trim s in
  match String.index_opt s '(' with
  | Some i when s.[String.length s - 1] = ')' ->
      let off = String.trim (String.sub s 0 i) in
      parse_reg (String.sub s (i + 1) (String.length s - i - 2)),
      (if off = "" then Arg_num (0, 0) else arg off)
  | _ -> M.error ("not a memory operand: " ^ s)

(* an instruction whose immediate is a, absolute: the number in it, or
 * 0 and the label for the link *)
let with_imm (f : int -> M.instr) (a : arg) : M.line =
  match a with
  | Arg_num n -> M.Instr (f (int_of n))
  | Arg_sym s -> M.Instr_at (f 0, M.Abs, M.Name s)

(* a jump or a branch to a: 0, and the words to it for the link *)
let with_pc (f : int -> M.instr) (a : arg) : M.line =
  M.Instr_at (f 0, M.Pc, target_of a)

(* the machine's own instructions: a register of control by its name *)
let machine_instr (name : string) (args : string list) : M.line =
  let csr s =
    match List.assoc_opt (String.trim s)
            (List.mapi (fun k n -> n, k) (Array.to_list M.csr_names)) with
    | Some k -> k | None -> M.error ("not a register of control: " ^ s) in
  let r = parse_reg in
  match name, args with
  | "csrr", [ d; c ] -> M.Machine (M.Csrr (r d, csr c))
  | "csrw", [ c; a ] -> M.Machine (M.Csrw (csr c, r a))
  | "eret", [] -> M.Machine M.Eret
  | "wfi", [] -> M.Machine M.Wfi
  | "csrrw", [ d; c; a ] -> M.Machine (M.Csrrw (r d, csr c, r a))
  | "amoswap", [ d; a; b ] ->
      let b = String.trim b in
      if String.length b < 2 || b.[0] <> '(' || b.[String.length b - 1] <> ')'
      then M.error "amoswap's address: (rN)";
      M.Machine (M.Amoswap (r d, r a, r (String.sub b 1 (String.length b - 2))))
  | _ -> M.error ("bad instruction: " ^ name ^ " " ^ String.concat ", " args)

(* the instructions named by a table: the ALU's, their immediate forms,
 * the branches (old: each name looked for in the three arrays at each
 * line, and imm_name's string made for each operation) *)
type named = Op of M.alu | Imm of M.alu | Test of M.cmp
let named = Hashtbl.create 64
let () =
  Array.iter (fun op ->
    Hashtbl.replace named M.alu_names.(M.index M.alus op) (Op op);
    if M.has_imm op then Hashtbl.replace named (M.imm_name op) (Imm op))
    M.alus;
  Array.iter (fun c ->
    Hashtbl.replace named M.cmp_names.(M.index M.cmps c) (Test c))
    M.cmps

let instruction (name : string) (args : string list) : M.line =
  let r = parse_reg in
  match Hashtbl.find_opt named name, args with
  | Some (Op op), [ d; a; b ] -> M.Instr (M.Alu (op, r d, r a, r b))
  | Some (Imm op), [ d; a; v ] ->
      with_imm (fun k -> M.Alui (op, r d, r a, k)) (arg v)
  | Some (Test c), [ d; a; t ] ->
      (match arg t with
       | Arg_sym s -> M.Branch_to (c, r d, r a, s)
       | n -> with_pc (fun k -> M.Branch (c, r d, r a, k)) n)
  | _ ->
      match name, args with
      | "lui", [ d; v ] ->
          (match arg v with
           | Arg_num n -> M.Instr (M.Lui (r d, int_of n land 0xffff))
           | a -> with_imm (fun k -> M.Lui (r d, k)) a)
      | ("ldw" | "ldb" | "stw" | "stb"), [ d; m ] ->
          let a, off = mem_operand m in
          let s = if name.[2] = 'w' then M.W else M.B in
          with_imm (fun k ->
            if name.[0] = 'l' then M.Load (s, r d, a, k)
            else M.Store (s, r d, a, k)) off
      | "jal", [ d; t ] -> with_pc (fun k -> M.Jal (r d, k)) (arg t)
      | "jalr", [ d; m ] ->
          let a, off = mem_operand m in
          with_imm (fun k -> M.Jalr (r d, a, k)) off
      | "sys", [ n ] -> with_imm (fun k -> M.Sys k) (arg n)
      (* the pseudo-instructions (la of a number is li's) *)
      | ("li" | "la"), [ d; v ] ->
          (match arg v with
           | Arg_num n -> M.Li (r d, word_of n)
           | Arg_sym s -> M.La (r d, s))
      | "mov", [ d; a ] -> M.Mov (r d, r a)
      | "call", [ t ] ->
          (match arg t with
           | Arg_sym s -> M.Call s
           | n -> with_pc (fun k -> M.Jal (M.lr, k)) n)
      | "j", [ t ] ->
          (match arg t with
           | Arg_sym s -> M.Jump s
           | n -> with_pc (fun k -> M.Jal (0, k)) n)
      | "ret", [] -> Ret
      | "nop", [] -> M.Instr (M.Alui (M.Add, 0, 0, 0))
      | _ -> machine_instr name args

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

let directive (d : string) (args : string) : M.line list =
  match d with
  | ".word" ->
      List.map (fun a ->
        match arg a with
        | Arg_num n -> M.Word (word_of n)
        | Arg_sym s -> M.Word_sym s)
        (String.split_on_char ',' args)
  | ".byte" ->
      [ M.Bytes (List.map (fun a ->
          match arg a with
          | Arg_num (_, l) -> l land 0xff
          | Arg_sym _ -> M.error ".byte takes numbers")
          (String.split_on_char ',' args)) ]
  | ".ascii" | ".asciz" ->
      let a = String.trim args in
      if String.length a < 2 || a.[0] <> '"' || a.[String.length a - 1] <> '"'
      then M.error ("not a string: " ^ a);
      [ M.Ascii (unescape (String.sub a 1 (String.length a - 2))
               ^ (if d = ".asciz" then "\000" else "")) ]
  | ".space" -> [ M.Space (int_of_string (String.trim args)) ]
  | ".align" -> [ M.Align (int_of_string (String.trim args)) ]
  | ".piece" -> [ M.Piece ]
  | ".text" -> [ M.SectionCode ]
  | ".data" -> [ M.SectionData ]
  | _ -> M.error ("unknown directive " ^ d)

(* a line: labels, then an instruction or a directive; ; starts a comment *)
let parse (text : string) : M.line list =
  let text = match String.index_opt text ';' with
    | Some i when not (String.contains (String.sub text 0 i) '"') ->
        String.sub text 0 i
    | _ -> text in
  let rec go s acc =
    let s = String.trim s in
    match String.index_opt s ':' with
    | Some i when not (String.contains (String.sub s 0 i) ' ')
                  && not (String.contains (String.sub s 0 i) '"') ->
        go (String.sub s (i + 1) (String.length s - i - 1))
          (M.Label (String.sub s 0 i) :: acc)
    | _ when s = "" -> List.rev acc
    | _ ->
        let first c =
          match String.index_opt s c with
          | Some i -> i
          | None -> String.length s in
        let i = min (first ' ') (first '\t') in
        let name = String.sub s 0 i
        and rest = String.sub s i (String.length s - i) in
        let args =
          List.map String.trim
            (if String.trim rest = "" then []
             else String.split_on_char ',' rest) in
        List.rev acc
        @ (if name.[0] = '.' then directive name rest
           else [ instruction name args ]) in
  go text []

(*****************************************************************************)
(* The object *)
(*****************************************************************************)

(* an error at a file's line *)
let at (file : string) n e = M.error (file ^ ":" ^ string_of_int n ^ ": " ^ e)

(* A file's text as lines of assembly (parse, above): each
 * line of text, its number from 1, and its lines (none for a blank
 * one, a comment) *)
let read (chan : Chan.i) : (int * M.line list) list =
  In_channel.input_all chan.ic
  |> String.split_on_char '\n'
  |> List.mapi (fun i text ->
    try i + 1, parse text
    with M.Error e -> at (Chan.origin chan) (i + 1) e)

(* The lines' object (TinyLibMachine's assemble), each text line's
 * lines encoded first, so that an error is said with its file and
 * line (old: the encoding here, TinyLibMachine's since the compilers
 * write objects too) *)
let encode (file : string) (lines : (int * M.line list) list)
    : M.line list =
  M.assemble
    (List.concat_map (fun (n, ls) ->
       try List.map M.encode_line ls with M.Error e -> at file n e) lines)

(* the object written, marshalled (TinyLibMachine's to_object) *)
let write (chan : Chan.o) (items : M.line list) : unit =
  Out_channel.output_string chan.oc (M.to_object items)

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  (* the pipeline: a path, its channel, the lines, the object's lines,
   * the object's channel *)
  let assemble_to (f : Fpath.t) (out : Fpath.t) : Exit.t =
    let lines = TSys.with_open_in caps read f in
    let obj = encode (Fpath.to_string f) lines in
    TSys.with_open_out caps (fun ch -> write ch obj) out;
    Exit.OK in
  (* -S: the lines read, printed *)
  let listing (f : Fpath.t) : Exit.t =
    TSys.with_open_in caps read f
    |> List.iter (fun (_, ls) ->
      List.iter (fun l -> TSys.print caps (M.print_line l)) ls);
    Exit.OK in
  (* x.s's object: x.o, here *)
  let default f = Fpath.set_ext ".o" (Fpath.base f) in
  let assembly f = Filename.check_suffix f ".s" in
  try
    match List.tl (Array.to_list argv) with
    | ("-h" | "--help") :: _ -> TSys.print caps help; Exit.OK
    | [ "-o"; out; f ] when assembly f -> assemble_to (Fpath.v f) (Fpath.v out)
    | [ f ] when assembly f -> assemble_to (Fpath.v f) (default (Fpath.v f))
    | [ "-S"; f ] when assembly f -> listing (Fpath.v f)
    | _ -> TSys.eprint caps (usage ^ "   (-h: how)\n"); Exit.Code 2
  (* (said after the program's name by TSys.main) *)
  with M.Error e -> Exit.Err e

let () = TSys.main "tiny-as" main
