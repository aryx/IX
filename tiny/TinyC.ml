(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyC.mli *)

open TinyCTypes
open TinyCLexer
open TinyCTree
open TinyCLower
open TinyCParser
open TinyCMachine

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
(* The file: globals and functions *)
(*****************************************************************************)

(* -ir: the stack machine's code instead of the machine's *)
let ir_only = ref false

let asm_name storage name = if storage = Static then name ^ "<>" else name

(* a global's init_data, as DATA at offsets *)
let rec init_data name t off =
  match t, peek () with
  | Arr (e, _), P "{" ->
      ignore (next ());
      (* the elements, counted *)
      let rec elems i =
        if accept "}" then i
        else
          (ignore (init_data name e (off + (i * size e)));
           ignore (accept ",");
           elems (i + 1)) in
      elems 0
  | Arr (Int (1, _), n), Str s ->
      ignore (next ());
      String.iteri (fun i c ->
        datum name (off + i) (Value (1, Int64.of_int (Char.code c)))) s;
      max n (String.length s + 1)
  | _ ->
      let e = rv (assign_expr ()) in
      (match e.d, e.t with
       | Const v, _ -> datum name off (Value (size t, v))
       | Addr (Global s), _ -> datum name off (Address s)
       | _ -> error (name ^ ": not a constant init_data"));
      1

let external_decl () =
  let storage, bt = base_type () in
  let rec go () =
    let name, t, pnames = declarator3 bt in
    if storage <> Typedef then no_vlong t;
    match t with
    | Func (rt, ps, _) when storage <> Typedef && peek () = P "{" ->
        (* a definition *)
        Hashtbl.replace globals name
          { vty = t; where = Global (asm_name storage name) };
        ignore (next ());
        let params = List.combine pnames ps in
        scopes := [ Hashtbl.create 8 ];
        List.iteri (fun i (p, pt) ->
          Hashtbl.replace (List.hd !scopes) p
            { vty = pt; where = Param (8 * i) }) params;
        frame := 0;
        result := rt;
        let body = block () in
        code := [];
        lower { brk = None; cont = None; cases = ref [] } body;
        if !ir_only then
          (Buffer.add_string out (name ^ ":\n");
           List.iter (fun i -> Buffer.add_string out ("\t" ^ show i ^ "\n"))
             (List.rev !code))
        else machine (asm_name storage name) (round !frame 8) (List.rev !code);
        scopes := []
    | _ ->
        let sym = asm_name storage name in
        (match storage, t with
         | Typedef, _ -> Hashtbl.replace typedefs name t
         | _, Func _ ->
             Hashtbl.replace globals name { vty = t; where = Global sym }
         | _ ->
             let t =
               if accept "=" then
                 (match t with
                  | Arr (e, 0) -> let n = init_data sym t 0 in Arr (e, n)
                  | _ -> ignore (init_data sym t 0); t)
               else t in
             Hashtbl.replace globals name { vty = t; where = Global sym };
             if storage <> Extern then globl sym (size t));
        if accept "," then go () else expect ";"
  in
  if not (accept ";") then go ()

(* a file that cannot be read or made, said apart from an error in one *)
exception File_error of string

let main
    (caps : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. >)
    =
  let output = ref "" and file = ref "" in
  let rec args l = match l with
    | "-ir" :: r -> ir_only := true; args r
    | "-o" :: o :: r -> output := o; args r
    | f :: r -> file := f; args r
    | [] -> ()
  in
  let argl = List.tl (TinyLibSystem.argv caps) in
  if List.mem "-h" argl || List.mem "--help" argl then
    (TinyLibSystem.print caps help; 0)
  else begin
    args argl;
    if !file = "" then (TinyLibSystem.eprint caps (usage ^ "   (-h: how)\n"); 2)
    else begin
      unit_name := Filename.remove_extension (Filename.basename !file);
      (* intptr, Plan 9's uintptr's signed twin: an integer as wide as a
       * pointer (TinyMLRuntime/'s values, a word each) *)
      Hashtbl.replace typedefs "intptr" int_t;
      let read f =
        try TinyLibSystem.read_file caps f
        with Failure m -> raise (File_error m) in
      try
        let ts = tokens (Hashtbl.create 16) read !file in
        toks := Array.of_list (List.map fst ts);
        locs := Array.of_list (List.map snd ts);
        while peek () <> EOF do external_decl () done;
        let text =
          Buffer.contents out
          ^ (if !ir_only then "" else "\t.data\n" ^ Buffer.contents data)
        in
        if !output = "" then TinyLibSystem.print caps text
        else begin
          let fd =
            try TinyLibSystem.open_out caps !output
            with Failure m -> raise (File_error m) in
          TinyLibSystem.write fd text; TinyLibSystem.close fd
        end;
        0
      with
      | Failure m ->
          (* where: the last token read (a missing ; is then on its line, not
           * the next one's), in its file (an #include's); the lexer's errors
           * have none *)
          let ls = !locs in
          if Array.length ls = 0 then
            TinyLibSystem.eprint caps (!file ^ ": " ^ m ^ "\n")
          else
            (let f, l = ls.(max 0 (min (!pos - 1) (Array.length ls - 1))) in
             TinyLibSystem.eprint caps
               (f ^ ": line " ^ string_of_int l ^ ": " ^ m ^ "\n"));
          1
      | File_error m ->
          TinyLibSystem.eprint caps (Printf.sprintf "tiny-c: %s\n" m); 1
    end
  end

let () = TinyLibSystem.main "tiny-c" main
