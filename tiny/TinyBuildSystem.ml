(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyBuildSystem.mli *)

(* -h: the usage, and a Buildfile's five kinds of lines, by example, as
 * it runs *)
let help = {|usage: tiny-build [-f Buildfile] [-j N] [-n] [-g] [target ...]
The targets out of date remade, by the rules of the Buildfile (-f: another),
N recipes at once (-j); up to date by content, not time (the stamps kept in
.tiny-build). -n: the recipes printed, not run; -g: the graph, for dot.
A Buildfile's five kinds of lines, and that is all the syntax:
  # a comment
  OBJS = hello.o world.o          a variable: a list of words
  hello: $OBJS                    a rule: targets, then prerequisites
      cc -o $target $prereq       its recipe: the lines that start with a
                                  blank, run by sh -e
  %.o: %.c                        a pattern: % is the stem
      cc -c $stem.c
  <.depend                        an include, if the file exists
tiny-build then makes hello (the first rule's target); a comment added to
world.c recompiles it, and relinks nothing: world.o came out the same.
|}

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

(* a rule's target: a name, or a pattern, the text around its % *)
type target = Exact of string | Pattern of string * string

type rule = {
  target : target;
  prereqs : string list;
  recipe : string option;
}

type node = {
  name : string;
  deps : node list;
  make : make;
}

(* a node is a source, or made by a recipe (a pattern's, with its stem) *)
(* old: recipe and stem strings, "" for none: a stem without a recipe
 * could be built, and each use re-tested recipe = "" *)
and make = Source | Recipe of { text : string; stem : string }

let target_of (s : string) =
  match String.index_opt s '%' with
  | None -> Exact s
  | Some i -> Pattern (String.sub s 0 i, String.sub s (i + 1) (String.length s - i - 1))

let show_target = function Exact s -> s | Pattern (pre, suf) -> pre ^ "%" ^ suf

exception Error of string

let error fmt = Printf.ksprintf (fun s -> raise (Error s)) fmt

(*****************************************************************************)
(* Reading a Buildfile *)
(*****************************************************************************)

let words (s : string) : string list =
  String.split_on_char ' ' (String.map (fun c -> if c = '\t' then ' ' else c) s)
  |> List.filter (( <> ) "")

(* $X and ${X}, by the value of X; an unknown X is an error, or, when
 * printing a recipe, left for the shell *)
let expand ~keep (vars : (string, string list) Hashtbl.t) (s : string) : string =
  let is_name c = c = '_' || ('a' <= c && c <= 'z') || ('A' <= c && c <= 'Z') || ('0' <= c && c <= '9') in
  let b = Buffer.create (String.length s) and n = String.length s in
  let rec go i =
    if i < n then
      if s.[i] = '$' && i + 1 < n then begin
        let braced = s.[i + 1] = '{' in
        let j = ref (if braced then i + 2 else i + 1) in
        while !j < n && is_name s.[!j] do incr j done;
        let start = if braced then i + 2 else i + 1 in
        let name = String.sub s start (!j - start) in
        let value =
          match Hashtbl.find_opt vars name with
          | Some v -> String.concat " " v
          | None when keep -> String.sub s i ((if braced then !j + 1 else !j) - i)
          | None -> error "undefined variable $%s" name
        in
        Buffer.add_string b value;
        go (if braced then !j + 1 else !j)
      end
      else (Buffer.add_char b s.[i]; go (i + 1))
  in
  go 0;
  Buffer.contents b

(* the rules, in order, and the variables; [read] gives an included
 * file's text (None: it doesn't exist yet, e.g. a generated .depend) *)
let parse ~(read : string -> string option) (text : string) :
    rule list * (string, string list) Hashtbl.t =
  let vars = Hashtbl.create 17 and rules = ref [] in
  (* a backslash-newline continues a line, as ocamldep writes them *)
  let lines text =
    let n = String.length text and b = Buffer.create (String.length text) in
    String.iteri (fun i c ->
      if c = '\\' && i + 1 < n && text.[i + 1] = '\n' then Buffer.add_char b ' '
      else if not (c = '\n' && i > 0 && text.[i - 1] = '\\') then Buffer.add_char b c) text;
    String.split_on_char '\n' (Buffer.contents b)
  in
  let is_recipe l = l <> "" && (l.[0] = '\t' || l.[0] = ' ') in
  let strip l = match String.index_opt l '#' with Some i -> String.sub l 0 i | None -> l in
  let rec go = function
    | [] -> ()
    | l :: _ when is_recipe l -> error "a recipe line with no rule: %s" l
    | l :: rest when String.length l > 1 && l.[0] = '<' ->
        let file = String.trim (expand ~keep:false vars (String.sub l 1 (String.length l - 1))) in
        Option.iter (fun text -> go (lines text)) (read file);
        go rest
    | l :: rest ->
        let l = strip l in
        let before i = words (expand ~keep:false vars (String.sub l 0 i)) in
        let after i = words (expand ~keep:false vars (String.sub l (i + 1) (String.length l - i - 1))) in
        (* whichever of = and : comes first *)
        match String.index_opt l '=', String.index_opt l ':' with
        | Some i, j when (match j with Some j -> i < j | None -> true) ->
            Hashtbl.replace vars (String.trim (String.sub l 0 i)) (after i);
            go rest
        | _, Some j ->
            let rec recipe acc = function
              | r :: rs when is_recipe r -> recipe (String.trim r :: acc) rs
              | rs -> String.concat "\n" (List.rev acc), rs
            in
            let body, rest = recipe [] rest in
            let prereqs = after j in
            let recipe = if body = "" then None else Some body in
            before j |> List.iter (fun t -> rules := { target = target_of t; prereqs; recipe } :: !rules);
            go rest
        | _ ->
            if String.trim l <> "" then error "not a rule nor a variable: %s" l;
            go rest
  in
  go (lines text);
  List.rev !rules, vars

(*****************************************************************************)
(* The graph *)
(*****************************************************************************)

(* does a target match name? the stem if so, "" for an exact one *)
let matches (t : target) (name : string) : string option =
  match t with
  | Exact s -> if s = name then Some "" else None
  | Pattern (pre, suf) ->
      let n = String.length name and np = String.length pre and ns = String.length suf in
      if np + ns <= n && String.sub name 0 np = pre && String.sub name (n - ns) ns = suf
      then Some (String.sub name np (n - np - ns)) else None

let subst stem (p : string) = String.concat stem (String.split_on_char '%' p)

(* From a target to its node: the rules naming it exactly, merged (at
 * most one with a recipe); if none has a recipe, the one pattern rule
 * whose prerequisites can all be made. *)
let graph (rules : rule list) ~(exists : string -> bool) (target : string) : node =
  let memo = Hashtbl.create 101 in
  let exact, patterns = List.partition (fun r -> match r.target with Exact _ -> true | Pattern _ -> false) rules in
  let rec node path used name =
    match Hashtbl.find_opt memo name with
    | Some n -> n
    | None ->
        if List.mem name path then
          error "cycle: %s" (String.concat " -> " (List.rev (name :: path)));
        let mine = List.filter (fun r -> r.target = Exact name) exact in
        let prereqs = List.concat_map (fun r -> r.prereqs) mine in
        let make, extra, used =
          match List.filter_map (fun (r : rule) -> r.recipe) mine with
          | [ text ] -> Recipe { text; stem = "" }, [], used
          | _ :: _ :: _ -> error "two recipes for %s" name
          | [] ->
              let candidates =
                patterns |> List.filter_map (fun r ->
                  if List.memq r used then None
                  else match matches r.target name with
                    | Some stem when List.for_all (makeable path (r :: used)) (List.map (subst stem) r.prereqs)
                      -> Some (r, stem)
                    | _ -> None)
              in
              (match candidates with
               | [] -> Source, [], used
               | [ (r, stem) ] ->
                   let make = match r.recipe with Some text -> Recipe { text; stem } | None -> Source in
                   make, List.map (subst stem) r.prereqs, r :: used
               | _ -> error "ambiguous: several patterns make %s" name)
        in
        let n = { name; make; deps = List.map (node (name :: path) used) (prereqs @ extra) } in
        if make = Source && n.deps = [] && not (exists name) then error "don't know how to make %s" name;
        Hashtbl.replace memo name n;
        n
  (* can this name be made: a file, or a target of some rule? *)
  and makeable path used name =
    exists name || List.exists (fun r -> r.target = Exact name) exact
    || List.exists (fun r ->
         not (List.memq r used) && not (List.mem name path)
         && match matches r.target name with
            | Some stem -> List.for_all (makeable (name :: path) (r :: used)) (List.map (subst stem) r.prereqs)
            | None -> false) patterns
  in
  node [] [] target

(* the nodes under [root], each once, prerequisites first *)
let order (root : node) : node list =
  let seen = Hashtbl.create 101 and out = ref [] in
  let rec go n =
    if not (Hashtbl.mem seen n.name) then begin
      Hashtbl.replace seen n.name ();
      List.iter go n.deps;
      out := n :: !out
    end
  in
  go root;
  List.rev !out

(*****************************************************************************)
(* The outside world *)
(*****************************************************************************)

let read_file caps file = if Sys.file_exists file then Some (FS.read caps (Fpath.v file)) else None

(* old: Digest's MD5 (Digest.file, Digest.string): SHA-1 is in t-ix
 * already, tiny-vcs's, and MD5 was here only *)
let digest_file (caps : < Cap.open_in; .. >) (file : string) : string option =
  if Sys.file_exists file && not (Sys.is_directory file) then Some (Sha1.to_hex (Sha1.string (FS.read caps (Fpath.v file))))
  else None

let start (caps : < Cap.fork; Cap.exec; .. >) (env : string array) (recipe : string) : int =
  match CapUnix.fork caps () with
  | 0 ->
      (try CapUnix.execve caps "/bin/sh" [| "sh"; "-e"; "-c"; recipe |] env with _ -> ());
      Unix._exit 127
  | pid -> pid

(*****************************************************************************)
(* Building *)
(*****************************************************************************)

let stampfile = ".tiny-build"

let build (caps : < Cap.fork; Cap.exec; Cap.wait; Cap.open_in; Cap.env; .. >)
    ~(vars : (string, string list) Hashtbl.t) ~(stamps : (string, string) Hashtbl.t)
    ~jobs ~dry (root : node) : bool =
  let digests = Hashtbl.create 101 in    (* the nodes done: their digest *)
  let running = Hashtbl.create 7 in      (* pid -> node *)
  let ran = ref 0 and failed = ref false in
  let env =
    Array.to_list (CapUnix.environment caps ())
    @ Hashtbl.fold (fun k v acc -> (k ^ "=" ^ String.concat " " v) :: acc) vars []
  in
  (* a source's recipe is "", as .tiny-build's stamps have it *)
  let stamp n =
    let recipe = match n.make with Source -> "" | Recipe r -> r.text in
    Sha1.to_hex (Sha1.string (String.concat "\n" (recipe :: List.map (fun d ->
      d.name ^ " " ^ Hashtbl.find digests d.name) n.deps)))
  in
  (* a node is done: its digest is its file's, or, without one, its stamp *)
  let finish n = Hashtbl.replace digests n.name
      (match digest_file caps n.name with Some d -> d | None -> stamp n) in
  let decide n =
    match n.make with
    | Source -> finish n
    | Recipe _ when digest_file caps n.name <> None && Hashtbl.find_opt stamps n.name = Some (stamp n) -> finish n
    | Recipe { text; stem } ->
      let own = [ "target", [ n.name ]; "stem", [ stem ]; "prereq", List.map (fun d -> d.name) n.deps ] in
      let shown = Hashtbl.copy vars in
      List.iter (fun (k, v) -> Hashtbl.replace shown k v) own;
      print_endline (expand ~keep:true shown text);
      incr ran;
      if dry then Hashtbl.replace digests n.name ("dry " ^ n.name)
      else
        let own = List.map (fun (k, v) -> k ^ "=" ^ String.concat " " v) own in
        Hashtbl.replace running (start caps (Array.of_list (own @ env)) text) n
  in
  let wait () =
    match Procs.wait_any caps with
    | None -> ()
    | Some (pid, st) ->
    match Hashtbl.find_opt running pid with
    | None -> ()
    | Some n ->
        Hashtbl.remove running pid;
        if st = Unix.WEXITED 0 then (Hashtbl.replace stamps n.name (stamp n); finish n)
        else (Printf.eprintf "tiny-build: %s failed\n%!" n.name; failed := true)
  in
  let rec loop todo =
    let ready n = List.for_all (fun d -> Hashtbl.mem digests d.name) n.deps in
    let rec start_ready = function
      | n :: rest when Hashtbl.length running < jobs && not !failed && ready n ->
          decide n; start_ready rest
      | n :: rest -> n :: start_ready rest
      | [] -> []
    in
    let todo = start_ready todo in
    if Hashtbl.length running > 0 then (wait (); loop todo)
    else if todo <> [] && not !failed && List.exists ready todo then loop todo
  in
  loop (order root);
  if !ran = 0 && not !failed then Printf.printf "tiny-build: %s is up to date\n" root.name;
  not !failed

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

let usage = "usage: tiny-build [-f file] [-j N] [-n] [-g] [target ...]   (-h: how)"
exception Bad of string

let run (caps : Cap.all_caps) : int =
  let file = ref "Buildfile" and jobs = ref 1 and dry = ref false and dot = ref false in
  let targets = ref [] in
  (* old: Arg.parse_argv, for these four options *)
  let bad o = raise (Bad (Printf.sprintf "tiny-build: unknown option '%s'\n%s\n" o usage)) in
  let rec options = function
    | "-f" :: f :: rest -> file := f; options rest
    | "-j" :: n :: rest -> (match int_of_string_opt n with Some n -> jobs := n | None -> bad ("-j " ^ n)); options rest
    | "-n" :: rest -> dry := true; options rest
    | "-g" :: rest -> dot := true; options rest
    | o :: _ when o <> "" && o.[0] = '-' -> bad o
    | t :: rest -> targets := !targets @ [ t ]; options rest
    | [] -> ()
  in
  options (List.tl (Array.to_list (CapSys.argv caps)));
  try
    let text = match read_file caps !file with Some s -> s | None -> error "no %s" !file in
    let rules, vars = parse ~read:(read_file caps) text in
    let targets =
      match !targets, rules with
      | [], r :: _ -> [ show_target r.target ]
      | [], [] -> error "nothing to build"
      | ts, _ -> ts
    in
    let stamps = Hashtbl.create 101 in
    Option.iter (fun s ->
      String.split_on_char '\n' s |> List.iter (fun l ->
        match String.split_on_char ' ' l with
        | [ name; st ] -> Hashtbl.replace stamps name st
        | _ -> ())) (read_file caps stampfile);
    let ok =
      List.for_all (fun t ->
        let root = graph rules ~exists:Sys.file_exists t in
        if !dot then begin
          print_endline "digraph G {";
          order root |> List.iter (fun n ->
            List.iter (fun d -> Printf.printf "  %S -> %S;\n" n.name d.name) n.deps);
          print_endline "}";
          true
        end
        else build caps ~vars ~stamps ~jobs:(max 1 !jobs) ~dry:!dry root) targets
    in
    if not !dry then FS.write caps (Fpath.v stampfile) (Hashtbl.fold (fun k v acc -> acc ^ Printf.sprintf "%s %s\n" k v) stamps "");
    if ok then 0 else 1
  with Error msg -> Printf.eprintf "tiny-build: %s\n" msg; 1

(* -h, and an unknown option said, not raised *)
let main (caps : Cap.all_caps) : int =
  match Array.to_list (CapSys.argv caps) with
  | [ _; ("-h" | "--help") ] -> Console.print caps help; 0
  | _ -> (try run caps with Bad m -> Console.eprint caps m; 2)

let () = Cap.main (fun caps -> Logging.setup caps ~name:"tiny-build"; CapStdlib.exit caps (main caps))
