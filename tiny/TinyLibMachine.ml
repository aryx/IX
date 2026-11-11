(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyLibMachine.mli *)

(*****************************************************************************)
(* The instructions *)
(*****************************************************************************)

type reg = int
[@@deriving show]

type alu =
  | Add | Sub | Mul | Div | Rem | And | Or | Xor | Shl | Shr | Sar | Slt | Sltu
[@@deriving show]
type cmp = Eq | Ne | Lt | Ge | Ltu | Geu
[@@deriving show]
type size = W | B
[@@deriving show]

type instr =
  | Alu of alu * reg * reg * reg          (* d, a, b *)
  | Alui of alu * reg * reg * int
      (* d, a, imm: add and or xor shl shr sar slt sltu *)
  | Lui of reg * int
  | Load of size * reg * reg * int        (* d, a, offset *)
  | Store of size * reg * reg * int       (* the value's register, a, offset *)
  | Branch of cmp * reg * reg * int
      (* d, a, offset in words, from pc + 4 *)
  | Jal of reg * int
  | Jalr of reg * reg * int
  | Sys of int
[@@deriving show]

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

(* an instruction's word, an int, and any 32 bits, an Int32 (the .mli
 * says why) *)
type instr_word = int
type word = int32
[@@deriving show]

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
[@@deriving show]

(* (old: the assembler's, by hand) *)
let encode_machine (m : machine_instr) : instr_word =
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
 * The opcodes stop at 0x3f, which keeps instr_word an int *)
let encode i : instr_word =
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
  | Jal (d, off) ->
      if not (fits16 off) then error "jump too far";
      w 0x38 d 0 off
  | Jalr (d, a, off) -> w 0x39 d a off
  | Sys n -> w 0x3f 0 0 n

let decode (w : instr_word) =
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
 * address). The one printer of the instructions: a listing's (listing,
 * below) and the assembly's (print_line). (old: two, the
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
let listing pc i =
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
(* The lines of assembly *)
(*****************************************************************************)

