(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *
 * See TinyAssembler.mli
 *)
module ISA = TinyMachineISA
module Asm = TinyMachineAsm
module TSys = TinyLibSystem

(* what tiny-assembler asks for: its file read, its object written *)
type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

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
(* The lines' items *)
(*****************************************************************************)

(* a word's bytes, the low first: the memory's order (an int64: a word
 * of data has 32 bits, tiny-ml's ints 31) *)
let word_bytes (w : int64) =
  String.init 4 (fun i ->
    Char.chr
      (Int64.to_int
         (Int64.logand (Int64.shift_right w (8 * i)) (Int64.of_int 0xff))))

(* instructions' words, and the places in them the link fills *)
let code (is : ISA.instr list) relocs : ISA.item =
  ISA.Chunk
    (String.concat ""
       (List.map (fun i -> word_bytes (Int64.of_int (ISA.encode i))) is),
     relocs)

(* a number of 16 bits, li's in one instruction; else its two halves *)
let small (v : int64) =
  Int64.compare v (Int64.of_int (-32768)) >= 0
  && Int64.compare v (Int64.of_int 32767) <= 0
let half (v : int64) shift =
  Int64.to_int (Int64.logand (Int64.shift_right v shift) (Int64.of_int 0xffff))

(* A line's item: an instruction's words, with 0 where a label's
 * address goes and the place for the link (a branch's, a call's: the
 * words from the next instruction, Pc; la's: its halves, Hi and Lo);
 * data's bytes; or the object's own item (a label, an alignment, which
 * the link does: an address's, not the file's) *)
let item (l : Asm.line) : ISA.item =
  let to_ s k = [ (0, k, ISA.Name s) ] in
  match l with
  | Asm.Instr i -> code [ i ] []
  | Asm.Instr_at (i, k, t) -> code [ i ] [ (0, k, t) ]
  | Asm.Machine m ->
      ISA.Chunk (word_bytes (Int64.of_int (ISA.encode_machine m)), [])
  | Asm.Li (d, v) when small v ->
      code [ ISA.Alui (ISA.Add, d, 0, Int64.to_int v) ] []
  | Asm.Li (d, v) ->
      code [ ISA.Lui (d, half v 16); ISA.Alui (ISA.Or, d, d, half v 0) ] []
  | Asm.La (d, s) ->
      code [ ISA.Lui (d, 0); ISA.Alui (ISA.Or, d, d, 0) ]
        [ (0, ISA.Hi, ISA.Name s); (4, ISA.Lo, ISA.Name s) ]
  | Asm.Mov (d, a) -> code [ ISA.Alui (ISA.Add, d, a, 0) ] []
  | Asm.Call s -> code [ ISA.Jal (ISA.lr, 0) ] (to_ s ISA.Pc)
  | Asm.Jump s -> code [ ISA.Jal (0, 0) ] (to_ s ISA.Pc)
  | Asm.Branch (c, d, a, s) -> code [ ISA.Branch (c, d, a, 0) ] (to_ s ISA.Pc)
  | Asm.Ret -> code [ ISA.Jalr (0, ISA.lr, 0) ] []
  | Asm.Label s -> ISA.Label s
  | Asm.Align k -> ISA.Align k
  | Asm.Space k -> ISA.Space k
  | Asm.Bytes bs ->
      ISA.Chunk (String.concat "" (List.map (fun b -> String.make 1 (Char.chr b)) bs), [])
  | Asm.Ascii s -> ISA.Chunk (s, [])
  | Asm.Word v -> ISA.Chunk (word_bytes v, [])
  | Asm.Word_sym s -> ISA.Chunk (word_bytes Int64.zero, to_ s ISA.Word)
  | Asm.Piece -> ISA.Piece
  | Asm.SectionCode -> ISA.SectionCode
  | Asm.SectionData -> ISA.SectionData

(* a text line's items, a line's each, but the words of one .word line
 * one chunk *)
let rec items (ls : Asm.line list) : ISA.item list =
  match ls with
  | [] -> []
  | (Asm.Word _ | Asm.Word_sym _) :: _ ->
      let rec words ls i bytes relocs =
        match ls with
        | Asm.Word v :: r -> words r (i + 1) (bytes ^ word_bytes v) relocs
        | Asm.Word_sym s :: r ->
            words r (i + 1) (bytes ^ word_bytes Int64.zero)
              ((4 * i, ISA.Word, ISA.Name s) :: relocs)
        | r -> ISA.Chunk (bytes, List.rev relocs) :: items r in
      words ls 0 "" []
  | l :: r -> item l :: items r

(*****************************************************************************)
(* The object *)
(*****************************************************************************)

(* A file's items, in their order, for tiny-linker, marshalled
 * (TinyMachineISA's to_object): its text's lines (TinyMachineAsm's
 * parse), each line's items *)
let assemble (chan : Chan.i) : string =
  let at n e = Chan.origin chan ^ ":" ^ string_of_int (n + 1) ^ ": " ^ e in
  (* each file on a word's boundary: one may end with bytes, the next
   * begin with code *)
  let all = ref [ ISA.Align 4 ] in
  In_channel.input_all chan.ic
  |> String.split_on_char '\n'
  |> List.iteri (fun n text ->
    let its = try items (Asm.parse text) with ISA.Error e -> ISA.error (at n e) in
    all := List.rev_append its !all);
  ISA.to_object (List.rev !all)

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let assemble_to (f : Fpath.t) (out : Fpath.t) : Exit.t =
    f |> TSys.with_open_in caps assemble
      |> TSys.write_file caps out
    ;
    Exit.OK in
  (* x.tm's object: x.o, here *)
  let default f = Fpath.set_ext ".o" (Fpath.base f) in
  let tm f = Filename.check_suffix f ".tm" in
  try
    match List.tl (Array.to_list argv) with
    | ("-h" | "--help") :: _ -> TSys.print caps help; Exit.OK
    | [ "-o"; out; f ] when tm f -> assemble_to (Fpath.v f) (Fpath.v out)
    | [ f ] when tm f -> assemble_to (Fpath.v f) (default (Fpath.v f))
    | _ -> TSys.eprint caps (usage ^ "   (-h: how)\n"); Exit.Code 2
  (* (said after the program's name by TSys.main) *)
  with ISA.Error e -> Exit.Err e

let () = TSys.main "tiny-assembler" main
