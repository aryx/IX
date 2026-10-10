(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

let usage = "usage: mini-pascal [-S] [-disk] [-seed n] [-s] file.pas...   (-h: how)"

(* -h: how, by examples, each one as it runs *)
let help = {|usage: mini-pascal [-S] [-disk] [-seed n] [-s] file.pas...
Pascal (Wirth, 1970) as Pascal-P and UCSD Pascal ran it: one pass from the text
to P-code, the code of a stack machine, and that machine. For example:
  mini-pascal hello.pas             a program compiled and run
  mini-pascal -S hello.pas          its P-code: an instruction a line, its address, its source line
  mini-pascal -disk                 the programs that come with it: HELLO.PAS, QUEENS.PAS, HANOI.PAS...
  mini-pascal QUEENS.PAS            one of them run (a name that is no file here is looked for there): the eight queens
  mini-pascal GUESS.PAS             a program that asks: readln takes the next line typed
  mini-pascal -seed 7 GUESS.PAS     random's numbers from another seed (1: the same ones every time)
The language: integer, boolean, char, subranges, arrays and records; const,
type, var; procedures and functions, nested, recursive, forward, with value and
var parameters; if, case, while, repeat, for; write, writeln, read, readln,
random. An error of the compiler is said with its line and column and nothing
is run; an error at run time (a range check, a division by zero, the stack
used up) with its number, Turbo Pascal's, and its line. The exit is then 1.
-s: the instructions the machine ran, said at the end.|}

(* a program run to its end on the console; false if it failed *)
let run (caps : < caps; .. >) (seed : int) (stats : bool) (p : Pcode.program) : bool =
  let m = Pmachine.start p in
  let chan = Console.stdin caps in
  let seed = ref (Lehmer.scramble seed) in
  let flush () : unit =
    let s = Pmachine.output m in
    if s <> "" then Console.print caps s;
    (* (seen now: a question before its line is waited for, what was
     * written before an error's message) *)
    flush (Console.stdout caps) in
  let rec go () : bool =
    let stop = Pmachine.resume ~pause:(fun (_ : Pmachine.machine) -> false) m 100_000 in
    flush ();
    match stop with
    | Pmachine.Halted -> true
    | Pmachine.Slice_over | Pmachine.Paused -> go ()
    | Pmachine.Need_line -> (
        match input_line chan with
        | l -> Pmachine.give_line m l; go ()
        | exception End_of_file -> Console.eprint caps "\nreadln: no line left\n"; false)
    | Pmachine.Need_random n ->
        (* (drawn as Talk draws them: a seed gives the same numbers here
         * and in TinyTurboPascal) *)
        seed := Lehmer.next !seed;
        Pmachine.give_random m (int_of_float (float_of_int n *. Lehmer.to_unit !seed));
        go ()
    | Pmachine.Failed (code, msg) ->
        let pc = Pmachine.pc m in
        Console.eprint caps (Printf.sprintf "\nRuntime error %d at line %d: %s\n" code (if pc > 0 then p.lines.(pc - 1) else 0) msg);
        false in
  let ok = go () in
  if stats then Console.eprint caps (Printf.sprintf "%d instructions\n" (Pmachine.executed m));
  ok

let main (caps : < caps; .. >) (argv : string array) : int =
  let listing = ref false and disk = ref false and stats = ref false and seed = ref 1 in
  let files : string list ref = ref [] in
  let options =
    [ ("-S", Arg.Set listing, " the P-code listed, nothing run");
      ("-disk", Arg.Set disk, " the names of the programs that come with it");
      ("-seed", Arg.Int (fun (n : int) -> seed := n), " random's seed (1)");
      ("-s", Arg.Set stats, " the instructions run, at the end") ] in
  (* a file here, or else one of the disk's *)
  let text (f : string) : string =
    match (match FS.path f with Ok p -> FS.read caps p | Error msg -> raise (Sys_error msg)) with
    | t -> t
    | exception Sys_error msg -> (match List.assoc_opt f Pascal_disk.files with Some t -> t | None -> failwith (msg ^ " (and not on the disk: -disk)")) in
  match Arg.parse_argv argv options (fun (f : string) -> files := f :: !files) usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); 0
  | exception Arg.Bad msg -> Console.eprint caps msg; 1
  | () -> (
      try
        if !disk then List.iter (fun ((name, _) : string * string) -> Console.print caps (name ^ "\n")) Pascal_disk.files
        else if !files = [] then failwith usage;
        let ok = ref true in
        List.iter
          (fun (f : string) ->
            match Pascal_compile.compile (text f) with
            | Error e -> Console.eprint caps (Printf.sprintf "%s:%d:%d: %s\n" f e.line e.col e.message); ok := false
            | Ok p -> if !listing then Console.print caps (Pcode.listing p) else if not (run caps !seed !stats p) then ok := false)
          (List.rev !files);
        if !ok then 0 else 1
      with Failure msg | Sys_error msg -> Console.eprint caps (msg ^ "\n"); 1)