(* (tiny-ml's; ppx_deriving and mini-ml derive the real one, after it) *)
let show_line _ = "NO DERIVING"
[@@warning "-32"]

type sym = string
[@@deriving show]

(* where a label's address goes in an instruction or a word, and what
 * goes there (TinyLibMachine.mli has them by example). Full, all 32
 * bits of a word (old: Word, the name .word's line has) *)
type place = Full | Abs | Hi | Lo | Pc
[@@deriving show]
type target = Name of string | Address of int
[@@deriving show]

(* an offset in a chunk's bytes, its kind, what goes there *)
type reloc = int * place * target
[@@deriving show]

(* (TinyLibMachine.mli says each; the object's lines are the last ones,
 * Chunk and those it shares with the assembly) *)
type line =
  | Instr of instr
  | Instr_at of instr * place * target
  | Machine of machine_instr
  | Li of reg * word
  | La of reg * sym
  | Mov of reg * reg
  | Call of sym
  | Jump of sym
  | Branch_to of cmp * reg * reg * sym
  | Ret
  | Label of sym
  | Align of int
  | Space of int
  | Bytes of int list
  | Ascii of string
  | Word of word
  | Word_sym of sym
  | Piece
  | SectionCode
  | SectionData
  | Chunk of string * reloc list
[@@deriving show]

(*****************************************************************************)
(* Printing *)
(*****************************************************************************)

(* (a register by its name) *)
let reg = reg_name

(* a word, signed, in decimal (old: an int64's low 32 bits, sign-extended
 * first; older: Printf's %ld of Int64.to_int32, in each compiler) *)
let word (v : word) = Int32.to_string v

let target_text (t : target) =
  match t with Name s -> s | Address n -> string_of_int n

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

let print_line (l : line) =
  let ins s = "\t" ^ s ^ "\n" in
  match l with
  | Instr i -> ins (text i None)
  | Instr_at (i, _, t) -> ins (text i (Some (target_text t)))
  | Machine m -> ins (machine_text m)
  | Li (d, v) -> ins ("li\t" ^ reg d ^ ", " ^ word v)
  | La (d, s) -> ins ("la\t" ^ reg d ^ ", " ^ s)
  | Mov (d, a) -> ins ("mov\t" ^ reg d ^ ", " ^ reg a)
  | Call s -> ins ("call\t" ^ s)
  | Jump s -> ins ("j\t" ^ s)
  | Branch_to (c, d, a, s) ->
      ins (cmp_names.(index cmps c) ^ "\t" ^ reg d ^ ", " ^ reg a
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

  (* an object's bytes are not assembly again: their size and their
   * places, for a reader (tiny-linker -debug shows them whole) *)
  | Chunk (b, places) ->
      ins (";\t" ^ string_of_int (String.length b) ^ " bytes, "
           ^ string_of_int (List.length places) ^ " places")

(*****************************************************************************)
(* The objects *)
(*****************************************************************************)

(* a word's bytes, the low first: the memory's order *)
let word_bytes (w : word) =
  String.init 4 (fun i ->
    Char.chr
      (Int32.to_int
         (Int32.logand (Int32.shift_right_logical w (8 * i))
            (Int32.of_int 0xff))))

(* instructions' words, and the places in them the link fills *)
let code (is : instr list) relocs : line =
  Chunk
    (String.concat ""
       (List.map (fun i -> word_bytes (Int32.of_int (encode i))) is),
     relocs)

(* a number of 16 bits, li's in one instruction, else its two halves; a
 * word is signed, so a compiler's 0xfffffff0 is -16, one instruction
 * (old: an int64, its low 32 bits read signed first) *)
let small (v : word) =
  Int32.compare v (Int32.of_int (-32768)) >= 0
  && Int32.compare v (Int32.of_int 32767) <= 0
let half (v : word) shift =
  Int32.to_int
    (Int32.logand (Int32.shift_right_logical v shift) (Int32.of_int 0xffff))

(* (old: TinyAssembler's item: the compilers encode their lines too) *)
let encode_line (l : line) : line =
  let to_ s k = [ (0, k, Name s) ] in
  match l with
  | Instr i -> code [ i ] []
  | Instr_at (i, k, t) -> code [ i ] [ (0, k, t) ]
  | Machine m -> Chunk (word_bytes (Int32.of_int (encode_machine m)), [])
  | Li (d, v) when small v ->
      code [ Alui (Add, d, 0, Int32.to_int v) ] []
  | Li (d, v) -> code [ Lui (d, half v 16); Alui (Or, d, d, half v 0) ] []
  | La (d, s) ->
      code [ Lui (d, 0); Alui (Or, d, d, 0) ]
        [ (0, Hi, Name s); (4, Lo, Name s) ]
  | Mov (d, a) -> code [ Alui (Add, d, a, 0) ] []
  | Call s -> code [ Jal (lr, 0) ] (to_ s Pc)
  | Jump s -> code [ Jal (0, 0) ] (to_ s Pc)
  | Branch_to (c, d, a, s) -> code [ Branch (c, d, a, 0) ] (to_ s Pc)
  | Ret -> code [ Jalr (0, lr, 0) ] []
  | Bytes bs ->
      Chunk
        (String.concat "" (List.map (fun b -> String.make 1 (Char.chr b)) bs),
         [])
  | Ascii s -> Chunk (s, [])
  | Word v -> Chunk (word_bytes v, [])
  | Word_sym s -> Chunk (word_bytes Int32.zero, to_ s Full)
  (* the lines the link places by, and a chunk, already encoded *)
  | Label _ | Align _ | Space _ | Piece | SectionCode | SectionData
  | Chunk _ -> l

(* each file on a word's boundary: one may end with bytes, the next
 * begin with code *)
let assemble (lines : line list) : line list =
  Align 4 :: List.map encode_line lines

(* does s start with m *)
let starts s m = String.length s >= String.length m
                 && String.sub s 0 (String.length m) = m

(* (Marshal's bytes after it: tiny-ml's Marshal stops the program on
 * bytes it cannot read, so another file is said not an object first.
 * 3: an object is lines, the assembly's type (old: 2, an item type of
 * its own, the same constructors; 1, the sections a bool): an older
 * object is refused, not misread) *)
let magic = "tiny-object 3\n"
let to_object (lines : line list) =
  magic ^ Marshal.to_string lines [ Marshal.No_sharing ]
let of_object (s : string) : line list =
  if not (starts s magic) then
    error "not an object of this tiny-assembler's (tiny-object 3): rebuild it";
  Marshal.from_string s (String.length magic)

(* an archive: its magic line, then each member's name and size on a
 * line, then its bytes, as Unix's ar's header before each member (its
 * 60 bytes, a name, a date, an owner, a mode and a size, the name and
 * the size here) *)
let archive_magic = "tiny-archive 1\n"
let is_archive (s : string) = starts s archive_magic
let to_archive (members : (string * string) list) : string =
  archive_magic
  ^ String.concat ""
      (List.map (fun (name, o) ->
         if not (starts o magic) then error (name ^ ": not an object");
         if String.contains name ' ' || String.contains name '\n' then
           error (name ^ ": a member's name has no blank");
         name ^ " " ^ string_of_int (String.length o) ^ "\n" ^ o)
         members)
let of_archive (s : string) : (string * string) list =
  if not (is_archive s) then error "not an archive";
  let rec from i =
    if i >= String.length s then []
    else
      let nl =
        match String.index_from_opt s i '\n' with
        | Some nl -> nl
        | None -> error "a damaged archive" in
      match String.split_on_char ' ' (String.sub s i (nl - i)) with
      | [ name; size ] ->
          let n =
            match int_of_string_opt size with
            | Some n when n >= 0 && nl + 1 + n <= String.length s -> n
            | _ -> error "a damaged archive" in
          (name, String.sub s (nl + 1) n) :: from (nl + 1 + n)
      | _ -> error "a damaged archive" in
  from (String.length archive_magic)

(*****************************************************************************)
(* The symbols *)
(*****************************************************************************)

(* (TinyLibSymbols.ml's, old) *)

type label = string
type address = int
type symbols = (label * address) array

(* a dot, an L, digits *)
let local name =
  match String.rindex_opt name '.' with
  | Some i when i + 2 < String.length name && name.[i + 1] = 'L' ->
      String.for_all (fun c -> c >= '0' && c <= '9')
        (String.sub name (i + 2) (String.length name - i - 2))
  | _ -> false

(* <unit>.f<number>_<name> (old: f<number>_<name><>, a program's
 * functions in one file) *)
let clean name =
  let n = String.length name in
  let digit c = c >= '0' && c <= '9' in
  let rec find i =
    if i + 2 >= n then None
    else if name.[i] = '.' && name.[i + 1] = 'f' && digit name.[i + 2] then
      Some i
    else find (i + 1) in
  match find 0 with
  | Some i ->
      let rec skip j = if j < n && digit name.[j] then skip (j + 1) else j in
      let j = skip (i + 2) in
      if j < n && name.[j] = '_' then
        (let short = String.sub name (j + 1) (n - j - 1) in
         if short = "fun" then name else short)
      else name
  | None -> name

let labels text =
  let l =
    text
    |> String.split_on_char '\n'
    |> List.filter_map (fun line ->
      match String.split_on_char ' ' line with
      | [ a; l ] when not (local l) ->
          (match int_of_string_opt ("0x" ^ a) with
           | Some a -> Some (l, a)
           | None -> None)
      | _ -> None) in
  l |> List.sort (fun (_, a) (_, b) -> compare a b) |> Array.of_list

(* by halves *)
let find funcs pc =
  let rec go lo hi =
    if hi - lo <= 1 then lo
    else
      let mid = (lo + hi) / 2 in
      if snd funcs.(mid) <= pc then go mid hi else go lo mid in
  if Array.length funcs = 0 || pc < snd funcs.(0) then None
  else
    let name, a = funcs.(go 0 (Array.length funcs)) in
    Some (clean name, a)

let address funcs name =
  let rec go i =
    if i >= Array.length funcs then None
    else
      let l, a = funcs.(i) in
      if l = name || clean l = name then Some a else go (i + 1) in
  go 0
