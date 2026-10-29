(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

type caps = < Cap.open_in; Cap.stdout; Cap.stderr >

let usage = "usage: mini-dotnet [-tables] [-S] [-size] file.dll..."

let main (caps : < caps; .. >) (argv : string array) : int =
  let mode = ref "run" in
  let files = ref [] in
  let options =
    [ ("-tables", Arg.Unit (fun () -> mode := "tables"), " the metadata's tables, a row a line");
      ("-S", Arg.Unit (fun () -> mode := "S"), " the types and their methods' IL, as ildasm");
      ("-size", Arg.Unit (fun () -> mode := "size"), " its types, methods and bytes of IL (each body decoded)") ] in
  match Arg.parse_argv argv options (fun (f : string) -> files := f :: !files) usage with
  | exception Arg.Help _ -> Console.print caps (usage ^ "\n"); 0
  | exception Arg.Bad msg -> Console.eprint caps msg; 1
  | () ->
      let one (f : string) : unit =
        let data = match FS.path f with
          | Error e -> failwith e
          | Ok p -> FS.read caps p in
        let img = Image.read data in
        match !mode with
        | "tables" -> Console.print caps (Listing.tables img)
        | "S" -> Console.print caps (Listing.listing img)
        | "size" ->
            let types, methods, il = Listing.sizes img in
            Console.print caps (Printf.sprintf "%s: %d bytes, %d types, %d methods, %d bytes of IL\n"
                                  (Filename.basename f) (String.length data) types methods il)
        | _ -> failwith "running: not yet" in
      try List.iter one (List.rev !files); 0 with
      | Failure msg | Sys_error msg -> Console.eprint caps ("mini-dotnet: " ^ msg ^ "\n"); 1
      | Image.Bad_image msg -> Console.eprint caps ("mini-dotnet: not an assembly: " ^ msg ^ "\n"); 1
