(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

type caps = < Cap.open_in; Cap.open_out; Cap.readdir; Cap.env; Cap.chdir; Cap.stdin; Cap.stdout; Cap.stderr >

let usage = "usage: mini-dotnet [-v|-debug|-quiet] [-trace] [-s] [-jit [-tier n]] file.dll [arg...] | -S [-jit [-m 5|7 [-refs]]] | -tables | -size | -verify file.dll..."

(* a Stream that cannot seek: the console's *)
let unseekable () : 'a =
  ignore (Library.hooks.throw "System.NotSupportedException" "Stream does not support seeking.");
  assert false

(* the system's error .NET's IOException (a write to a file opened to
 * read...) *)
let io (f : unit -> 'a) : 'a =
  match f () with
  | x -> x
  | exception Unix.Unix_error (e, _, _) ->
      ignore (Library.hooks.throw "System.IO.IOException" (Unix.error_message e)); assert false

(* a file's Stream: its descriptor's bytes *)
let file_stream (fd : Unix.file_descr) : Value.stream =
  let rec write (b : Bytes.t) (off : int) (n : int) : unit =
    if n > 0 then (let k = io (fun () -> Unix.write fd b off n) in write b (off + k) (n - k)) in
  { sread = (fun b off n -> io (fun () -> Unix.read fd b off n)); swrite = write; sflush = (fun () -> ());
    sclose = (fun () -> io (fun () -> Unix.close fd));
    sposition = (fun () -> io (fun () -> Unix.lseek fd 0 Unix.SEEK_CUR));
    sseek = (fun (p : int) -> io (fun () -> ignore (Unix.lseek fd p Unix.SEEK_SET)));
    slength = (fun () -> io (fun () -> (Unix.fstat fd).st_size)) }

(* File's OpenRead, OpenWrite (made when it is not there, else written
 * as it is), Create (made or emptied); Exists *)
let open_file (caps : < caps; .. >) (how : string) (f : string) : Value.stream option =
  let exists () = match FS.open_in_fd caps f with fd -> Unix.close fd; true | exception Unix.Unix_error _ -> false in
  match how with
  | "Exists" -> if exists () then Some (file_stream Unix.stdin) else None
  | _ -> (
      match
        (match how with
         | "OpenRead" -> FS.open_in_fd caps f
         | "OpenWrite" when exists () -> FS.open_device_fd caps f
         | _ -> FS.open_out_fd caps f 0o666)
      with
      | fd -> Some (file_stream fd)
      | exception Unix.Unix_error _ -> None)

(* a path's kind: 0 nothing, 1 a file, 2 a directory *)
let kind (_caps : < Cap.open_in; .. >) (f : string) : int =
  (* nosemgrep: use-caps *)
  match (Unix.stat f).st_kind with Unix.S_DIR -> 2 | _ -> 1 | exception Unix.Unix_error _ -> 0

let rename (_caps : < Cap.open_out; .. >) (a : string) (b : string) : bool =
  (* nosemgrep: use-caps *)
  match Sys.rename a b with () -> true | exception Sys_error _ -> false

(* (sorted: .NET's order is the system's, which may differ) *)
let entries (_caps : < Cap.readdir; .. >) (f : string) : string list option =
  (* nosemgrep: use-caps *)
  match Sys.readdir f with a -> Some (List.sort compare (Array.to_list a)) | exception Sys_error _ -> None

(* Library's system: each access by its capability; the clock the
 * milliseconds since the program started *)
let os (caps : < caps; .. >) (argv : string list) : Library.os =
  let start = Unix.gettimeofday () in
  { argv;
    getenv = (fun (v : string) -> match CapSys.getenv caps v with s -> Some s | exception Not_found -> None);
    kind = kind caps;
    remove = (fun (f : string) -> match FS.remove_any caps f with () -> true | exception Unix.Unix_error _ -> false);
    rename = rename caps;
    mkdir = (fun (f : string) -> match FS.mkdir caps f 0o777 with () -> true | exception Unix.Unix_error _ -> false);
    entries = entries caps;
    cwd = (fun () -> FS.getcwd caps ());
    chdir = (fun (f : string) -> match CapUnix.chdir caps f with () -> true | exception Unix.Unix_error _ -> false);
    ticks = (fun () -> int_of_float ((Unix.gettimeofday () -. start) *. 1000.)) }

(* a program run: its output by the console's channel, its input
 * read a byte at a time; an exception no one catches said as .NET says
 * it, the exit then 134 (.NET's abort). The standard streams over the
 * same channels, so that Console.Write's and theirs come in order *)
let run (caps : < caps; .. >) (path : string) (img : Image.t) (argv : string list) (tracing : bool) (stats : bool) : int =
  let out = Console.stdout caps in
  let ic = Console.stdin caps in
  let err = Console.stderr caps in
  Library.hooks.out <- output_string out;
  Library.hooks.read <- (fun () -> flush out; match input_char ic with
    | c -> Char.code c | exception End_of_file -> -1);
  let std (fd : int) : Value.stream =
    let oc = if fd = 2 then err else out in
    { sread = (fun b off n -> if fd = 0 then (flush out; input ic b off n) else 0);
      swrite = (fun b off n -> if fd <> 0 then output oc b off n);
      sflush = (fun () -> if fd <> 0 then flush oc);
      sclose = (fun () -> ()); sposition = unseekable; sseek = (fun (_ : int) -> unseekable ()); slength = unseekable } in
  Library.hooks.std <- std;
  Library.hooks.file <- open_file caps;
  Library.hooks.os <- os caps (path :: argv);
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
              if !jit && not Code_memory.available then
                Logs.warn (fun m -> m "-jit ignored: this build has no JIT\n\
                                       (mini-ml's on arm64 has: _mk/7/languages/dotnet/mini-dotnet)");
              if !jit then Machine.jit := Some (Jit_run.jit caps);
              run caps f (read f) argv !tracing !stats
        end
        else (List.iter one (List.rev !files); 0)
      with
      | Failure msg | Sys_error msg -> Console.eprint caps ("mini-dotnet: " ^ msg ^ "\n"); 1
      | Image.Bad_image msg -> Console.eprint caps ("mini-dotnet: not an assembly: " ^ msg ^ "\n"); 1
