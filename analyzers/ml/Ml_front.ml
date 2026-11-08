(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Ml_front.mli *)

let files : (string, string) Hashtbl.t = Hashtbl.create 64
let own : (string, unit) Hashtbl.t = Hashtbl.create 16

(* (a directory, a unit its units name: homes's) *)
let wanted : (string * string, unit) Hashtbl.t = Hashtbl.create 64

let library (caps : < Cap.open_in; .. >) (d : string) : Fpath.t list =
  let text = match FS.read_opt caps (Fpath.v (Filename.concat d "units.txt")) with Some t -> t | None -> "" in
  let dirs = List.filter_map (fun u -> if u = "" || u.[0] = '#' then None else Some (Filename.dirname u)) (String.split_on_char '\n' text) in
  List.map (fun x -> Fpath.v (Filename.concat d x)) (List.sort_uniq compare dirs @ [ "commons" ])

(* CLI's parse_text *)
let parse (file : string) (text : string) : (Ast.source, string) result =
  let lexbuf = Lexing.from_string text in
  lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = file };
  let where () = Printf.sprintf "%s:%d" file lexbuf.lex_curr_p.pos_lnum in
  try
    if Filename.check_suffix file ".mli" then Ok (Ast.Signature (Parser.interface Lexer.token lexbuf))
    else Ok (Ast.Structure (Parser.implementation Lexer.token lexbuf))
  with
  | Parser.Error | Parsing.Parse_error -> Error (where () ^ ": syntax error")
  | Lexer.Error m -> Error (where () ^ ": " ^ m)

(* mlpp: a .ml's type t = [%mli] and the like rewritten, as CLI's parse does *)
let rewritten (caps : < Cap.open_in; .. >) (file : string) (text : string) (tree : Ast.source) : (Ast.source * string, string) result =
  let mli () =
    let f = Filename.remove_extension file ^ ".mli" in
    let rec decls (s : Ast.signature) =
      List.concat_map (fun (i : Ast.sig_item) -> match i.s with Stype ds -> ds | Smodule (_, MTsig s) -> decls s | _ -> []) s in
    match FS.read_opt caps (Fpath.v f) with
    | None -> None
    | Some mli_text -> (
        match parse f mli_text with
        | Ok (Ast.Signature s) -> Some { Pp.mli_file = f; mli_text; mli_decls = decls s }
        | _ -> None) in
  match Pp.file ~file text tree ~mli with
  | exception Pp.Error (l, m) -> Error (Printf.sprintf "%s:%d: %s" file l m)
  | text' when text' == text -> Ok (tree, text)
  | text' -> Result.map (fun t -> (t, text')) (parse file text')

(* A directory's files, read once. A name is looked up in them rather than
 * opened: on a case-insensitive file system (macOS's) fS.mli opens Fs.mli,
 * another unit than FS, and png.ml opens Png.ml, the one file twice. *)
let listings : (string, (string, unit) Hashtbl.t) Hashtbl.t = Hashtbl.create 64

let listed (_ : < Cap.readdir; .. >) (d : Fpath.t) (n : string) : bool =
  let d = Fpath.to_string d in
  let names =
    match Hashtbl.find_opt listings d with
    | Some names -> names
    | None ->
        let names = Hashtbl.create 64 in
        (try Array.iter (fun (n : string) -> Hashtbl.replace names n ()) (Sys.readdir d) with Sys_error _ -> ());
        Hashtbl.replace listings d names;
        names in
  Hashtbl.mem names n

(* a unit's file in the directories: its .mli for the names, or its .ml *)
let find (caps : < Cap.open_in; Cap.readdir; .. >) (dirs : Fpath.t list) (name : string) (exts : string list) : (Fpath.t * string) option =
  let names = List.concat_map (fun ext -> [ String.uncapitalize_ascii name ^ ext; name ^ ext ]) exts in
  List.find_map
    (fun (d : Fpath.t) ->
      List.find_map
        (fun n ->
          let f = Fpath.(d / n) in
          if listed caps d n then Option.map (fun t -> (f, t)) (FS.read_opt caps f) else None)
        names)
    dirs

(* a tree, and the text it was parsed from: mlpp's when it rewrote it *)
let parsed (caps : < Cap.open_in; .. >) (f : string) (text : string) : (Ast.source * string, string) result =
  match parse f text with
  | Error m -> Error m
  | Ok tree -> rewritten caps f text tree

(* CLI's loader *)
let loader (caps : < Cap.open_in; Cap.readdir; .. >) (dirs : Fpath.t list) : Scope.loader =
 fun name ->
  match find caps dirs name [ ".mli"; ".ml" ] with
  | None -> None
  | Some (f, text) -> (match parsed caps (Fpath.to_string f) text with Ok (src, _) -> Some src | Error m -> raise (Resolve.Error (0, m)))

(* the printers [@@deriving show] makes, "Unit.show_x" and "Unit.pp_x"
 * (show and pp for a t), for each type of a group the attribute
 * follows: the deriver's code, not the author's (Dead_report leaves
 * them out) *)
let derived : (string, unit) Hashtbl.t = Hashtbl.create 64

let derives (name : string) (items : Ast.item list) : unit =
  List.iter (fun (i : Ast.item) ->
      match i.i with
      | Itype ds
        when List.exists (fun (d : Ast.type_decl) ->
                 List.exists (fun (a : Ast.attribute) -> a.aname = "deriving" && List.mem "show" a.aargs) d.tattrs) ds ->
          List.iter (fun (d : Ast.type_decl) ->
              let x = if d.tname = "t" then "" else "_" ^ d.tname in
              Hashtbl.replace derived (name ^ ".show" ^ x) ();
              Hashtbl.replace derived (name ^ ".pp" ^ x) ())
            ds
      | _ -> ())
    items

(* one unit: its facts made; the units it names *)
let unit_ (caps : < Cap.open_in; Cap.readdir; .. >) (dirs : Fpath.t list) (file : Fpath.t) (text : string) : (string list, string) result =
  let f = Fpath.to_string file in
  let name = String.capitalize_ascii (Filename.remove_extension (Filename.basename f)) in
  Hashtbl.replace files name f;
  match parsed caps f text with
  | Error m -> Error m
  | Ok (Ast.Signature _, _) -> Ok []
  | Ok (Ast.Structure items, text) -> (
      derives name items;
      try
        let items = Resolve.implementation ~implicit:true (loader caps (Fpath.parent file :: dirs)) name items in
        let named = Resolve.units_named () in
        let dir = FS.cleanname (Filename.dirname f) in
        List.iter (fun (u : string) -> Hashtbl.replace wanted (dir, u) ()) named;
        ignore (Typing.unit_ name items);
        ignore (Closure_facts.unit_ name items);
        (* (the program's own units' trees: bugs/layout.dl's) *)
        if Hashtbl.mem own name then Tree_facts.unit_ name text items;
        Ok named
      with Resolve.Error (l, m) | Typing.Error (l, m) -> Error (Printf.sprintf "%s:%d: %s" f l m))

let unread : string list ref = ref []
let homes : (string, string list) Hashtbl.t = Hashtbl.create 64
let alone : bool ref = ref false

let program (caps : < Cap.open_in; Cap.readdir; .. >) (dirs : Fpath.t list) (paths : Fpath.t list) : string list =
  let errors = ref [] in
  let todo = Queue.create () in
  (* (a variable's type, for what is a capability) *)
  Typing.keep := true;
  (* (each unit sees the program's directories, then the library's) *)
  let program_dirs = List.sort_uniq compare (List.map Fpath.parent paths) in
  let dirs = program_dirs @ dirs in
  let read (file : Fpath.t) (text : string) (mine : bool) =
    match unit_ caps dirs file text with
    | Ok named -> List.iter (fun u -> Queue.add u todo) named
    | Error m -> if mine then errors := m :: !errors else unread := m :: !unread in
  List.iter
    (fun (p : Fpath.t) ->
      Hashtbl.replace own (String.capitalize_ascii (Filename.remove_extension (Filename.basename (Fpath.to_string p)))) ();
      match FS.read_opt caps p with
      | Some text -> read p text true
      | None -> errors := ("cannot open " ^ Fpath.to_string p) :: !errors)
    paths;
  while not !alone && not (Queue.is_empty todo) do
    let u = Queue.pop todo in
    if not (Hashtbl.mem files u) then begin
      Hashtbl.replace files u "";
      match find caps dirs u [ ".ml" ] with
      | Some (f, text) -> Logs.info (fun m -> m "the library's %s" (Fpath.to_string f)); read f text false
      | None -> ()
    end
  done;
  (* (a file of the name in a directory whose units name it: the unit
   * those units link; one in an -I's that only gives interfaces, or
   * whose units do not name it, is not linked) *)
  Hashtbl.iter
    (fun (u : string) (f : string) ->
      if f <> "" then begin
        let names =
          List.sort_uniq compare [ String.uncapitalize_ascii u ^ ".ml"; u ^ ".ml" ] in
        let found =
          List.concat_map
            (fun (d : Fpath.t) ->
              List.filter_map
                (fun (n : string) ->
                  if listed caps d n then Some (Fpath.to_string Fpath.(d / n)) else None)
                names)
            dirs in
        (* (one file by two names, lib_crypto/../lib_crypto: once) *)
        let found = List.map FS.cleanname found in
        Hashtbl.replace homes u
          (List.sort_uniq compare
             (List.filter (fun (f : string) -> Hashtbl.mem wanted (Filename.dirname f, u)) found))
      end)
    files;
  List.rev !errors
