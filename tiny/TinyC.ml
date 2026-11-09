(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *
 * See TinyC.mli
 *)
open TinyCTypes
open TinyCLexer
open TinyCTree
open TinyCParser
module Lower = TinyCLower
module Machine = TinyCMachine
module TSys = TinyLibSystem

let usage = "usage: tiny-c [-ir] [-o out.tm] file.c"

(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|

A tiny C compiler: a C file to TinyCPU's assembly, for tiny-cpu, with its own
libc; -ir prints its stack machine's code instead. A fact.c that includes
tiny/TinyCRuntime/libc.h and prints fact(10):
  L=tiny/TinyCRuntime; (cd $L && tiny-c -o libc.tm libc.c)
  tiny-c -o fact.tm fact.c
  for f in $L/start $L/udivmod $L/libc fact
  do tiny-assembler -o $f.o $f.tm; done
  tiny-linker -o fact $L/start.o $L/udivmod.o $L/libc.o fact.o
  tiny-cpu fact                            fact 10 = 3628800
  tiny-c -ir fact.c                        fact: param 0, load 4, imm 0, ...
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
 *     Parser.external_decl  typed as it is read (TinyCTree)
 *        | defs: a function's tree, a global's data
 *     Lower.lower_function  the tree to the stack machine
 *        | ir list
 *     Machine.machine       TinyCPU's assembly (Machine.global: data)
 *)

(* -ir: the stack machine's code instead of the machine's *)
let ir_only = ref false

let compile (d : def) =
  match d with
  | Function (f, locals, body) ->
      let code = Lower.lower_function body in
      if !ir_only then
        (Buffer.add_string Machine.out (f ^ ":\n");
         List.iter (fun i ->
           Buffer.add_string Machine.out ("\t" ^ Lower.show i ^ "\n")) code)
      else Machine.machine f locals code
  | Data (g, n, ds) -> if not !ir_only then Machine.global g n ds

(*****************************************************************************)
(* main *)
(*****************************************************************************)

(* a file that cannot be read or made, said apart from an error in one *)
exception File_error of string

let main (caps : < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. >)
    (argv : string array) : Exit.t =
  let output = ref None and file = ref None in
  let rec args l = match l with
    | "-ir" :: r -> ir_only := true; args r
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
      unit_name := Fpath.to_string (Fpath.rem_ext (Fpath.base file));
      (* intptr, Plan 9's uintptr's signed twin: an integer as wide as a
       * pointer (TinyMLRuntime/'s values, a word each) *)
      Hashtbl.replace typedefs "intptr" int_t;
      (* (a file that cannot be opened apart from its errors, which are
       * Failures too) *)
      let with_file g f =
        let opened = ref false in
        try TSys.with_open_in caps (fun ch -> opened := true; g ch) f
        with Failure m when not !opened -> raise (File_error m) in
      try
        let ts = with_file (tokens (Hashtbl.create 16) with_file) file in
        toks := Array.of_list (List.map fst ts);
        locs := Array.of_list (List.map snd ts);
        while peek () <> EOF do List.iter compile (external_decl ()) done;
        let text =
          Buffer.contents Machine.out
          ^ (if !ir_only then ""
             else "\t.data\n" ^ Buffer.contents Machine.data)
        in
        (match !output with
         | None -> TSys.print caps text
         | Some o ->
             (try
                TSys.with_open_out caps
                  (fun (ch : Chan.o) -> Out_channel.output_string ch.oc text) o
              with Failure m -> raise (File_error m)));
        Exit.OK
      with
      | Failure m ->
          (* where: the last token read (a missing ; is then on its line, not
           * the next one's), in its file (an #include's); the lexer's errors
           * have none *)
          let ls = !locs in
          if Array.length ls = 0 then
            TSys.eprint caps (Fpath.to_string file ^ ": " ^ m ^ "\n")
          else
            (let f, l = ls.(max 0 (min (!pos - 1) (Array.length ls - 1))) in
             TSys.eprint caps
               (f ^ ": line " ^ string_of_int l ^ ": " ^ m ^ "\n"));
          (* (said here, after the file, not the program's name) *)
          Exit.Code 1
      | File_error m -> Exit.Err m
  end

let () = TSys.main "tiny-c" main
