(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Ml_front.mli *)

let files : (string, string) Hashtbl.t = Hashtbl.create 64
let own : (string, unit) Hashtbl.t = Hashtbl.create 16
let interfaces : (string, string) Hashtbl.t = Hashtbl.create 16

(* (a directory, a unit its units name: homes's) *)
let wanted : (string * string, unit) Hashtbl.t = Hashtbl.create 64

(* -L's directory when it is a library in one directory (flat): the units
 * that builtins (below) go before *)
let flat_dir : string option ref = ref None

(* a library in one directory, its own Stdlib there, no units.txt:
 * tiny/TinyLibCore *)
let flat (caps : < Cap.open_in; .. >) (d : string) : bool =
  FS.read_opt caps (Fpath.v (Filename.concat d "units.txt")) = None
  && FS.read_opt caps (Fpath.v (Filename.concat d "Stdlib.mli")) <> None

let library (caps : < Cap.open_in; .. >) (d : string) : Fpath.t list =
  if flat caps d then begin
    Logs.info (fun m -> m "library: %s (one directory, no units.txt)" d);
    flat_dir := Some (FS.cleanname d);
    [ Fpath.v d ]
  end
  else
  let text =
    match FS.read_opt caps (Fpath.v (Filename.concat d "units.txt")) with
    | Some t -> Logs.info (fun m -> m "library: %s (its units.txt's directories, and commons/)" d); t
    | None ->
        (* (-L's default is lib_core of the current directory: elsewhere
         * nothing is read, and the units say only that Stdlib is
         * missing) *)
        Logs.warn (fun m -> m "-L %s: no units.txt there, no library read (-L: ix's lib_core)" d);
        "" in
  let dirs = List.filter_map (fun u -> if u = "" || u.[0] = '#' then None else Some (Filename.dirname u)) (String.split_on_char '\n' text) in
  List.map (fun x -> Fpath.v (Filename.concat d x)) (List.sort_uniq compare dirs @ [ "commons" ])

(* (a flat library's units first: what the program links, the -I's
 * only for what it lacks, as tiny/TinyLibSystem.mli's Cap from
 * lib_core/system, whose Fpath would hide TinyLibCore's) *)
let search (caps : < Cap.open_in; .. >) (lib : string) (incs : Fpath.t list) : Fpath.t list =
  if flat caps lib then library caps lib @ incs else incs @ library caps lib

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

(* What tiny-ml takes for granted, having no types: a unit's text read
 * before a flat library's .mli and .ml of that unit, on their first
 * line, so that their line numbers stay. Stdlib: what OCaml has
 * predefined (option, result) or in its Stdlib (ref, the operators that
 * are syntax in tiny-ml's parser), declared as lib_core's Stdlib.mli
 * declares them. Printf: the calls tiny-ml expands when their format is
 * written in the call (TinyML/Formats.ml), declared as lib_core's
 * Printf.mli declares them, their code a value of any type: no output
 * the analyses follow, but ksprintf's continuation called, so that a
 * function given to it is not dead. *)
let builtins : (string * (string * string)) list =
  let stdlib =
    "type 'a ref = { mutable contents : 'a } type 'a option = None | Some of 'a \
     type ('a, 'b) result = Ok of 'a | Error of 'b \
     external ( && ) : bool -> bool -> bool = \"%sequand\" \
     external ( || ) : bool -> bool -> bool = \"%sequor\" \
     external ( & ) : bool -> bool -> bool = \"%sequand\" \
     external ( or ) : bool -> bool -> bool = \"%sequor\" " in
  [ ("Stdlib", (stdlib, stdlib));
    ("Printf",
     ("val sprintf : ('a, unit, string) format -> 'a \
       val bprintf : Buffer.t -> ('a, Buffer.t, unit) format -> 'a \
       val ksprintf : (string -> 'd) -> ('a, unit, string, 'd) format4 -> 'a ",
      "external any_ : 'a -> 'b = \"%identity\" \
       let sprintf _ = any_ \"\" let bprintf _ _ = any_ () \
       let ksprintf k _ = any_ (k \"\") "));
    (* (int32, int64: OCaml's types, which mini-ml reads as Int32.t,
     * Int64.t; TinyLibCore's interfaces write them without a t, so in
     * their own unit, without these, int32 was Int32.t, Int32's own
     * unit loaded again, forever. Their .ml has its own int32.) *)
    ("Int32", ("type int32 type t = int32 ", ""));
    ("Int64", ("type int64 type t = int64 ", "")) ]

(* TinyLibCore's Stdlib.ml declares the exceptions tiny-ml needs, which
 * mini-ml predefines (Resolve's predef) and its Stdlib.mli does not:
 * read, they were the library's own Stdlib.Failure..., which a
 * program's "with Failure _" (the predefined one, by the .mli) never
 * caught, and every Failure escaped. tiny-ml matches them by name, one
 * exception: their lines left blank, so that the others' numbers stay. *)
let predefined_exns =
  [ "Match_failure"; "Assert_failure"; "Out_of_memory"; "Stack_overflow"; "Invalid_argument";
    "Failure"; "Not_found"; "Sys_error"; "End_of_file"; "Division_by_zero" ]

let without_predefined_exns (text : string) : string =
  String.split_on_char '\n' text
  |> List.map (fun (l : string) ->
         match String.split_on_char ' ' (String.trim l) with
         | "exception" :: x :: _ when List.mem x predefined_exns -> ""
         | _ -> l)
  |> String.concat "\n"

(* a unit's file in the directories: its .mli for the names, or its .ml *)
let find (caps : < Cap.open_in; Cap.readdir; .. >) (dirs : Fpath.t list) (name : string) (exts : string list) : (Fpath.t * string) option =
  let names = List.concat_map (fun ext -> [ String.uncapitalize_ascii name ^ ext; name ^ ext ]) exts in
  List.find_map
    (fun (d : Fpath.t) ->
      List.find_map
        (fun n ->
          let f = Fpath.(d / n) in
          let text (t : string) : string =
            match List.assoc_opt name builtins, !flat_dir with
            | Some (mli, ml), Some flat when FS.cleanname (Fpath.to_string d) = flat ->
                if Filename.check_suffix n ".mli" then mli ^ t
                else ml ^ (if name = "Stdlib" then without_predefined_exns t else t)
            | _ -> t in
          if listed caps d n then Option.map (fun t -> (f, text t)) (FS.read_opt caps f) else None)
        names)
    dirs

(* a tree, and the text it was parsed from: mlpp's when it rewrote it *)
let parsed (caps : < Cap.open_in; .. >) (f : string) (text : string) : (Ast.source * string, string) result =
  match parse f text with
  | Error m -> Error m
  (* (on a flat library, t-IX's: no mlpp, as tiny-ml, which leaves out
   * attributes, [@@deriving show] too: TinyShell.ml's show_cmd) *)
  | Ok tree when !flat_dir <> None -> Ok (tree, text)
  | Ok tree -> rewritten caps f text tree

(* (see Ml_front.mli; the loader's) *)
let linked : (string, string) Hashtbl.t = Hashtbl.create 64

(* how a unit's file is found: by the file that names it, the unit's
 * name, the extensions *)
type look = string -> string -> string list -> (Fpath.t * string) option

(* CLI's loader *)
let loader (caps : < Cap.open_in; Cap.readdir; .. >) (look : look) (file : Fpath.t) : Scope.loader =
 fun name ->
  let exts = [ ".mli"; ".ml" ] in
  (* (the naming unit's own directory first; but a unit a manifest says
   * linked is the file linked: tiny/TinyKernel/KGraphics.ml's KRaw is
   * host/KRaw.ml when dune links that, not the KRaw.ml beside it) *)
  let found =
    if Hashtbl.mem linked name then look (Fpath.to_string file) name exts
    else
      match find caps [ Fpath.parent file ] name exts with
      | Some x -> Some x
      | None -> look (Fpath.to_string file) name exts in
  match found with
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
let unit_ (caps : < Cap.open_in; Cap.readdir; .. >) (look : look) (file : Fpath.t) (text : string) : (string list, string) result =
  let f = Fpath.to_string file in
  let name = String.capitalize_ascii (Filename.remove_extension (Filename.basename f)) in
  Hashtbl.replace files name f;
  (* (an .ml without its .mli beside it: the unit's interface, if one is
   * found) *)
  if Filename.check_suffix f ".ml" && FS.read_opt caps (Fpath.v (f ^ "i")) = None then
    Option.iter (fun ((m, _) : Fpath.t * string) -> Hashtbl.replace interfaces f (Fpath.to_string m))
      (look f name [ ".mli" ]);
  match parsed caps f text with
  | Error m -> Error m
  | Ok (Ast.Signature _, _) -> Ok []
  | Ok (Ast.Structure items, text) -> (
      derives name items;
      try
        let items = Resolve.implementation ~implicit:true (loader caps look file) name items in
        let named = Resolve.units_named () in
        let dir = FS.cleanname (Filename.dirname f) in
        List.iter (fun (u : string) -> Hashtbl.replace wanted (dir, u) ()) named;
        ignore (Typing.unit_ name items);
        ignore (Closure_facts.unit_ f name items);
        (* (the program's own units' trees: bugs/layout.dl's) *)
        if Hashtbl.mem own name then Tree_facts.unit_ name text items;
        Ok named
      with Resolve.Error (l, m) | Typing.Error (l, m) -> Error (Printf.sprintf "%s:%d: %s" f l m))

let unread : string list ref = ref []
let homes : (string, string list) Hashtbl.t = Hashtbl.create 64
let alone : bool ref = ref false
let own_dirs : Fpath.t list ref = ref []
let components : (string, unit) Hashtbl.t = Hashtbl.create 16
let built_outside : string list ref = ref []

let program (caps : < Cap.open_in; Cap.readdir; .. >) (dirs : Fpath.t list) (paths : Fpath.t list) : string list =
  let errors = ref [] in
  let todo = Queue.create () in
  (* (a variable's type, for what is a capability) *)
  Typing.keep := true;
  (* (each unit sees the program's directories, then the library's) *)
  let program_dirs = List.sort_uniq compare (List.map Fpath.parent paths) in
  (* (a unit in none of the directories given: the project's, its
   * directory found by Module_finder and then searched after the others,
   * for what they do not have, its units the program's own) *)
  let finder = Module_finder.create caps (match paths with p :: _ -> Fpath.to_string p | [] -> ".") in
  let chosen = ref [] in
  let library = dirs in
  let dirs () = program_dirs @ !own_dirs @ library @ !chosen in
  (* (the program's own: its files' directories, unless an -I's, -own's,
   * those found in its part of the project; tiny/ and ./tiny are one
   * directory) *)
  let mine (d : string) : bool =
    let is (x : Fpath.t) = FS.cleanname (Fpath.to_string x) = d in
    List.exists is !own_dirs
    || (List.exists is !chosen && Module_finder.own finder d)
    || (List.exists is program_dirs && not (List.exists is library)) in
  (* (the generated units said once each, not built) *)
  let not_built : (string, unit) Hashtbl.t = Hashtbl.create 4 in
  (* (a manifest's: a unit's code is the file linked, or, for a unit the
   * build took from outside the project (dune's from OCaml's own
   * library: List, Hashtbl), the standard library's (-L's), else none;
   * its interface the .mli beside it, else the directories') *)
  let linked_look (name : string) (exts : string list) : (Fpath.t * string) option =
    let at =
      match Hashtbl.find_opt linked name with
      | Some f -> [ Fpath.parent (Fpath.v f) ]
      | None -> library in
    let mli =
      if List.mem ".mli" exts then find caps (at @ dirs ()) name [ ".mli" ]
      else None in
    match mli with
    | Some x -> Some x
    | None -> if List.mem ".ml" exts then find caps at name [ ".ml" ] else None in
  (* (in the project, Module_finder's: a unit no directory given has) *)
  let in_project (from : string) (name : string) (exts : string list) =
    match Module_finder.choose finder from name exts with
    | None -> None
    | Some d ->
        let d = Fpath.v d in
        if not (List.mem d !chosen) then chosen := !chosen @ [ d ];
        find caps [ d ] name exts in
  let look (from : string) (name : string) (exts : string list) : (Fpath.t * string) option =
    if Hashtbl.length linked > 0 then
      (* (a unit the link did not take, named for its types alone,
       * troff's Rgba_image: its interface found in the project) *)
      match linked_look name exts with
      | Some x -> Some x
      | None when Hashtbl.mem linked name -> None
      | None -> in_project from name exts
    else
    match find caps (dirs ()) name exts with
    | Some x -> Some x
    (* (a unit the directories know otherwise, by its .mli alone, has no
     * other code: TinyLibCore's Cap, lib_core/parallel's Parallel) *)
    | None when find caps (dirs ()) name [ ".mli"; ".ml" ] <> None -> None
    | None -> (
      (* (a unit the build makes from a .mll or .mly in the program's
       * directories: where dune put it, else said, never another
       * directory's of its name) *)
      match List.find_map (fun (d : Fpath.t) -> Module_finder.generated caps finder (Fpath.to_string d) name)
              (program_dirs @ !own_dirs) with
      | Some (Some b) ->
          let d = Fpath.v b in
          if not (List.mem d !chosen) then chosen := !chosen @ [ d ];
          find caps [ d ] name exts
      | Some None ->
          if not (Hashtbl.mem not_built name) then begin
            Hashtbl.replace not_built name ();
            Logs.warn (fun m ->
                m "unit %s (named in %s): made by the build from a .mll or .mly, not found: build it (dune build), or -I where the build put it"
                  name from)
          end;
          None
      | None -> in_project from name exts) in
  (* (a unit's code: a file given, or an .ml found; asked as a unit's
   * calls are made, before the units it names are found) *)
  let bodies = Hashtbl.create 16 in
  (* (a manifest's library unit whose code cannot be read is its
   * interface alone, an external, decided before its callers are read:
   * its file does not parse, mini-ml's dialect (TinyMachineSDL's
   * polymorphic variants), or names a unit that has no file, code or
   * interface (lib_core's Parallel on OCaml 5's Domain); else the
   * functions given to it would look never called) *)
  let readable (file : Fpath.t) (text : string) : bool =
    let f = Fpath.to_string file in
    match parse f text with
    | Error m ->
        Logs.warn (fun l -> l "%s: its interface alone (its code not read: %s)" f m);
        false
    | Ok _ ->
        let local = Hashtbl.create 8 in
        String.split_on_char '\n' text
        |> List.iter (fun (l : string) ->
               match String.split_on_char ' ' (String.trim l) with
               | "module" :: m :: _ -> Hashtbl.replace local m ()
               | _ -> ());
        let missing =
          Hashtbl.fold (fun (n : string) () acc ->
              if Hashtbl.mem local n || List.mem_assoc n builtins
                 || look f n [ ".mli"; ".ml" ] <> None then acc
              else n :: acc)
            (Module_finder.names text) [] in
        if missing <> [] then
          Logs.warn (fun l ->
              l "%s: its interface alone (it names %s, which has no file)" f
                (String.concat ", " (List.sort compare missing)));
        missing = [] in
  Closure_facts.has_body :=
    (fun (u : string) ->
      match Hashtbl.find_opt bodies u with
      | Some b -> b
      | None ->
          let b =
            Hashtbl.mem own u
            || (match look "" u [ ".ml" ] with
                | None -> false
                | Some (file, text) -> Hashtbl.length linked = 0 || readable file text) in
          Hashtbl.replace bodies u b;
          (* (its interface alone: what its code builds, the constructors
           * of its types, built outside: TinyMachineSDL.ml's events) *)
          if not b && Hashtbl.length linked > 0 then
            Option.iter (fun ((m, text) : Fpath.t * string) ->
                match parse (Fpath.to_string m) text with
                | Ok (Ast.Signature items) ->
                    List.iter (fun (i : Ast.sig_item) ->
                        match i.s with
                        | Ast.Stype ds ->
                            List.iter (fun (d : Ast.type_decl) ->
                                match d.tkind with
                                | Ast.Variant cs ->
                                    List.iter (fun ((c, args) : string * Ast.ty list) ->
                                        List.iteri (fun k _ ->
                                            built_outside := Printf.sprintf "con:%s.%d" c k :: !built_outside)
                                          args)
                                      cs
                                | _ -> ())
                              ds
                        | _ -> ())
                      items
                | _ -> ())
              (look "" u [ ".mli" ]);
          b);
  let read (file : Fpath.t) (text : string) (mine : bool) =
    Module_finder.mentions finder text;
    match unit_ caps look file text with
    | Ok named -> List.iter (fun u -> Queue.add (u, Fpath.to_string file) todo) named
    | Error m -> if mine then errors := m :: !errors else unread := m :: !unread in
  List.iter
    (fun (p : Fpath.t) ->
      Hashtbl.replace own (String.capitalize_ascii (Filename.remove_extension (Filename.basename (Fpath.to_string p)))) ();
      match FS.read_opt caps p with
      | Some text -> Logs.info (fun m -> m "reading %s (a file given)" (Fpath.to_string p)); read p text true
      | None -> errors := ("cannot open " ^ Fpath.to_string p) :: !errors)
    paths;
  (* (-v: where a unit's file was found, and so whether it is the
   * program's own) *)
  let whence (d : string) : string =
    let is (x : Fpath.t) = FS.cleanname (Fpath.to_string x) = d in
    if List.exists is !own_dirs then "-own"
    else if List.exists is program_dirs && not (List.exists is library) then "the program's directory"
    else if List.exists is library then "-L or -I"
    else if Module_finder.own finder d then "found in the project, the program's part"
    else "found in the project, outside the program's part: a library" in
  while not !alone && not (Queue.is_empty todo) do
    let u, from = Queue.pop todo in
    if not (Hashtbl.mem files u) then begin
      Hashtbl.replace files u "";
      match look from u [ ".ml" ] with
      (* (a unit whose code cannot be read, its interface alone: a
       * library's, or of the program's part, -own's; a file given is
       * read before, not here) *)
      | Some _ when not (!Closure_facts.has_body u) -> ()
      | Some (f, text) when mine (FS.cleanname (Fpath.to_string (Fpath.parent f))) ->
          (* (a unit of the program's: as a file given, marked before it
           * is read for Tree_facts) *)
          Hashtbl.replace own u ();
          Logs.info (fun m -> m "reading %s (%s)" (Fpath.to_string f) (whence (FS.cleanname (Fpath.to_string (Fpath.parent f)))));
          read f text true
      | Some (f, text) ->
          Logs.info (fun m -> m "the library's %s (%s)" (Fpath.to_string f) (whence (FS.cleanname (Fpath.to_string (Fpath.parent f)))));
          read f text false
      | None -> Logs.info (fun m -> m "no code for %s (named in %s): its interface alone" u from)
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
            (dirs ()) in
        (* (one file by two names, lib_crypto/../lib_crypto: once) *)
        let found = List.map FS.cleanname found in
        Hashtbl.replace homes u
          (List.sort_uniq compare
             (List.filter (fun (f : string) -> Hashtbl.mem wanted (Filename.dirname f, u)) found))
      end)
    files;
  List.rev !errors
