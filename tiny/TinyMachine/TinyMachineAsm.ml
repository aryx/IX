(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMachineAsm.mli *)
module ISA = TinyMachineISA

type sym = string

type line =
  | Instr of ISA.instr
  | Instr_at of ISA.instr * ISA.place * ISA.target
  | Machine of ISA.machine_instr
  | Li of ISA.reg * int64
  | La of ISA.reg * sym
  | Mov of ISA.reg * ISA.reg
  | Call of sym
  | Jump of sym
  | Branch of ISA.cmp * ISA.reg * ISA.reg * sym
  | Ret
  | Label of sym
  | Align of int
  | Space of int
  | Bytes of int list
  | Ascii of string
  | Word of int64
  | Word_sym of sym
  | Piece
  | SectionCode
  | SectionData

(*****************************************************************************)
(* Printing *)
(*****************************************************************************)

(* (a register by its name, TinyMachineISA's) *)
let reg = ISA.reg_name

(* a number's low 32 bits, signed, in decimal (old: Printf's %ld of
 * Int64.to_int32, in each compiler) *)
let word v = Int64.to_string (Int64.shift_right (Int64.shift_left v 32) 32)

let target (t : ISA.target) =
  match t with ISA.Name s -> s | ISA.Address n -> string_of_int n

(* a string as .ascii writes it: a quote, a backslash, a newline, a tab
 * and a 0 escaped *)
let quoted s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  String.iter (fun c ->
    match c with
    | '"' -> Buffer.add_string b "\\\""
    | '\\' -> Buffer.add_string b "\\\\"
    | '\n' -> Buffer.add_string b "\\n"
    | '\t' -> Buffer.add_string b "\\t"
    | '\000' -> Buffer.add_string b "\\0"
    | c -> Buffer.add_char b c) s;
  Buffer.add_char b '"';
  Buffer.contents b

let print (l : line) =
  let ins s = "\t" ^ s ^ "\n" in
  match l with
  | Instr i -> ins (ISA.text i None)
  | Instr_at (i, _, t) -> ins (ISA.text i (Some (target t)))
  | Machine m -> ins (ISA.machine_text m)
  | Li (d, v) -> ins ("li\t" ^ reg d ^ ", " ^ word v)
  | La (d, s) -> ins ("la\t" ^ reg d ^ ", " ^ s)
  | Mov (d, a) -> ins ("mov\t" ^ reg d ^ ", " ^ reg a)
  | Call s -> ins ("call\t" ^ s)
  | Jump s -> ins ("j\t" ^ s)
  | Branch (c, d, a, s) ->
      ins (ISA.cmp_names.(ISA.index ISA.cmps c) ^ "\t" ^ reg d ^ ", " ^ reg a
           ^ ", " ^ s)
  | Ret -> ins "ret"
  | Label s -> s ^ ":\n"
  | Align k -> ins (".align\t" ^ string_of_int k)
  | Space k -> ins (".space\t" ^ string_of_int k)
  | Bytes l -> ins (".byte\t" ^ String.concat ", " (List.map string_of_int l))
  | Ascii s -> ins (".ascii\t" ^ quoted s)
  | Word v -> ins (".word\t" ^ word v)
  | Word_sym s -> ins (".word\t" ^ s)
  | Piece -> ins ".piece"
  | SectionCode -> ins ".text"
  | SectionData -> ins ".data"

(*****************************************************************************)
(* Parsing *)
(*****************************************************************************)

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
  if h < 0x4000 || h >= 0xc000 then (ISA.sext16 h * 0x10000) + l
  else ISA.error "number out of range"

(* as an int64, its 32 bits signed (in Int64: h * 0x10000 needs 32) *)
let int64_of ((h, l) : halves) : int64 =
  Int64.add (Int64.mul (Int64.of_int (ISA.sext16 h)) (Int64.of_int 0x10000))
    (Int64.of_int l)

(* an operand: a number (a character too, 'c'), or a label *)
type arg = Arg_num of halves | Arg_sym of sym

let arg (s : string) : arg =
  let s = String.trim s in
  if String.length s = 3 && s.[0] = '\'' && s.[2] = '\'' then
    Arg_num (0, Char.code s.[1])
  else match halves s with Some n -> Arg_num n | None -> Arg_sym s

let target_of (a : arg) : ISA.target =
  match a with Arg_num n -> ISA.Address (int_of n) | Arg_sym s -> ISA.Name s

let parse_reg (s : string) : ISA.reg =
  match String.trim s with
  | "zero" -> 0 | "sp" -> ISA.sp | "lr" -> ISA.lr
  | s when String.length s >= 2 && s.[0] = 'r' ->
      (match int_of_string_opt (String.sub s 1 (String.length s - 1)) with
       | Some n when n >= 0 && n < 16 -> n
       | _ -> ISA.error ("not a register: " ^ s))
  | s -> ISA.error ("not a register: " ^ s)

(* "off(ra)" or "(ra)" *)
let mem_operand (s : string) : ISA.reg * arg =
  let s = String.trim s in
  match String.index_opt s '(' with
  | Some i when s.[String.length s - 1] = ')' ->
      let off = String.trim (String.sub s 0 i) in
      parse_reg (String.sub s (i + 1) (String.length s - i - 2)),
      (if off = "" then Arg_num (0, 0) else arg off)
  | _ -> ISA.error ("not a memory operand: " ^ s)

(* an instruction whose immediate is a, absolute: the number in it, or
 * 0 and the label for the link *)
let with_imm (f : int -> ISA.instr) (a : arg) : line =
  match a with
  | Arg_num n -> Instr (f (int_of n))
  | Arg_sym s -> Instr_at (f 0, ISA.Abs, ISA.Name s)

(* a jump or a branch to a: 0, and the words to it for the link *)
let with_pc (f : int -> ISA.instr) (a : arg) : line =
  Instr_at (f 0, ISA.Pc, target_of a)

(* the machine's own instructions: a register of control by its name *)
let machine_instr (name : string) (args : string list) : line =
  let csr s =
    match List.assoc_opt (String.trim s)
            (List.mapi (fun k n -> n, k) (Array.to_list ISA.csr_names)) with
    | Some k -> k | None -> ISA.error ("not a register of control: " ^ s) in
  let r = parse_reg in
  match name, args with
  | "csrr", [ d; c ] -> Machine (ISA.Csrr (r d, csr c))
  | "csrw", [ c; a ] -> Machine (ISA.Csrw (csr c, r a))
  | "eret", [] -> Machine ISA.Eret
  | "wfi", [] -> Machine ISA.Wfi
  | "csrrw", [ d; c; a ] -> Machine (ISA.Csrrw (r d, csr c, r a))
  | "amoswap", [ d; a; b ] ->
      let b = String.trim b in
      if String.length b < 2 || b.[0] <> '(' || b.[String.length b - 1] <> ')'
      then ISA.error "amoswap's address: (rN)";
      Machine (ISA.Amoswap (r d, r a, r (String.sub b 1 (String.length b - 2))))
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

let instruction (name : string) (args : string list) : line =
  let r = parse_reg in
  match Hashtbl.find_opt named name, args with
  | Some (Op op), [ d; a; b ] -> Instr (ISA.Alu (op, r d, r a, r b))
  | Some (Imm op), [ d; a; v ] ->
      with_imm (fun k -> ISA.Alui (op, r d, r a, k)) (arg v)
  | Some (Test c), [ d; a; t ] ->
      (match arg t with
       | Arg_sym s -> Branch (c, r d, r a, s)
       | n -> with_pc (fun k -> ISA.Branch (c, r d, r a, k)) n)
  | _ ->
      match name, args with
      | "lui", [ d; v ] ->
          (match arg v with
           | Arg_num n -> Instr (ISA.Lui (r d, int_of n land 0xffff))
           | a -> with_imm (fun k -> ISA.Lui (r d, k)) a)
      | ("ldw" | "ldb" | "stw" | "stb"), [ d; m ] ->
          let a, off = mem_operand m in
          let s = if name.[2] = 'w' then ISA.W else ISA.B in
          with_imm (fun k ->
            if name.[0] = 'l' then ISA.Load (s, r d, a, k)
            else ISA.Store (s, r d, a, k)) off
      | "jal", [ d; t ] -> with_pc (fun k -> ISA.Jal (r d, k)) (arg t)
      | "jalr", [ d; m ] ->
          let a, off = mem_operand m in
          with_imm (fun k -> ISA.Jalr (r d, a, k)) off
      | "sys", [ n ] -> with_imm (fun k -> ISA.Sys k) (arg n)
      (* the pseudo-instructions (la of a number is li's) *)
      | ("li" | "la"), [ d; v ] ->
          (match arg v with
           | Arg_num n -> Li (r d, int64_of n)
           | Arg_sym s -> La (r d, s))
      | "mov", [ d; a ] -> Mov (r d, r a)
      | "call", [ t ] ->
          (match arg t with
           | Arg_sym s -> Call s
           | n -> with_pc (fun k -> ISA.Jal (ISA.lr, k)) n)
      | "j", [ t ] ->
          (match arg t with
           | Arg_sym s -> Jump s
           | n -> with_pc (fun k -> ISA.Jal (0, k)) n)
      | "ret", [] -> Ret
      | "nop", [] -> Instr (ISA.Alui (ISA.Add, 0, 0, 0))
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

let directive (d : string) (args : string) : line list =
  match d with
  | ".word" ->
      List.map (fun a ->
        match arg a with
        | Arg_num n -> Word (int64_of n)
        | Arg_sym s -> Word_sym s)
        (String.split_on_char ',' args)
  | ".byte" ->
      [ Bytes (List.map (fun a ->
          match arg a with
          | Arg_num (_, l) -> l land 0xff
          | Arg_sym _ -> ISA.error ".byte takes numbers")
          (String.split_on_char ',' args)) ]
  | ".ascii" | ".asciz" ->
      let a = String.trim args in
      if String.length a < 2 || a.[0] <> '"' || a.[String.length a - 1] <> '"'
      then ISA.error ("not a string: " ^ a);
      [ Ascii (unescape (String.sub a 1 (String.length a - 2))
               ^ (if d = ".asciz" then "\000" else "")) ]
  | ".space" -> [ Space (int_of_string (String.trim args)) ]
  | ".align" -> [ Align (int_of_string (String.trim args)) ]
  | ".piece" -> [ Piece ]
  | ".text" -> [ SectionCode ]
  | ".data" -> [ SectionData ]
  | _ -> ISA.error ("unknown directive " ^ d)

(* a line: labels, then an instruction or a directive; ; starts a comment *)
let parse (text : string) : line list =
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
        let args =
          List.map String.trim
            (if String.trim rest = "" then []
             else String.split_on_char ',' rest) in
        List.rev acc
        @ (if name.[0] = '.' then directive name rest
           else [ instruction name args ]) in
  go text []
