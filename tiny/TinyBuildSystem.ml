(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *
 * See TinyBuildSystem.mli
 *)
open Common
module TSys = TinyLibSystem

let usage =
  "usage: tiny-build [-f Buildfile] [-j N] [-n] [-g] [-t] [NAME=value ...] [target ...]"

(* -h: the usage, and a Buildfile's five kinds of lines, by example *)
let help = usage ^ {|

The targets out of date remade, by the rules of the Buildfile (-f: another),
N recipes at once (-j); up to date by content, not time (the stamps kept in
.tiny-build). -n: the recipes printed, not run; -g: the graph, for dot;
-t: each recipe's time as it ends, then the times by kind of target (bin/*,
ml/*.s), and what was not a recipe's (the digests, the graph); with -j,
the recipes' sum and how many ran at once on average.
A NAME=value is that variable's value, over the Buildfile's (mk's): tiny-build
TINY=tiny- on the host, where the tools are tiny-ml, tiny-cc..., for a
Buildfile that says ${TINY}ml.

A Buildfile's five kinds of lines, and that is all the syntax:
  # a comment
  OBJS = hello.o world.o          a variable: a list of words
  SRCS = ${OBJS:%.o=%.c}          its words changed by a pattern, in a
                                  variable's or a rule's line (mk's)
  hello: $OBJS                    a rule: targets, then prerequisites
      cc -o $target $prereq       its recipe: the lines that start with a
                                  blank, run by rc -e
  %.o: %.c                        a pattern: % is the stem
      cc -c $stem.c
  lib/&.o: lib/&.c                & a stem with no / or ., one directory's
  <.depend                        an include, if the file exists

tiny-build then makes hello (the first rule's target); a comment added to
world.c recompiles it, and relinks nothing: world.o came out the same.
|}

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

(* a rule's target: a name, or a pattern, the text around its % or its
 * & (mk's: a stem with no / or ., so x.o in one directory, not y/x.o;
 * why both, the .mli's kept:) *)
type target = Exact of string | Pattern of string * string | Amp of string * string

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
and make = Source | Recipe of step
and step = { text : string; stem : string }

(* the Buildfile's variables, each with its words *)
type vars = (string, string list) Hashtbl.t

(* the last build's stamps (.tiny-build's), by node's name: a node, not
 * a file, so the target 'all' has one too *)
type stamps = (string, Sha1.t) Hashtbl.t

let target_of (s : string) : target =
  let around i = (String.sub s 0 i, String.sub s (i + 1) (String.length s - i - 1)) in
  match String.index_opt s '%', String.index_opt s '&' with
  | Some i, _ -> let pre, suf = around i in Pattern (pre, suf)
  | None, Some i -> let pre, suf = around i in Amp (pre, suf)
  | None, None -> Exact s

let show_target = function
  | Exact s -> s
  | Pattern (pre, suf) -> pre ^ "%" ^ suf
  | Amp (pre, suf) -> pre ^ "&" ^ suf


type caps =
  < Cap.forkew; Cap.env; Cap.open_in; Cap.open_out;
    Cap.readdir; Cap.clock; Cap.stdout; Cap.stderr >

(*****************************************************************************)
(* Reading a Buildfile *)
(*****************************************************************************)

let words (s : string) : string list =
  String.split_on_char ' ' (String.map (fun c -> if c = '\t' then ' ' else c) s)
  |> List.filter (( <> ) "")

(* [subst_word from to w]: mk's ${X:from=to} on a word: from's % matches any
 * part of w, the stem, which to's % gives back (TinyLibCore/%.tmi
 * from Stdlib); a word that does not match stays as it is *)
let subst_word (from : string) (to_ : string) (w : string) : string =
  match String.index_opt from '%' with
  | None -> error ("${...:" ^ from ^ "=...}: no % in the pattern")
  | Some k ->
      let pre = String.sub from 0 k
      and post = String.sub from (k + 1) (String.length from - k - 1) in
      let n = String.length w and lp = String.length pre
      and ls = String.length post in
      if n >= lp + ls && String.sub w 0 lp = pre
         && String.sub w (n - ls) ls = post
      then
        let stem = String.sub w lp (n - lp - ls) in
        String.concat stem (String.split_on_char '%' to_)
      else w

(* $X and ${X}, by the value of X, and ${X:from=to}, X's words each
 * changed by the pattern (subst_word), in a variable's line or a rule's;
 * an unknown X is an error, or, when printing a recipe (keep), left for
 * the shell, as a substitution is (old: ~keep and the other labels:
 * tiny-ml reads none) *)
let expand keep (vars : vars) (s : string) : string =
  let is_name c =
    c = '_' || ('a' <= c && c <= 'z') || ('A' <= c && c <= 'Z')
    || ('0' <= c && c <= '9')
  in
  let b = Buffer.create (String.length s) and n = String.length s in
  let rec go i =
    if i < n then
      if s.[i] = '$' && i + 1 < n then begin
        let braced = s.[i + 1] = '{' in
        let j = ref (if braced then i + 2 else i + 1) in
        while !j < n && is_name s.[!j] do incr j done;
        let start = if braced then i + 2 else i + 1 in
        let name = String.sub s start (!j - start) in
        (* ${X:from=to}: the pattern, up to the closing brace *)
        let pattern, close =
          if braced && !j < n && s.[!j] = ':' then
            match String.index_from_opt s !j '}' with
            | Some c ->
                let p = String.sub s (!j + 1) (c - !j - 1) in
                (match String.index_opt p '=' with
                 | Some e ->
                     Some (String.sub p 0 e,
                           String.sub p (e + 1) (String.length p - e - 1)), c
                 | None -> error ("${" ^ name ^ ":" ^ p ^ "}: no ="))
            | None -> error ("${" ^ name ^ ": no closing brace")
          else None, !j in
        let value =
          match Hashtbl.find_opt vars name, pattern with
          | Some v, None -> String.concat " " v
          (* (in a recipe, printed as the shell will run it: as in mk, a
           * substitution is a rule's or a variable's, not a recipe's) *)
          | Some _, Some _ when keep -> String.sub s i (close + 1 - i)
          | Some v, Some (from, to_) ->
              String.concat " " (List.map (subst_word from to_) v)
          | None, _ when keep ->
              String.sub s i ((if braced then close + 1 else !j) - i)
          | None, _ -> error ("undefined variable $" ^ name)
        in
        Buffer.add_string b value;
        go (if braced then close + 1 else !j)
      end
      else (Buffer.add_char b s.[i]; go (i + 1))
  in
  go 0;
  Buffer.contents b

(* the rules, in order, and the variables; [read] gives an included
 * file's text (None: it doesn't exist yet, e.g. a generated .depend) *)
let parse (fixed : (string * string list) list) (read : string -> string option)
    (text : string) : rule list * vars =
  let vars = Hashtbl.create 17 and rules = ref [] in
  (* the command line's, NAME=value, before the file's and over them, as
   * mk's: tiny-build TINY=tiny- for the host's tools *)
  List.iter (fun (k, v) -> Hashtbl.replace vars k v) fixed;
  (* a backslash-newline continues a line, as ocamldep writes them *)
  let lines text =
    let n = String.length text and b = Buffer.create (String.length text) in
    String.iteri (fun i c ->
      if c = '\\' && i + 1 < n && text.[i + 1] = '\n' then Buffer.add_char b ' '
      else if not (c = '\n' && i > 0 && text.[i - 1] = '\\') then
        Buffer.add_char b c) text;
    String.split_on_char '\n' (Buffer.contents b)
  in
  let is_recipe l = l <> "" && (l.[0] = '\t' || l.[0] = ' ') in
  let strip l =
    match String.index_opt l '#' with Some i -> String.sub l 0 i | None -> l
  in
  let rec go = function
    | [] -> ()
    | l :: _ when is_recipe l -> error ("a recipe line with no rule: " ^ l)
    | l :: rest when String.length l > 1 && l.[0] = '<' ->
        let file =
          String.trim (expand false vars (String.sub l 1 (String.length l - 1)))
        in
        Option.iter (fun text -> go (lines text)) (read file);
        go rest
    | l :: rest ->
        let l = strip l in
        let before i = words (expand false vars (String.sub l 0 i)) in
        let after i =
          words (expand false vars
            (String.sub l (i + 1) (String.length l - i - 1)))
        in
        (* whichever of = and : comes first, outside a ${...}, whose
         * ${X:from=to} has both *)
        let outside c =
          let depth = ref 0 and found = ref None in
          String.iteri (fun i ch ->
            if !found = None then
              if ch = '{' && i > 0 && l.[i - 1] = '$' then incr depth
              else if ch = '}' && !depth > 0 then decr depth
              else if ch = c && !depth = 0 then found := Some i) l;
          !found in
        match outside '=', outside ':' with
        | Some i, j when (match j with Some j -> i < j | None -> true) ->
            let name = String.trim (String.sub l 0 i) in
            if not (List.mem_assoc name fixed) then
              Hashtbl.replace vars name (after i);
            go rest
        | _, Some j ->
            let rec recipe acc = function
              | r :: rs when is_recipe r -> recipe (String.trim r :: acc) rs
              | rs -> String.concat "\n" (List.rev acc), rs
            in
            let body, rest = recipe [] rest in
            let prereqs = after j in
            let recipe = if body = "" then None else Some body in
            before j |> List.iter (fun t ->
              rules := { target = target_of t; prereqs; recipe } :: !rules);
            go rest
        | _ ->
            if String.trim l <> "" then error ("not a rule nor a variable: " ^ l);
            go rest
  in
  go (lines text);
  List.rev !rules, vars

(*****************************************************************************)
(* The graph *)
(*****************************************************************************)

(* does a target match name? the stem if so, "" for an exact one *)
let matches (t : target) (name : string) : string option =
  let around pre suf =
    let n = String.length name and np = String.length pre
    and ns = String.length suf in
    if np + ns <= n && String.sub name 0 np = pre
       && String.sub name (n - ns) ns = suf
    then Some (String.sub name np (n - np - ns)) else None
  in
  match t with
  | Exact s -> if s = name then Some "" else None
  | Pattern (pre, suf) -> around pre suf
  | Amp (pre, suf) ->
      (match around pre suf with
       | Some stem when not (String.contains stem '/' || String.contains stem '.') ->
           Some stem
       | _ -> None)

(* a prerequisite's % and & made the stem *)
let subst stem (p : string) =
  String.concat stem
    (List.map (fun q -> String.concat stem (String.split_on_char '&' q))
       (String.split_on_char '%' p))

(* From a target to its node: the rules naming it exactly, merged (at
 * most one with a recipe); if none has a recipe, the one pattern rule
 * whose prerequisites can all be made. exists asks the system whether a
 * file is at a name's path: the name made an Fpath.t there. *)
let graph (rules : rule list) (exists : Fpath.t -> bool) (target : string) :
    node =
  let memo = Hashtbl.create 101 in
  let exact, patterns =
    List.partition
      (fun r -> match r.target with Exact _ -> true | _ -> false) rules
  in
  (* the patterns used on the way to a pattern's prerequisite: only one
   * with % carries them (a %: %.gz would make x.gz.gz...); a name given
   * as it is, by an exact rule (a .depend's line) or by a pattern
   * ($LIB's), starts afresh, as GNU make's: x.o by %.o, then y.tmi of
   * its .depend line by %.tmi, then y.o by %.o again *)
  let along r used p =
    if String.contains p '%' || String.contains p '&' then r :: used else [] in
  let rec node path used name =
    match Hashtbl.find_opt memo name with
    | Some n -> n
    | None ->
        if List.mem name path then
          error ("cycle: " ^ String.concat " -> " (List.rev (name :: path)));
        let mine = List.filter (fun r -> r.target = Exact name) exact in
        let prereqs = List.concat_map (fun r -> r.prereqs) mine in
        let make, extra =
          match List.filter_map (fun (r : rule) -> r.recipe) mine with
          | [ text ] -> Recipe { text; stem = "" }, []
          | _ :: _ :: _ -> error ("two recipes for " ^ name)
          | [] ->
              let candidates =
                patterns |> List.filter_map (fun r ->
                  if List.memq r used then None
                  else match matches r.target name with
                    | Some stem
                      when List.for_all
                             (fun p ->
                               makeable path (along r used p) (subst stem p))
                             r.prereqs
                      -> Some (r, stem)
                    | _ -> None)
              in
              (match candidates with
               | [] -> Source, []
               | [ (r, stem) ] ->
                   let make =
                     match r.recipe with
                     | Some text -> Recipe { text; stem }
                     | None -> Source
                   in
                   make,
                   List.map (fun p -> subst stem p, along r used p) r.prereqs
               | _ -> error ("ambiguous: several patterns make " ^ name))
        in
        let n =
          { name; make;
            deps =
              List.map (node (name :: path) []) prereqs
              @ List.map (fun (p, used) -> node (name :: path) used p) extra }
        in
        if make = Source && n.deps = [] && not (exists (Fpath.v name)) then
          error ("don't know how to make " ^ name);
        Hashtbl.replace memo name n;
        n
  (* can this name be made: a file, or a target of some rule? *)
  and makeable path used name =
    exists (Fpath.v name) || List.exists (fun r -> r.target = Exact name) exact
    || List.exists (fun r ->
         not (List.memq r used) && not (List.mem name path)
         && match matches r.target name with
            | Some stem ->
                List.for_all
                  (fun p ->
                    makeable (name :: path) (along r used p) (subst stem p))
                  r.prereqs
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

(* (a target's name is text, matched by the rules and the digests'
 * key: a path at this section's door) *)
let read_file caps file =
  let path = Fpath.v file in
  if TSys.exists caps path then Some (TSys.read_file caps path) else None

(* A file's digest, the SHA-1 of its bytes, read once in a run
 * (file_digests), and not at all when its size and date are the ones
 * .tiny-build recorded with its digest (known): git's index, where make
 * trusts the date alone. A digest is recorded only for a file dated
 * before the second it was read in: one written again within that
 * second, at the same size, would have the same date and another
 * digest (git's "racy" files). The file is digested as it is read, 4
 * KB at a time (old: read whole: boot.img, 8 MB, put tiny-kernel's
 * tiny-build, in 16, out of memory).
 * (old: every file read at each run, twice, its digest computed again:
 * minutes of tiny-kernel's for its own build; older: Digest's MD5,
 * where SHA-1 was in t-ix already, tiny-vcs's)
 *
 * The tables are keyed by a node's name, a string and not an Fpath.t,
 * and digest_file takes one too: a name need *not* be a file (all, whose
 * digest is None), and the rules match names as text (matches). An
 * Fpath.t is made only where TinyLibSystem is called.
 *)
let file_digests : (string, Sha1.t option) Hashtbl.t = Hashtbl.create 101
let known : (string, int * int * Sha1.t) Hashtbl.t = Hashtbl.create 101

let digest_file (caps : < Cap.open_in; Cap.readdir; .. >) (file : string) :
    Sha1.t option =
  match Hashtbl.find_opt file_digests file with
  | Some d -> d
  | None ->
      let path = Fpath.v file in
      let d =
        if TSys.exists caps path && not (TSys.is_directory caps path)
        then begin
          let (st : TSys.stat) = TSys.stat caps path
          and date = TSys.mtime caps path in
          let size = st.st_size in
          match Hashtbl.find_opt known file with
          | Some (s, t, d) when s = size && t = date -> Some d
          | _ ->
              let now = TSys.time caps in
              (* (a piece at a time: a file need not fit in the heap) *)
              let b = Bytes.make 4096 ' ' in
              let d =
                TSys.with_open_in caps (fun (c : Chan.i) ->
                    Sha1.reads (fun () ->
                      Bytes.sub_string b 0 (In_channel.input c.ic b 0 4096)))
                  path in
              if date < now then Hashtbl.replace known file (size, date, d)
              else Hashtbl.remove known file;
              Some d
        end
        else None in
      Hashtbl.replace file_digests file d;
      d

(* a recipe run by rc -e, the host's tiny-shell or tiny-kernel's /bin/rc
 * (TSys.shell); its pid, None when no process could run it (old:
 * CapUnix.fork and execve of /bin/sh -e -c here) *)
let start (caps : < Cap.fork; Cap.exec; Cap.env; Cap.open_out; .. >)
    (vars : (string * string list) list) (recipe : string)
    : TSys.pid option =
  TSys.shell caps vars recipe

(*****************************************************************************)
(* .tiny-build *)
(*****************************************************************************)

let stampfile = ".tiny-build"

(* .tiny-build: magic, then the stamps and known, marshalled; without
 * magic, no stamps (tiny-ml's Marshal stops on bytes it cannot read).
 * old: text, a line each, read back by hand *)
let magic = "tiny-build 2\n"  (* (1: the digests in hexadecimal) *)

(* the stamps of the last build, the digests it knew put back in known *)
let load (caps : < Cap.open_in; .. >) : stamps =
  let n = String.length magic in
  match read_file caps stampfile with
  | Some s when String.length s >= n && String.sub s 0 n = magic ->
      (* (their types load's and known's) *)
      let stamps, digests = Marshal.from_string s n in
      Hashtbl.iter (Hashtbl.replace known) digests;
      stamps
  | _ -> Hashtbl.create 101

(* the stamps and the digests known, written to .tiny-build: after each
 * recipe that ends well, so that a build stopped (killed, the machine
 * halted) keeps what it made (old: at the end only: tiny-kernel's
 * build of itself, stopped after 5 hours, began again from nothing) *)
let save (caps : < Cap.open_out; .. >) (stamps : stamps) =
  TSys.write_file caps (Fpath.v stampfile)
    (magic ^ Marshal.to_string (stamps, known) [ Marshal.No_sharing ])

(*****************************************************************************)
(* Extra features *)
(*****************************************************************************)

(* the recipes run, each with its time in milliseconds (-t) *)
let times : (string * int) list ref = ref []

(*****************************************************************************)
(* Building *)
(*****************************************************************************)

let build
    (caps : < Cap.forkew; Cap.open_in; Cap.open_out;
              Cap.env; Cap.stdout; Cap.stderr; .. >)
    (vars : vars) (stamps : stamps)
    jobs dry timed (root : node) : bool =
  let digests = Hashtbl.create 101 in    (* the nodes done: their digest *)
  let running = Hashtbl.create 7 in      (* pid -> node, its start *)
  let ran = ref 0 and failed = ref false in
  (* the Buildfile's variables, then the environment's (TSys.shell's;
   * old: the environment's first) *)
  let env = Hashtbl.fold (fun k v acc -> (k, v) :: acc) vars [] in
  (* a source's recipe is "", as .tiny-build's stamps have it; a
   * recipe with the Buildfile's variables by their values, as -n
   * prints it, so that a changed variable remakes what its recipes
   * make ($target, $prereq and $stem left, which the node and its
   * prerequisites say; the environment's left too, not followed) *)
  let stamp n =
    let recipe =
      match n.make with Source -> "" | Recipe r -> expand true vars r.text in
    Sha1.string (String.concat "\n" (recipe :: List.map (fun d ->
      d.name ^ " " ^ Sha1.to_hex (Hashtbl.find digests d.name)) n.deps))
  in
  (* a node is done: its digest is its file's, or, without one, its stamp *)
  let finish n = Hashtbl.replace digests n.name
      (match digest_file caps n.name with Some d -> d | None -> stamp n) in
  (* a node decided: done, or its recipe started; false when its
   * recipe could not be, the system's processes all taken, while others
   * run: it is started again when one has ended (old: its pid -1 kept
   * as running, waited for ever: -j 3 hung on tiny-kernel) *)
  let said = Hashtbl.create 7 in
  let decide n =
    match n.make with
    | Source -> finish n; true
    | Recipe _
      when digest_file caps n.name <> None
           && Hashtbl.find_opt stamps n.name = Some (stamp n) -> finish n; true
    | Recipe r ->
      let own =
        [ "target", [ n.name ]; "stem", [ r.stem ];
          "prereq", List.map (fun d -> d.name) n.deps ]
      in
      let shown = Hashtbl.copy vars in
      List.iter (fun (k, v) -> Hashtbl.replace shown k v) own;
      if not (Hashtbl.mem said n.name) then begin
        Hashtbl.replace said n.name ();
        TSys.print caps (expand true shown r.text ^ "\n");
        incr ran
      end;
      if dry then
        (Hashtbl.replace digests n.name (Sha1.string ("dry " ^ n.name)); true)
      else
        match start caps (own @ env) r.text with
        | Some pid ->
            Hashtbl.replace running pid (n, TSys.millis caps); true
        | None when Hashtbl.length running > 0 -> false
        | None ->
            TSys.flush caps;
            TSys.eprint caps
              (Printf.sprintf "tiny-build: %s: no process to run it\n" n.name);
            failed := true;
            true
  in
  let wait () =
    match TSys.wait_any caps with
    | None -> ()
    | Some (pid, st) ->
    match Hashtbl.find_opt running pid with
    | None -> ()
    | Some (n, began) ->
        Hashtbl.remove running pid;
        (* (said at once: a build that fails later keeps them) *)
        if timed then begin
          let ms = TSys.millis caps - began in
          times := (n.name, ms) :: !times;
          TSys.print caps (Printf.sprintf "%8d ms  %s\n" ms n.name)
        end;
        (* (its file made again: its digest too) *)
        if st = "" then (
          Hashtbl.remove file_digests n.name;
          Hashtbl.replace stamps n.name (stamp n);
          finish n;
          save caps stamps)
        else (
          TSys.flush caps;
          TSys.eprint caps
            (Printf.sprintf "tiny-build: %s failed\n" n.name);
          failed := true)
  in
  let rec loop todo =
    let ready n = List.for_all (fun d -> Hashtbl.mem digests d.name) n.deps in
    let rec start_ready = function
      | n :: rest when Hashtbl.length running < jobs && not !failed && ready n ->
          if decide n then start_ready rest else n :: rest
      | n :: rest -> n :: start_ready rest
      | [] -> []
    in
    let todo = start_ready todo in
    if Hashtbl.length running > 0 then (wait (); loop todo)
    else if todo <> [] && not !failed && List.exists ready todo then loop todo
  in
  loop (order root);
  if !ran = 0 && not !failed then
    TSys.print caps
      (Printf.sprintf "tiny-build: %s is up to date\n" root.name);
  not !failed

(*****************************************************************************)
(* Reporting times (-t) *)
(*****************************************************************************)

(* -t, at the end: the times by kind of target: its
 * directory and its extension (bin/*, ml/*.s, *.o), and the rest of the
 * run's, which was no recipe's *)
let report caps total =
  let kind name =
    let dir = Filename.dirname name and base = Filename.basename name in
    let ext =
      match String.rindex_opt base '.' with
      | Some i -> String.sub base i (String.length base - i)
      | None -> ""
    in
    (if dir = "." then "" else dir ^ "/") ^ "*" ^ ext in
  let by = Hashtbl.create 17 in
  List.iter (fun (name, ms) ->
    let n, t =
      match Hashtbl.find_opt by (kind name) with Some x -> x | None -> 0, 0
    in
    Hashtbl.replace by (kind name) (n + 1, t + ms)) (List.rev !times);
  let rows =
    List.sort (fun (_, (_, a)) (_, (_, b)) -> compare b a)
      (Hashtbl.fold (fun k v acc -> (k, v) :: acc) by [])
  in
  List.iter (fun (k, (n, t)) ->
    TSys.print caps (Printf.sprintf "%8d ms  %4d  %s\n" t n k)) rows;
  let recipes = List.fold_left (fun acc (_, ms) -> acc + ms) 0 !times in
  (* (with -j the recipes overlap: their sum may pass the whole's, and
   * how many ran at once on average is what is worth saying) *)
  if recipes <= total then
    TSys.print caps
      (Printf.sprintf "%8d ms        not a recipe's\n%8d ms        in all\n"
         (total - recipes) total)
  else
    TSys.print caps
      (Printf.sprintf
         "%8d ms        the recipes', %d.%d at once\n%8d ms        in all\n"
         recipes (recipes / max 1 total) (recipes * 10 / max 1 total mod 10)
         total)

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

exception Bad of string

let run (caps : < caps; .. >) (argv : string array) : Exit.t =
  let file = ref "Buildfile" and jobs = ref 1 and dry = ref false
  and dot = ref false and timed = ref false in
  let began = TSys.millis caps in
  let targets = ref [] and fixed = ref [] in
  (* old: Arg.parse_argv, for these four options *)
  let bad o =
    raise (Bad ("tiny-build: unknown option '" ^ o ^ "'\n" ^ usage
                ^ "   (-h: how)\n"))
  in
  let rec options = function
    | "-f" :: f :: rest -> file := f; options rest
    | "-j" :: n :: rest ->
        (match int_of_string_opt n with
         | Some n -> jobs := n
         | None -> bad ("-j " ^ n));
        options rest
    | "-n" :: rest -> dry := true; options rest
    | "-g" :: rest -> dot := true; options rest
    | "-t" :: rest -> timed := true; options rest
    | o :: _ when o <> "" && o.[0] = '-' -> bad o
    | a :: rest when String.contains a '=' ->
        let i = String.index a '=' in
        fixed := !fixed @ [ String.sub a 0 i,
                            words (String.sub a (i + 1) (String.length a - i - 1)) ];
        options rest
    | t :: rest -> targets := !targets @ [ t ]; options rest
    | [] -> ()
  in
  options (List.tl (Array.to_list argv));
  try
    let text =
      match read_file caps !file with
      | Some s -> s
      | None -> error ("no " ^ !file)
    in
    let rules, vars = parse !fixed (read_file caps) text in
    let targets =
      match !targets, rules with
      | [], r :: _ -> [ show_target r.target ]
      | [], [] -> error "nothing to build"
      | ts, _ -> ts
    in
    let stamps = load caps in
    let ok =
      targets |> List.for_all (fun t ->
        let root = graph rules (TSys.exists caps) t in
        if !dot then begin
          TSys.print caps "digraph G {\n";
          order root |> List.iter (fun n ->
            List.iter (fun d ->
              TSys.print caps
                (Printf.sprintf "  %S -> %S;\n" n.name d.name)) n.deps);
          TSys.print caps "}\n";
          true
        end
        else build caps vars stamps (max 1 !jobs) !dry !timed root)
    in
    if not !dry then save caps stamps;
    if !timed then report caps (TSys.millis caps - began);
    if ok then Exit.OK else Exit.Code 1
  with Error msg -> Exit.Err msg

(* -h, and an unknown option said, not raised *)
let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  match Array.to_list argv with
  | [ _; ("-h" | "--help") ] -> TSys.print caps help; Exit.OK
  | _ ->
      (try run caps argv
       with Bad m -> TSys.eprint caps m; Exit.Code 2)

let () = TSys.main "tiny-build" main
