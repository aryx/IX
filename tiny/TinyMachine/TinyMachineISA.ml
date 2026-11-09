(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMachineISA.mli *)

(*****************************************************************************)
(* The instructions *)
(*****************************************************************************)

type reg = int

type alu =
  | Add | Sub | Mul | Div | Rem | And | Or | Xor | Shl | Shr | Sar | Slt | Sltu
type cmp = Eq | Ne | Lt | Ge | Ltu | Geu
type size = W | B

type instr =
  | Alu of alu * reg * reg * reg          (* d, a, b *)
  | Alui of alu * reg * reg * int
      (* d, a, imm: add and or xor shl shr sar slt sltu *)
  | Lui of reg * int
  | Load of size * reg * reg * int        (* d, a, offset *)
  | Store of size * reg * reg * int       (* the value's register, a, offset *)
  | Branch of cmp * reg * reg * int       (* d, a, offset in words, from pc + 4 *)
  | Jal of reg * int
  | Jalr of reg * reg * int
  | Sys of int

(* (old: [| ... |], which tiny-ml does not read) *)
let alus =
  Array.of_list [ Add; Sub; Mul; Div; Rem; And; Or; Xor; Shl; Shr; Sar; Slt;
                  Sltu ]
let alu_names =
  Array.of_list [ "add"; "sub"; "mul"; "div"; "rem"; "and"; "or"; "xor";
                  "shl"; "shr"; "sar"; "slt"; "sltu" ]
let cmps = Array.of_list [ Eq; Ne; Lt; Ge; Ltu; Geu ]
let cmp_names = Array.of_list [ "beq"; "bne"; "blt"; "bge"; "bltu"; "bgeu" ]
let index a x = let rec go i = if a.(i) = x then i else go (i + 1) in go 0

(* an immediate form's name: the operation's and an i, but sltiu (MIPS's) *)
let imm_name op =
  match op with Sltu -> "sltiu" | _ -> alu_names.(index alus op) ^ "i"

(* the immediate forms: those whose immediate is zero-extended *)
let unsigned_imm op = match op with And | Or | Xor -> true | _ -> false
let has_imm op = match op with Mul | Div | Rem | Sub -> false | _ -> true

let sext16 v = ((v land 0xffff) lxor 0x8000) - 0x8000

let sp = 14 and lr = 15

(* the machine's registers of control, by number (TinyMachineDevices's) *)
let csr_names =
  Array.of_list [ "status"; "epc"; "cause"; "tval"; "tvec"; "time"; "timecmp";
                  "base"; "bound"; "core"; "ip"; "ie"; "satp"; "scratch";
                  "rate"; "cores"; "tbase"; "tbound" ]

exception Error of string
(* old: Printf.ksprintf's, a format and its values *)
let error s = raise (Error s)

(* the machine's own instructions, which TinyMachineDevices runs, not
 * the CPU: a register of control (csr) by its number *)
type machine_instr =
  | Csrr of reg * int                 (* d, csr *)
  | Csrw of int * reg                 (* csr, a *)
  | Eret
  | Wfi
  | Csrrw of reg * int * reg          (* d, csr, a: both at once *)
  | Amoswap of reg * reg * reg        (* d, a, (b) *)

(* (old: the assembler's, by hand) *)
let encode_machine (m : machine_instr) : int =
  let w op d a k = (op lsl 24) lor (d lsl 20) lor (a lsl 16) lor k in
  match m with
  | Csrr (d, c) -> w 0x3a d 0 c
  | Csrw (c, a) -> w 0x3b 0 a c
  | Eret -> w 0x3c 0 0 0
  | Wfi -> w 0x37 0 0 0
  | Csrrw (d, c, a) -> w 0x3e d a c
  | Amoswap (d, a, b) -> w 0x3d d a b

(* a number in hexadecimal, 0x and its digits *)
let hex n = Printf.sprintf "0x%x" n

(*****************************************************************************)
(* The words *)
(*****************************************************************************)

(* opcodes: 0x01-0x0d the ALU, 0x11-0x1d its immediate forms, then the
 * rest; 0 is no instruction, so that zeroed memory stops a program.
 * An instruction's word is under 2^30 (its opcode under 0x40), so it
 * is an int for tiny-ml too, whose ints have 31 bits *)
let encode i =
  let w op d a imm =
    (op lsl 24) lor (d lsl 20) lor (a lsl 16) lor (imm land 0xffff) in
  let fits16 v = v >= -0x8000 && v < 0x8000 in
  match i with
  | Alu (op, d, a, b) -> w (1 + index alus op) d a b
  | Alui (op, d, a, imm) ->
      if not (if unsigned_imm op then imm >= 0 && imm < 0x10000
              else fits16 imm) then
        error ("immediate " ^ string_of_int imm ^ " out of range");
      w (0x11 + index alus op) d a imm
  | Lui (d, imm) -> w 0x20 d 0 imm
  | Load (s, d, a, off) ->
      if not (fits16 off) then
        error ("offset " ^ string_of_int off ^ " out of range");
      w (if s = W then 0x21 else 0x22) d a off
  | Store (s, d, a, off) ->
      if not (fits16 off) then
        error ("offset " ^ string_of_int off ^ " out of range");
      w (if s = W then 0x23 else 0x24) d a off
  | Branch (c, d, a, off) ->
      if not (fits16 off) then error "branch too far";
      w (0x30 + index cmps c) d a off
  | Jal (d, off) -> if not (fits16 off) then error "jump too far"; w 0x38 d 0 off
  | Jalr (d, a, off) -> w 0x39 d a off
  | Sys n -> w 0x3f 0 0 n

let decode w =
  let op = (w lsr 24) land 0xff and d = (w lsr 20) land 15
  and a = (w lsr 16) land 15 and imm = w land 0xffff in
  match op with
  | _ when op >= 0x01 && op <= 0x0d ->
      Some (Alu (alus.(op - 1), d, a, imm land 15))
  | _ when op >= 0x11 && op <= 0x1d && has_imm alus.(op - 0x11) ->
      let alu = alus.(op - 0x11) in
      Some (Alui (alu, d, a, if unsigned_imm alu then imm else sext16 imm))
  | 0x20 -> Some (Lui (d, imm))
  | 0x21 -> Some (Load (W, d, a, sext16 imm))
  | 0x22 -> Some (Load (B, d, a, sext16 imm))
  | 0x23 -> Some (Store (W, d, a, sext16 imm))
  | 0x24 -> Some (Store (B, d, a, sext16 imm))
  | _ when op >= 0x30 && op <= 0x35 ->
      Some (Branch (cmps.(op - 0x30), d, a, sext16 imm))
  | 0x38 -> Some (Jal (d, sext16 imm))
  | 0x39 -> Some (Jalr (d, a, sext16 imm))
  | 0x3f -> Some (Sys imm)
  | _ -> None

(* a register's name: zero, sp, lr, or r1 to r13 *)
let reg_name (r : reg) =
  if r = 0 then "zero" else if r = sp then "sp" else if r = lr then "lr"
  else "r" ^ string_of_int r

(* An instruction's text, its registers by their names; its immediate,
 * or its offset, the given text when there is one (a label's name, an
 * address). The one printer of the instructions: a listing's (print,
 * below) and the assembly's (TinyMachineAsm's). (old: two, the
 * listing's registers r0, r14, r15) *)
let text (i : instr) (imm_text : string option) : string =
  let r = reg_name in
  let imm k = match imm_text with Some s -> s | None -> string_of_int k in
  let mem off a = imm off ^ "(" ^ r a ^ ")" in
  match i with
  | Alu (op, d, a, b) ->
      alu_names.(index alus op) ^ "\t" ^ r d ^ ", " ^ r a ^ ", " ^ r b
  | Alui (op, d, a, k) ->
      imm_name op ^ "\t" ^ r d ^ ", " ^ r a ^ ", " ^ imm k
  | Lui (d, k) ->
      "lui\t" ^ r d ^ ", "
      ^ (match imm_text with Some s -> s | None -> hex k)
  | Load (s, d, a, off) ->
      (if s = W then "ldw" else "ldb") ^ "\t" ^ r d ^ ", " ^ mem off a
  | Store (s, d, a, off) ->
      (if s = W then "stw" else "stb") ^ "\t" ^ r d ^ ", " ^ mem off a
  | Branch (c, d, a, off) ->
      cmp_names.(index cmps c) ^ "\t" ^ r d ^ ", " ^ r a ^ ", " ^ imm off
  | Jal (d, off) -> "jal\t" ^ r d ^ ", " ^ imm off
  | Jalr (d, a, off) -> "jalr\t" ^ r d ^ ", " ^ mem off a
  | Sys k -> "sys\t" ^ imm k

(* an instruction as a listing shows it, [pc] its address: a branch's
 * or a jal's target as an address *)
let print pc i =
  let target off = Some (hex (pc + 4 + (4 * off))) in
  match i with
  | Branch (_, _, _, off) -> text i (target off)
  | Jal (_, off) -> text i (target off)
  | _ -> text i None

(* a machine instruction's text, a register of control by its name *)
let machine_text (m : machine_instr) =
  let r = reg_name and csr c = csr_names.(c) in
  match m with
  | Csrr (d, c) -> "csrr\t" ^ r d ^ ", " ^ csr c
  | Csrw (c, a) -> "csrw\t" ^ csr c ^ ", " ^ r a
  | Eret -> "eret"
  | Wfi -> "wfi"
  | Csrrw (d, c, a) -> "csrrw\t" ^ r d ^ ", " ^ csr c ^ ", " ^ r a
  | Amoswap (d, a, b) ->
      "amoswap\t" ^ r d ^ ", " ^ r a ^ ", (" ^ r b ^ ")"

(*****************************************************************************)
(* The objects *)
(*****************************************************************************)

(* (tiny-ml's; ppx_deriving and mini-ml derive the real one, after it) *)
let show_item _ = "NO DERIVING"
[@@warning "-32"]

type place = Word | Abs | Hi | Lo | Pc
[@@deriving show]
type target = Name of string | Address of int
[@@deriving show]
type item =
  | Label of string | Align of int | Space of int
  | Chunk of string * (int * place * target) list | Piece
  | SectionCode | SectionData
[@@deriving show]

(* (Marshal's bytes after it: tiny-ml's Marshal stops the program on
 * bytes it cannot read, so another file is said not an object first.
 * 2: the sections two constructors, old Section of bool, true the
 * data's: an object of 1 is refused, not misread) *)
let magic = "tiny-object 2\n"
let to_object (items : item list) =
  magic ^ Marshal.to_string items [ Marshal.No_sharing ]
let of_object (s : string) : item list =
  let n = String.length magic in
  if String.length s < n || String.sub s 0 n <> magic then
    error "not an object of tiny-assembler's";
  Marshal.from_string s n
