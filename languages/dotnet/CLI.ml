(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

let usage = "usage: mini-dotnet [-v|-debug|-quiet] [-trace] [-s] [-jit [-tier n]] file.dll [arg...] | -S [-jit [-m 5|7 [-refs]]] | -tables | -size | -verify file.dll..."

(* a program run: its output by the console's channel, its input
 * read a byte at a time; an exception no one catches said as .NET says
 * it, the exit then 134 (.NET's abort) *)
let run (caps : < caps; .. >) (img : Image.t) (argv : string list) (tracing : bool) (stats : bool) : int =
  let out = Console.stdout caps in
  let input = Console.stdin caps in
  Library.hooks.out <- output_string out;
  Library.hooks.read <- (fun () -> flush out; match input_char input with
    | c -> Char.code c | exception End_of_file -> -1);
  if tracing then Frame.trace := Some (fun s -> flush out; Console.eprint caps (s ^ "\n"));
  Machine.install ();
  let im = Types.load img in
  let finish () =
    flush out;
    if stats then Console.eprint caps (Printf.sprintf "%d instructions\n" !Frame.steps);
    if stats && !Jit_run.compiled > 0 then
      Console.eprint caps (Printf.sprintf "%d methods compiled\n" !Jit_run.compiled) in
  match Machine.run_main im argv with
  | n -> finish (); n
  | exception Library.Exit n -> finish (); n
  | exception Frame.Stack_overflow -> finish (); Console.eprint caps "Stack overflow.\n"; 134
  | exception Frame.Unhandled (cls, msg) ->
      finish ();
      Console.eprint caps (Printf.sprintf "Unhandled exception. %s: %s\n" cls msg);
      134
  | exception (Frame.Error msg | Types.Load_error msg) ->
      finish ();
      Console.eprint caps ("mini-dotnet: " ^ msg ^ "\n");
      1

let main (caps : < caps; .. >) (argv : string array) : int =
  let mode = ref "run" in
  let files = ref [] in
  let tracing = ref false and stats = ref false and jit = ref false and mach = ref 5 and refs = ref false in
  let options =
    Logging.flags @
    [ ("-trace", Arg.Set tracing, " each instruction said as it runs, to the standard error");
      ("-s", Arg.Set stats, " the instructions run, said at the end"); ("-tables", Arg.Unit (fun () -> mode := "tables"), " the metadata's tables, a row a line");
      ("-S", Arg.Unit (fun () -> mode := "S"), " the types and their methods' IL, as ildasm");
      ("-size", Arg.Unit (fun () -> mode := "size"), " its types, methods and bytes of IL (each body decoded)");
      ("-verify", Arg.Unit (fun () -> mode := "verify"), " each method's stack typed at each instruction: those refused, and why");
      ("-jit", Arg.Set jit, " the methods the JIT takes run as the machine's code (mini-ml's build, arm64); with -S, that code as mini-asm's text, why not the others");
      ("-tier", Arg.Set_int Machine.tier, " with -jit: the calls a method is interpreted before it is compiled (30; 0: at its first; a method with a loop at its first)");
      ("-m", Arg.Set_int mach, " with -S -jit: the machine, 5 (arm, the default) or 7 (arm64)");
      ("-refs", Arg.Set refs, " with -S -jit: references too, the code -jit runs (the assembly loaded)") ] in
  match Arg.parse_argv argv options (fun (f : string) -> files := f :: !files) usage with
  | exception Arg.Help _ -> Console.print caps (usage ^ "\n"); 0
  | exception Arg.Bad msg -> Console.eprint caps msg; 1
  | () ->
      let read (f : string) : Image.t =
        let data = match FS.path f with
          | Error e -> failwith e
          | Ok p -> FS.read caps p in
        Logs.info (fun m -> m "read %s: %d bytes" f (String.length data));
        Image.read data in
      let one (f : string) : unit =
        let img = read f in
        let data = img.file in
        match !mode with
        | "tables" -> Console.print caps (Listing.tables img)
        | "S" when !jit ->
            let text, n, refused = Jit.assembly (if !mach = 7 then Jit.Arm64 else Jit.Arm) img
                (if !refs then Some (Types.load img) else None) in
            Console.print caps text;
            List.iter (fun (row, why) ->
                Console.print caps (Printf.sprintf "// not compiled: %s: %s\n"
                                      (Listing.token_name img (Metadata.token Metadata.t_method_def row)) why)) refused;
            Console.print caps (Printf.sprintf "// %s: %d methods compiled, %d not\n" (Filename.basename f) n (List.length refused))
        | "S" -> Console.print caps (Listing.listing img)
        | "size" ->
            let types, methods, il = Listing.sizes img in
            Console.print caps (Printf.sprintf "%s: %d bytes, %d types, %d methods, %d bytes of IL\n"
                                  (Filename.basename f) (String.length data) types methods il)
        | "verify" ->
            let ok, errors = Verifier.assembly img in
            List.iter (fun (row, msg) ->
                Console.print caps (Printf.sprintf "%s: %s\n"
                                      (Listing.token_name img (Metadata.token Metadata.t_method_def row)) msg)) errors;
            Console.print caps (Printf.sprintf "%s: %d methods verified, %d refused\n"
                                  (Filename.basename f) ok (List.length errors))
        | _ -> () in
      try
        if !mode = "run" then begin
          match List.rev !files with
          | [] -> Console.eprint caps (usage ^ "\n"); 1
          | f :: argv ->
              if !jit then Machine.jit := Some (Jit_run.jit caps);
              run caps (read f) argv !tracing !stats
        end
        else (List.iter one (List.rev !files); 0)
      with
      | Failure msg | Sys_error msg -> Console.eprint caps ("mini-dotnet: " ^ msg ^ "\n"); 1
      | Image.Bad_image msg -> Console.eprint caps ("mini-dotnet: not an assembly: " ^ msg ^ "\n"); 1
