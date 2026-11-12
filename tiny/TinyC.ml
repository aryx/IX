(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *
 * See TinyC.mli
 *)
open Common
module Ty = TinyCTypes
module Lexer = TinyCLexer
module Tree = TinyCTree
module Parser = TinyCParser
module Lower = TinyCLower
module Machine = TinyCMachine
module M = TinyLibMachine
module TSys = TinyLibSystem

let usage = "usage: tiny-cc [-S | -ir] [-o out.o] file.c"

(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|

A tiny C compiler: a C file to an object of TinyCPU's code, for tiny-ld
and tiny-cpu, with its own libc; -S its assembly instead, -ir its stack
machine's code, on stdout without -o. A fact.c that includes
tiny/runtime/libc.h and prints fact(10):
  L=tiny/runtime
  tiny-cc $L/libc.c; tiny-cc fact.c         libc.o, fact.o
  for f in $L/start $L/udivmod; do tiny-as $f.s; done
  tiny-ld -o fact start.o udivmod.o libc.o fact.o
  tiny-cpu fact                            fact 10 = 3628800
  tiny-cc -S fact.c                        fact: addi sp, sp, -8 ...
  tiny-cc -ir fact.c                       fact: param 0, load 4, imm 0, ...
An error names the file and the line: fact.c: line 3: expected ;
|}

(*****************************************************************************)
(* The compiler: its passes *)
(*****************************************************************************)

(* The compiler's passes, a declaration at a time (so that an error in
 * a function's lowering is said at its line):
 *
 *     the file's text      TinyCLexer.tokens (#includes, #defines)
 *        | tokens
 *     Parser.declaration    typed as it is read (TinyCTree)
 *        | defs: a function's tree, a global's data
 *     Lower.lower_function  the tree to the stack machine
 *        | ir list
 *     Machine.machine       TinyCPU's assembly (Machine.global: data)
 *)

(* [compile d]: d's assembly, the code of a function or the data of a
 * global *)
let compile (d : Tree.def) : M.line list * M.line list =
  match d with
  | Tree.Function (f, locals, body) ->
      Machine.machine f locals (Lower.lower_function body), []
  | Tree.Data (g, n, ds) -> [], Machine.global g n ds

(* -ir: a function's stack machine's code, as text; a global's nothing *)
let show_ir (d : Tree.def) : string =
  match d with
  | Tree.Function (f, _, body) ->
      String.concat ""
        ((f ^ ":\n")
         :: List.map (fun i -> "\t" ^ Lower.show i ^ "\n")
              (Lower.lower_function body))
  | Tree.Data _ -> ""

(*****************************************************************************)
(* main *)
(*****************************************************************************)

(* a file that cannot be read or made, said apart from an error in one *)
exception File_error of string

let main (caps : < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. >)
    (argv : string array) : Exit.t =
  let output = ref None and file = ref None and ir_only = ref false
  and text = ref false in
  let rec args l = match l with
    | "-ir" :: r -> ir_only := true; args r
    | "-S" :: r -> text := true; args r
    | "-o" :: o :: r -> output := Some (Fpath.v o); args r
    | f :: r -> file := Some (Fpath.v f); args r
    | [] -> ()
  in
  let argl = List.tl (Array.to_list argv) in
  if List.mem "-h" argl || List.mem "--help" argl then
    (TSys.print caps help; Exit.OK)
  else begin
    args argl;
    match !file with
    | None ->
        TSys.eprint caps (usage ^ "   (-h: how)\n"); Exit.Code 2
    | Some file ->
      Ty.unit_name := Fpath.to_string (Fpath.rem_ext (Fpath.base file));
      (* intptr, Plan 9's uintptr's signed twin: an integer as wide as a
       * pointer (runtime/'s values, a word each) *)
      Hashtbl.replace Parser.typedefs "intptr" Ty.int_t;
      (* (a file that cannot be opened apart from a Failure of g's, a
       * bug) *)
      let with_file g f =
        let opened = ref false in
        try TSys.with_open_in caps (fun ch -> opened := true; g ch) f
        with Failure m when not !opened -> raise (File_error m) in
      try
        Parser.start
          (with_file (Lexer.tokens (Hashtbl.create 16) with_file) file);
        (* the functions' lines and the globals', the last first; or
         * the stack machine's code, -ir's *)
        let code = ref [] and data = ref [] and ir = Buffer.create 4096 in
        while not (Parser.at_end ()) do
          List.iter (fun d ->
            if !ir_only then Buffer.add_string ir (show_ir d)
            else begin
              let c, dt = compile d in
              code := List.rev_append c !code;
              data := List.rev_append dt !data
            end)
            (Parser.declaration ())
        done;
        let lines = List.rev_append !code (M.SectionData :: List.rev !data) in
        (* an object (TinyLibMachine's assemble), or a text: -S's lines
         * (old: the text always, for tiny-as, which parsed it
         * back into the same lines), -ir's code *)
        let made =
          if !ir_only then Buffer.contents ir
          else if !text then String.concat "" (List.map M.print_line lines)
          else M.to_object (M.assemble lines) in
        (match !output with
         | None when !text || !ir_only -> TSys.print caps made
         | o ->
             let o =
               match o with
               | Some o -> o
               | None -> Fpath.set_ext ".o" (Fpath.base file) in
             (try
                TSys.with_open_out caps
                  (fun (ch : Chan.o) -> Out_channel.output_string ch.oc made) o
              with Failure m -> raise (File_error m)));
        Exit.OK
      with
      (* (a Failure is a bug, left uncaught. old: caught as well, the
       * library's on the text, Int64.of_string's, not told from a bug's) *)
      | Error m ->
          (* where: the last token read, in its file (an #include's); the
           * lexer's errors have none, their line in their message *)
          (match Parser.last_loc () with
           | None -> TSys.eprint caps (Fpath.to_string file ^ ": " ^ m ^ "\n")
           | Some (f, l) ->
               TSys.eprint caps
                 (f ^ ": line " ^ string_of_int l ^ ": " ^ m ^ "\n"));
          (* (said here, after the file, not the program's name) *)
          Exit.Code 1
      (* a line the compiler made that cannot be encoded (a number too
       * big for its field): the compiler's error, said with the file,
       * as tiny-as said it of the text (old) *)
      | M.Error e ->
          TSys.eprint caps (Fpath.to_string file ^ ": " ^ e ^ "\n"); Exit.Code 1
      | File_error m -> Exit.Err m
  end

let () = TSys.main "tiny-cc" main
