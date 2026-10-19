(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyAssembler.mli *)

open TinyMachineCPU

(* -h: how, by examples, each one as it runs *)
let help = {|usage: tiny-assembler [-o file.o] file.tm

tiny-machine's assembly (TinyMachineCPU's instructions, li, la, call, ret...,
the machine's csrr, csrw, eret, csrrw, amoswap, and .word .byte .ascii .asciz
.space .align) to an object, file.o by default, for tiny-linker. In
tiny/tests/TinyCPU_tests/, for example:
  tiny-assembler hello.tm                  hello.o: its words, its labels, the
                                           places a label's address goes
  tiny-linker -o hello hello.o && tiny-cpu hello        Hello, world
An error names the file and the line: hello.tm:3: not a register: r16
|}

(*****************************************************************************)
(* The items *)
(*****************************************************************************)

type expr = Num of int | Sym of string

(* where a label's address goes in a word, the linker's to fill: the
 * whole word (.word), the immediate (addi's, a load's offset...), its
 * high or low half (la: lui then ori), or a branch's offset in words *)
type kind = Word | Abs | Hi | Lo | Pc
let kinds = [ Word, "word"; Abs, "abs"; Hi, "hi"; Lo, "lo"; Pc, "pc" ]

(* an item: its words made from what the operands resolve to, given the
 * word's index in the item and the place's kind; or bytes, zeros, a
 * label, an alignment, which the linker does (an address's, not the
 * file's) *)
type item = Label of string | Words of int * ((int -> kind -> expr -> int) -> int list) | Bytes_ of string | Space of int | Align of int | Piece

let reg s =
  match String.trim s with
  | "zero" -> 0 | "sp" -> sp | "lr" -> lr
  | s when String.length s >= 2 && s.[0] = 'r' ->
      (match int_of_string_opt (String.sub s 1 (String.length s - 1)) with Some n when n >= 0 && n < 16 -> n | _ -> error "not a register: %s" s)
  | s -> error "not a register: %s" s

let expr s =
  let s = String.trim s in
  if String.length s = 3 && s.[0] = '\'' && s.[2] = '\'' then Num (Char.code s.[1])
  else match int_of_string_opt s with Some n -> Num n | None -> Sym s

(* "off(ra)" or "(ra)" *)
let mem_operand s =
  let s = String.trim s in
  match String.index_opt s '(' with
  | Some i when s.[String.length s - 1] = ')' ->
      let off = String.trim (String.sub s 0 i) in
      reg (String.sub s (i + 1) (String.length s - i - 2)), (if off = "" then Num 0 else expr off)
  | _ -> error "not a memory operand: %s" s

let one f = Words (4, fun res -> [ encode (f (res 0)) ])

(* the machine's own instructions (TinyMachineDevices runs them): a
 * register of control by its name *)
let machine name args =
  let csr s =
    match List.assoc_opt (String.trim s) (List.mapi (fun k n -> n, k) (Array.to_list TinyMachineDevices.csr_names)) with
    | Some k -> k | None -> error "not a register of control: %s" s in
  let w op d a k = Words (4, fun _ -> [ (op lsl 24) lor (d lsl 20) lor (a lsl 16) lor k ]) in
  match name, args with
  | "csrr", [ d; c ] -> w 0x3a (reg d) 0 (csr c)
  | "csrw", [ c; a ] -> w 0x3b 0 (reg a) (csr c)
  | "eret", [] -> w 0x3c 0 0 0
  | "csrrw", [ d; c; a ] -> w 0x3e (reg d) (reg a) (csr c)
  | "amoswap", [ d; a; b ] ->
      let b = String.trim b in
      if String.length b < 2 || b.[0] <> '(' || b.[String.length b - 1] <> ')' then error "amoswap's address: (rN)";
      w 0x3d (reg d) (reg a) (reg (String.sub b 1 (String.length b - 2)))
  | _ -> error "bad instruction: %s %s" name (String.concat ", " args)

let instruction name args : item =
  let args = List.map String.trim (if String.trim args = "" then [] else String.split_on_char ',' args) in
  let alu_of n = match index alu_names n with i -> Some alus.(i) | exception _ -> None in
  let imm_op n = Array.find_opt (fun op -> has_imm op && imm_name op = n) alus in
  match name, args with
  | _, [ d; a; b ] when alu_of name <> None -> one (fun _ -> Alu (Option.get (alu_of name), reg d, reg a, reg b))
  | _, [ d; a; v ] when imm_op name <> None -> one (fun res -> Alui (Option.get (imm_op name), reg d, reg a, res Abs (expr v)))
  | "lui", [ d; v ] -> one (fun res -> Lui (reg d, res Abs (expr v) land 0xffff))
  | ("ldw" | "ldb" | "stw" | "stb"), [ d; m ] ->
      one (fun res ->
        let a, off = mem_operand m in
        let s = if name.[2] = 'w' then W else B in
        if name.[0] = 'l' then Load (s, reg d, a, res Abs off) else Store (s, reg d, a, res Abs off))
  | _, [ d; a; t ] when Array.mem name cmp_names -> one (fun res -> Branch (cmps.(index cmp_names name), reg d, reg a, res Pc (expr t)))
  | "jal", [ d; t ] -> one (fun res -> Jal (reg d, res Pc (expr t)))
  | "jalr", [ d; m ] -> one (fun res -> let a, off = mem_operand m in Jalr (reg d, a, res Abs off))
  | "sys", [ n ] -> one (fun res -> Sys (res Abs (expr n)))
  (* the pseudo-instructions *)
  | "li", [ d; v ] when (match expr v with Num n -> n >= -0x8000 && n < 0x8000 | Sym _ -> false) ->
      one (fun res -> Alui (Add, reg d, 0, res Abs (expr v)))
  | ("li" | "la"), [ d; v ] ->
      Words (8, fun res -> [ encode (Lui (reg d, res 0 Hi (expr v))); encode (Alui (Or, reg d, reg d, res 1 Lo (expr v))) ])
  | "mov", [ d; a ] -> one (fun _ -> Alui (Add, reg d, reg a, 0))
  | "call", [ t ] -> one (fun res -> Jal (lr, res Pc (expr t)))
  | "j", [ t ] -> one (fun res -> Jal (0, res Pc (expr t)))
  | "ret", [] -> one (fun _ -> Jalr (0, lr, 0))
  | "nop", [] -> one (fun _ -> Alui (Add, 0, 0, 0))
  | _ -> machine name args

(* a string's escapes: backslash and n, t or 0, or the character *)
let unescape s =
  let b = Buffer.create (String.length s) in
  let rec go i =
    if i < String.length s then
      if s.[i] = '\\' && i + 1 < String.length s then
        (Buffer.add_char b (match s.[i + 1] with 'n' -> '\n' | 't' -> '\t' | '0' -> '\000' | c -> c); go (i + 2))
      else (Buffer.add_char b s.[i]; go (i + 1)) in
  go 0; Buffer.contents b

let directive d args : item =
  match d with
  | ".word" ->
      let es = List.map expr (String.split_on_char ',' args) in
      Words (4 * List.length es, fun res -> List.mapi (fun i e -> m32 (res i Word e)) es)
  | ".byte" -> Bytes_ (String.concat "" (List.map (fun e -> match expr e with Num n -> String.make 1 (Char.chr (n land 0xff)) | Sym _ -> error ".byte takes numbers") (String.split_on_char ',' args)))
  | ".ascii" | ".asciz" ->
      let a = String.trim args in
      if String.length a < 2 || a.[0] <> '"' || a.[String.length a - 1] <> '"' then error "not a string: %s" a;
      Bytes_ (unescape (String.sub a 1 (String.length a - 2)) ^ if d = ".asciz" then "\000" else "")
  | ".space" -> Space (int_of_string (String.trim args))
  | ".align" -> Align (int_of_string (String.trim args))
  | ".piece" -> Piece
  | _ -> error "unknown directive %s" d

(* a line: labels, then an instruction or a directive; ; starts a comment *)
let parse_line line : item list =
  let line = match String.index_opt line ';' with
    | Some i when not (String.contains (String.sub line 0 i) '"') -> String.sub line 0 i
    | _ -> line in
  let rec go s acc =
    let s = String.trim s in
    match String.index_opt s ':' with
    | Some i when not (String.contains (String.sub s 0 i) ' ') && not (String.contains (String.sub s 0 i) '"') ->
        go (String.sub s (i + 1) (String.length s - i - 1)) (Label (String.sub s 0 i) :: acc)
    | _ when s = "" -> List.rev acc
    | _ ->
        let i = try String.index_from s 0 ' ' with Not_found -> String.length s in
        let i = min i (try String.index s '\t' with Not_found -> String.length s) in
        let name = String.sub s 0 i and rest = String.sub s i (String.length s - i) in
        List.rev acc @ [ (if name.[0] = '.' then directive name rest else instruction name rest) ] in
  go line []

(*****************************************************************************)
(* The object *)
(*****************************************************************************)

(* A file's items as lines, in their order, for tiny-linker
 * (TinyLinker.mli has the format): a word whose operand is a number is
 * made here, one whose operand is a label is made with 0 there and a
 * reloc line says what goes in it; a branch to a number too, its
 * offset being from an address the link chooses *)
let assemble name text =
  let b = Buffer.create 4096 in
  let line fmt = Printf.ksprintf (fun s -> Buffer.add_string b (s ^ "\n")) fmt in
  let hex s = let h = Buffer.create (2 * String.length s) in String.iter (fun c -> Buffer.add_string h (Printf.sprintf "%02x" (Char.code c))) s; Buffer.contents h in
  let target = function Num n -> string_of_int n | Sym s -> s in
  line "tiny-object";
  (* each file on a word's boundary: one may end with bytes, the next
   * begin with code *)
  line "align 4";
  List.iteri (fun n l ->
    let items = try parse_line l with Error e -> error "%s:%d: %s" name (n + 1) e in
    List.iter (fun it ->
      match it with
      | Label l -> line "label %s" l
      | Align k -> line "align %d" k
      | Piece -> line "piece"
      | Space k -> line "space %d" k
      | Bytes_ s -> line "code %s" (hex s)
      | Words (_, f) ->
          let relocs = ref [] in
          let res i k e =
            match k, e with
            | Pc, _ | _, Sym _ -> relocs := (4 * i, k, e) :: !relocs; 0
            | Word, Num n -> m32 n
            | Hi, Num n -> m32 n lsr 16
            | Lo, Num n -> m32 n land 0xffff
            | Abs, Num n -> n in
          let ws = try f res with Error e -> error "%s:%d: %s" name (n + 1) e in
          let s = Bytes.create (4 * List.length ws) in
          List.iteri (fun i w -> Bytes.set_int32_le s (4 * i) (Int32.of_int w)) ws;
          line "code %s" (hex (Bytes.to_string s));
          (* (by offset: a list's words are made from the last) *)
          List.iter (fun (off, k, e) -> line "reloc %d %s %s" off (List.assoc k kinds) (target e))
            (List.sort (fun (a, _, _) (b, _, _) -> compare a b) !relocs)) items)
    (String.split_on_char '\n' text);
  Buffer.contents b

let main (caps : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. >) =
  match List.tl (Array.to_list (CapSys.argv caps)) with
  | ("-h" | "--help") :: _ -> Console.print caps help; 0
  | ([ "-o"; _; f ] | [ f ]) as args when Filename.check_suffix f ".tm" ->
      let out = match args with [ "-o"; o; _ ] -> o | _ -> Filename.chop_suffix (Filename.basename f) ".tm" ^ ".o" in
      (try FS.write caps (Fpath.v out) (assemble f (FS.read caps (Fpath.v f))); 0
       with Error e | Sys_error e -> Console.eprint caps ("tiny-assembler: " ^ e ^ "\n"); 1)
  | _ -> Console.eprint caps "usage: tiny-assembler [-o file.o] file.tm   (-h: how)\n"; 2

let () = Cap.main (fun caps -> CapStdlib.exit caps (main caps))
