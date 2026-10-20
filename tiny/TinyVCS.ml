(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyVCS.mli *)

(* -h: how, by examples, each one as it runs *)
open Common

let help = {|usage: tiny-vcs CMD [args], in a directory with .tvcs, or below it
git's ideas, the roads after git: no staging (every file tracked but dotfiles
and .tvcsignore's), every command undoable, a merge's conflicts committed.
  tiny-vcs init; echo hello > a.txt
  tiny-vcs status                    A a.txt
  tiny-vcs commit -m first           master: d1c4126e...
  tiny-vcs branch feature; tiny-vcs switch feature
  echo more >> a.txt; tiny-vcs diff  +more, unified
  tiny-vcs commit -m second; tiny-vcs log
  tiny-vcs switch master; tiny-vcs merge feature
  tiny-vcs ops; tiny-vcs undo        the operations; the last one undone
  tiny-vcs show a.txt                a file as committed
  tiny-vcs clone ../repo copy; tiny-vcs pull ../repo; tiny-vcs push ../repo
|}

exception Error of string

(* (old: a format, Printf.ksprintf's: tiny-ml has no Printf) *)
let error s = raise (Error s)

(*****************************************************************************)
(* Objects *)
(*****************************************************************************)

type hash = string   (* 40 hex digits *)

(* the text with markers, and the three versions, None for absent
 * (old: an inline record, Conflict's own, which tiny-ml does not read) *)
type conflict = { text : hash; base : hash option; ours : hash option; theirs : hash option }

type entry =
  | File of hash
  | Exec of hash
  | Dir of hash
  | Conflict of conflict

type commit = { tree : hash; parents : hash list; date : int; author : string; msg : string }

type op = { prev : hash option; odate : int; what : string; current : string; branches : (string * hash) list }

type obj = Blob of string | Tree of (string * entry) list | Commit of commit | Op of op

let encode = function
  | Blob s -> "blob\n" ^ s
  | Tree es ->
      let opt = function Some h -> h | None -> "-" in
      "tree\n" ^ String.concat "" (List.map (fun (name, e) ->
        (match e with
         | File h -> "f " ^ h | Exec h -> "x " ^ h | Dir h -> "d " ^ h
         | Conflict c -> "c " ^ c.text ^ " " ^ opt c.base ^ " " ^ opt c.ours ^ " " ^ opt c.theirs) ^ " " ^ name ^ "\n") es)
  | Commit c ->
      "commit\ntree " ^ c.tree ^ "\n" ^ String.concat "" (List.map (fun p -> "parent " ^ p ^ "\n") c.parents)
      ^ "date " ^ string_of_int c.date ^ "\nauthor " ^ c.author ^ "\n\n" ^ c.msg
  | Op o ->
      "op\n" ^ (match o.prev with Some p -> "prev " ^ p ^ "\n" | None -> "") ^ "date " ^ string_of_int o.odate
      ^ "\nwhat " ^ o.what ^ "\ncurrent " ^ o.current ^ "\n"
      ^ String.concat "" (List.map (fun (b, h) -> "branch " ^ h ^ " " ^ b ^ "\n") o.branches)

(* "key value" lines, until a blank line; the rest *)
let headers s =
  let rec go pos acc =
    match String.index_from_opt s pos '\n' with
    | Some i when i = pos -> List.rev acc, String.sub s (i + 1) (String.length s - i - 1)
    | Some i -> let l = String.sub s pos (i - pos) in go (i + 1) (l :: acc)
    | None -> List.rev (if pos < String.length s then String.sub s pos (String.length s - pos) :: acc else acc), "" in
  let lines, rest = go 0 [] in
  List.map (fun l -> match String.index_opt l ' ' with
    | Some i -> String.sub l 0 i, String.sub l (i + 1) (String.length l - i - 1)
    | None -> l, "") lines, rest

let decode s =
  let nl = match String.index_opt s '\n' with Some i -> i | None -> error "bad object" in
  let body = String.sub s (nl + 1) (String.length s - nl - 1) in
  let all k hs = List.filter_map (fun (k', v) -> if k = k' then Some v else None) hs in
  let one k hs = match all k hs with v :: _ -> v | [] -> error ("bad object: no " ^ k) in
  match String.sub s 0 nl with
  | "blob" -> Blob body
  | "tree" ->
      let entry l =
        match String.split_on_char ' ' l with
        | "c" :: t :: b :: o :: th :: name ->
            let opt = function "-" -> None | h -> Some h in
            String.concat " " name, Conflict { text = t; base = opt b; ours = opt o; theirs = opt th }
        | k :: h :: name ->
            String.concat " " name, (match k with "f" -> File h | "x" -> Exec h | "d" -> Dir h | _ -> error "bad tree")
        | _ -> error "bad tree" in
      Tree (List.map entry (List.filter (( <> ) "") (String.split_on_char '\n' body)))
  | "commit" ->
      let hs, msg = headers body in
      Commit { tree = one "tree" hs; parents = all "parent" hs; date = int_of_string (one "date" hs); author = one "author" hs; msg }
  | "op" ->
      let hs, _ = headers (body ^ "\n") in
      Op { prev = (match all "prev" hs with p :: _ -> Some p | [] -> None); odate = int_of_string (one "date" hs);
           what = one "what" hs; current = one "current" hs;
           branches = List.map (fun v -> match String.index_opt v ' ' with
             | Some i -> String.sub v (i + 1) (String.length v - i - 1), String.sub v 0 i
             | None -> error "bad op") (all "branch" hs) }
  | k -> error ("bad object kind " ^ k)

(*****************************************************************************)
(* The store: one append-only file, and head *)
(*****************************************************************************)

(* .tvcs/objects: "HASH LENGTH\n" and that many bytes, the object's
 * text, each object once; read whole at open, the index in memory
 * (old: deflated, by lib_compression's Zlib: 300 lines more for
 * tiny-ml to compile and tiny-kernel to load) *)
(* the capabilities a command needs: a repository is opened with them
 * and keeps them, for its files; output is printed with them *)
type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.env; Cap.readdir >

type repo = { caps : caps; root : string; index : (hash, string) Hashtbl.t; mutable fresh : (hash * string) list }

let dir r = Filename.concat r.root ".tvcs"
let path r f = Filename.concat (dir r) f

let read_file (caps : < Cap.open_in; .. >) p = TinyLibSystem.read_file caps p

let write_file (caps : < Cap.open_out; .. >) p s =
  let fd = TinyLibSystem.open_out caps p in
  TinyLibSystem.write fd s;
  TinyLibSystem.close fd

let exists p = try ignore (TinyLibSystem.stat p); true with Failure _ -> false

let load (caps : caps) root =
  let r = { caps; root; index = Hashtbl.create 1024; fresh = [] } in
  let s = try read_file caps (path r "objects") with Failure _ -> "" in
  let rec go pos =
    if pos < String.length s then
      let nl = String.index_from s pos '\n' in
      match String.split_on_char ' ' (String.sub s pos (nl - pos)) with
      | [ h; n ] -> let n = int_of_string n in Hashtbl.replace r.index h (String.sub s (nl + 1) n); go (nl + 1 + n)
      | _ -> error "corrupt store" in
  go 0;
  r

let hash_of s = Sha1.to_hex (Sha1.string s)

let get r h =
  match Hashtbl.find_opt r.index h with
  | Some s -> decode s
  | None -> error ("missing object " ^ h)

let put r o =
  let s = encode o in
  let h = hash_of s in
  if not (Hashtbl.mem r.index h) then begin
    Hashtbl.replace r.index h s;
    r.fresh <- (h, s) :: r.fresh
  end;
  h

let blob r h = match get r h with Blob s -> s | _ -> error (h ^ ": not a blob")
let tree r h = match get r h with Tree es -> es | _ -> error (h ^ ": not a tree")
let commit r h = match get r h with Commit c -> c | _ -> error (h ^ ": not a commit")

(* the new objects appended, then head replaced: a crash between
 * leaves head naming the old state, whole *)
let save r (o : op) =
  let h = put r (Op o) in
  let fd = TinyLibSystem.open_append r.caps (path r "objects") in
  TinyLibSystem.write fd (String.concat "" (List.map (fun (h, z) -> h ^ " " ^ string_of_int (String.length z) ^ "\n" ^ z) (List.rev r.fresh)));
  TinyLibSystem.close fd;
  r.fresh <- [];
  let tmp = path r "head.tmp" in
  write_file r.caps tmp (h ^ "\n");
  TinyLibSystem.rename r.caps tmp (path r "head")

let head r = String.trim (read_file r.caps (path r "head"))
let state r = match get r (head r) with Op o -> o | _ -> error "head is not an operation"

let getenv_opt (caps : < Cap.env; .. >) v = List.assoc_opt v (TinyLibSystem.environment caps)

let now caps =
  match getenv_opt caps "TINYVCS_DATE" with Some d -> int_of_string d | None -> TinyLibSystem.time ()

(* a new state: the branches changed, the current branch too for
 * record_at, the rest kept *)
let record_at r current what branches =
  save r { prev = Some (head r); odate = now r.caps; what; current; branches }

let record r what branches = record_at r (state r).current what branches

let tip r = let s = state r in List.assoc_opt s.current s.branches

(*****************************************************************************)
(* The work tree *)
(*****************************************************************************)

let ignored caps root =
  let pats = try List.filter (( <> ) "") (String.split_on_char '\n' (read_file caps (Filename.concat root ".tvcsignore"))) with Failure _ -> [] in
  fun name ->
    name.[0] = '.'
    || List.exists (fun p ->
         if String.length p > 1 && p.[0] = '*' then Filename.check_suffix name (String.sub p 1 (String.length p - 1)) else p = name) pats

(* the work tree as a tree, its blobs written; a conflicted file whose
 * text still has the markers stays a conflict *)
let snapshot r =
  let ign = ignored r.caps r.root in
  let old = match tip r with Some c -> Some (commit r c).tree | None -> None in
  let rec go dir (prev : (string * entry) list) =
    let names = List.sort compare (TinyLibSystem.readdir dir) in
    let es = List.filter_map (fun name ->
      if ign name then None
      else
        let p = Filename.concat dir name in
        match (try Some (fst (TinyLibSystem.stat p)) with Failure _ -> None) with
        | Some true ->
            let sub = match List.assoc_opt name prev with Some (Dir h) -> tree r h | _ -> [] in
            (match go p sub with [] -> None | es -> Some (name, Dir (put r (Tree es))))
        | Some false ->
            let h = put r (Blob (read_file r.caps p)) in
            Some (name, match List.assoc_opt name prev with
              | Some (Conflict c) when c.text = h -> Conflict c
              | _ -> if TinyLibSystem.is_executable p then Exec h else File h)
        | None -> None) names in
    es in
  put r (Tree (go r.root (match old with Some t -> tree r t | None -> [])))

(* the work tree made a tree's: what the old one had and the new lacks
 * removed, what differs written *)
let checkout r (old : hash option) (nw : hash) =
  let rec rm_rf p = if TinyLibSystem.is_directory p then List.iter (fun f -> rm_rf (Filename.concat p f)) (TinyLibSystem.readdir p); TinyLibSystem.remove r.caps p in
  (* (old: File h | Exec h | Conflict { text = h; _ }, an or-pattern
   * with variables, which tiny-ml does not read) *)
  let write p h x =
    if exists p && TinyLibSystem.is_directory p then rm_rf p;
    write_file r.caps p (blob r h);
    TinyLibSystem.set_executable r.caps p x in
  let rec go dir (old : (string * entry) list) (nw : (string * entry) list) =
    List.iter (fun (name, _) -> if not (List.mem_assoc name nw) then (try rm_rf (Filename.concat dir name) with Failure _ -> ())) old;
    List.iter (fun (name, e) ->
      let p = Filename.concat dir name in
      if List.assoc_opt name old <> Some e then
        match e with
        | Dir h ->
            let sub = match List.assoc_opt name old with Some (Dir o) -> tree r o | _ -> [] in
            if exists p && not (TinyLibSystem.is_directory p) then TinyLibSystem.remove r.caps p;
            if not (exists p) then TinyLibSystem.mkdir r.caps p;
            go p sub (tree r h)
        | File h -> write p h false
        | Exec h -> write p h true
        | Conflict c -> write p c.text false) nw in
  go r.root (match old with Some t -> tree r t | None -> []) (tree r nw)

(* the files of two trees that differ: path, before, after *)
let rec changes r prefix (a : (string * entry) list) (b : (string * entry) list) =
  let names = List.sort_uniq compare (List.map fst a @ List.map fst b) in
  List.concat_map (fun name ->
    let p = if prefix = "" then name else prefix ^ "/" ^ name in
    match List.assoc_opt name a, List.assoc_opt name b with
    | x, y when x = y -> []
    | Some (Dir x), Some (Dir y) -> changes r p (tree r x) (tree r y)
    | Some (Dir x), y -> changes r p (tree r x) [] @ (if y = None then [] else [ p, None, y ])
    | x, Some (Dir y) -> (if x = None then [] else [ p, x, None ]) @ changes r p [] (tree r y)
    | x, y -> [ p, x, y ]) names

let tree_of_commit r = function Some c -> tree r (commit r c).tree | None -> []

(*****************************************************************************)
(* Diff and merge *)
(*****************************************************************************)

(* the lines, each with its newline; the last may lack one *)
let lines s =
  let n = String.length s in
  let rec go pos acc =
    if pos >= n then List.rev acc
    else match String.index_from_opt s pos '\n' with
      | Some i -> go (i + 1) (String.sub s pos (i - pos + 1) :: acc)
      | None -> List.rev (String.sub s pos (n - pos) :: acc) in
  Array.of_list (go 0 [])

let ends_nl l = l <> "" && l.[String.length l - 1] = '\n'

(* a line printed after its prefix, the missing newline said *)
let line prefix l = if ends_nl l then prefix ^ l else prefix ^ l ^ "\n\\ No newline at end of file\n"

(* Myers: the shortest edit script, as the matched pairs (i, j) *)
let matches (a : string array) (b : string array) =
  let n = Array.length a and m = Array.length b in
  let max = n + m in
  let v = Array.make (2 * max + 2) 0 in
  let trace = ref [] in
  let rec step d =
    trace := Array.copy v :: !trace;
    let rec diag k =
      if k > d then None
      else begin
        let x = if k = -d || (k <> d && v.(max + k - 1) < v.(max + k + 1)) then v.(max + k + 1) else v.(max + k - 1) + 1 in
        let x = ref x in
        while !x < n && !x - k < m && a.(!x) = b.(!x - k) do incr x done;
        v.(max + k) <- !x;
        if !x >= n && !x - k >= m then Some d else diag (k + 2)
      end in
    match diag (-d) with Some d -> d | None -> step (d + 1) in
  let d = if max = 0 then 0 else step 0 in
  (* back from (n, m) through the saved rows *)
  let pairs = ref [] and x = ref n and y = ref m in
  List.iteri (fun i vd ->
    let d = d - i in
    let k = !x - !y in
    let pk = if k = -d || (k <> d && vd.(max + k - 1) < vd.(max + k + 1)) then k + 1 else k - 1 in
    let px = if d = 0 then 0 else vd.(max + pk) in
    let py = px - pk in
    while !x > px && !y > py do
      decr x; decr y; pairs := (!x, !y) :: !pairs
    done;
    if d > 0 then (x := px; y := py)) !trace;
  !pairs

(* unified diff, 3 lines of context *)
let unified name_a name_b a b =
  let a = lines a and b = lines b in
  let ms = Array.of_list (matches a b) in
  (* the edits: runs between matches *)
  let hunks = ref [] and pa = ref 0 and pb = ref 0 in
  Array.iter (fun (i, j) ->
    if i > !pa || j > !pb then hunks := (!pa, i, !pb, j) :: !hunks;
    pa := i + 1; pb := j + 1) ms;
  if !pa < Array.length a || !pb < Array.length b then hunks := (!pa, Array.length a, !pb, Array.length b) :: !hunks;
  let edits = List.rev !hunks in
  if edits = [] then ""
  else begin
    let buf = Buffer.create 256 in
    Buffer.add_string buf ("--- " ^ name_a ^ "\n+++ " ^ name_b ^ "\n");
    (* edits whose contexts touch go in one hunk *)
    let rec groups = function
      | [] -> []
      | e :: rest ->
          let rec take (_, a1, _, _) acc = function
            | ((a0', _, _, _) as e') :: rest when a0' - a1 <= 6 -> take e' (e' :: acc) rest
            | rest -> List.rev acc, rest in
          let g, rest = take e [ e ] rest in
          g :: groups rest in
    List.iter (fun g ->
      let (a0, _, b0, _) = List.hd g and (_, a1, _, b1) = List.nth g (List.length g - 1) in
      let s = max 0 (a0 - 3) and e = min (Array.length a) (a1 + 3) in
      let sb = b0 - (a0 - s) and eb = b1 + (e - a1) in
      Buffer.add_string buf ("@@ -" ^ string_of_int (if e = s then s else s + 1) ^ "," ^ string_of_int (e - s)
        ^ " +" ^ string_of_int (if eb = sb then sb else sb + 1) ^ "," ^ string_of_int (eb - sb) ^ " @@\n");
      let at = ref s in
      List.iter (fun (a0, a1, b0, b1) ->
        for i = !at to a0 - 1 do Buffer.add_string buf (line " " a.(i)) done;
        for i = a0 to a1 - 1 do Buffer.add_string buf (line "-" a.(i)) done;
        for j = b0 to b1 - 1 do Buffer.add_string buf (line "+" b.(j)) done;
        at := a1) g;
      for i = !at to e - 1 do Buffer.add_string buf (line " " a.(i)) done) (groups edits);
    Buffer.contents buf
  end

(* diff3: the base's lines both sides kept split the three files into
 * stable and unstable chunks; an unstable chunk only one side changed
 * is taken, one both changed alike too, else it is a conflict *)
(* (old: ~base ~ours ~theirs, labels, which tiny-ml does not read) *)
let merge3 base ours theirs =
  let o = lines base and a = lines ours and b = lines theirs in
  let ma = Hashtbl.create 64 and mb = Hashtbl.create 64 in
  List.iter (fun (i, j) -> Hashtbl.replace ma i j) (matches o a);
  List.iter (fun (i, j) -> Hashtbl.replace mb i j) (matches o b);
  let out = Buffer.create 256 and conflict = ref false in
  let emit arr x y = for i = x to y - 1 do Buffer.add_string out arr.(i) done in
  (* inside a conflict, a side's last line gets a newline before the
   * marker *)
  let emit_side arr x y = emit arr x y; if y > x && not (ends_nl arr.(y - 1)) then Buffer.add_char out '\n' in
  let chunk ox oy ax ay bx by =
    let sub arr x y = Array.to_list (Array.sub arr x (y - x)) in
    let so = sub o ox oy and sa = sub a ax ay and sb = sub b bx by in
    if sa = so then emit b bx by
    else if sb = so || sa = sb then emit a ax ay
    else begin
      conflict := true;
      Buffer.add_string out "<<<<<<< ours\n"; emit_side a ax ay;
      Buffer.add_string out "||||||| base\n"; emit_side o ox oy;
      Buffer.add_string out "=======\n"; emit_side b bx by;
      Buffer.add_string out ">>>>>>> theirs\n"
    end in
  let rec go i ai bi =
    (* the next base line kept by both, from i *)
    let rec next k = if k >= Array.length o then None else match Hashtbl.find_opt ma k, Hashtbl.find_opt mb k with
      | Some x, Some y when x >= ai && y >= bi -> Some (k, x, y) | _ -> next (k + 1) in
    match next i with
    | Some (k, x, y) ->
        if k > i || x > ai || y > bi then chunk i k ai x bi y;
        Buffer.add_string out o.(k);
        go (k + 1) (x + 1) (y + 1)
    | None -> if i < Array.length o || ai < Array.length a || bi < Array.length b then chunk i (Array.length o) ai (Array.length a) bi (Array.length b) in
  go 0 0 0;
  Buffer.contents out, !conflict

(* the ancestors of a commit, itself included *)
let ancestors r h =
  let seen = Hashtbl.create 64 in
  let rec go h = if not (Hashtbl.mem seen h) then (Hashtbl.add seen h (); List.iter go (commit r h).parents) in
  go h;
  seen

(* a best common ancestor: common, and no other common one below it;
 * the smallest hash of several, to be deterministic *)
let lca r a b =
  let aa = ancestors r a and ab = ancestors r b in
  let common = Hashtbl.fold (fun h () acc -> if Hashtbl.mem ab h then h :: acc else acc) aa [] in
  let below = Hashtbl.create 64 in
  List.iter (fun h -> List.iter (fun p -> Hashtbl.iter (fun x () -> Hashtbl.replace below x ()) (ancestors r p)) (commit r h).parents) common;
  match List.sort compare (List.filter (fun h -> not (Hashtbl.mem below h)) common) with
  | h :: _ -> Some h
  | [] -> None

(* three trees merged entry by entry; the conflicts' paths *)
let rec merge_trees r base ours theirs prefix =
  let names = List.sort_uniq compare (List.concat_map (List.map fst) [ base; ours; theirs ]) in
  let conflicts = ref [] in
  let es = List.filter_map (fun name ->
    let b = List.assoc_opt name base and o = List.assoc_opt name ours and t = List.assoc_opt name theirs in
    let p = if prefix = "" then name else prefix ^ "/" ^ name in
    let content = function Some (File h) -> Some h | Some (Exec h) -> Some h | Some (Conflict c) -> Some c.text | _ -> None in
    let text h = match h with Some h -> blob r h | None -> "" in
    if o = t then Option.map (fun e -> name, e) o
    else if o = b then Option.map (fun e -> name, e) t
    else if t = b then Option.map (fun e -> name, e) o
    else match o, t with
      | Some (Dir x), Some (Dir y) ->
          let bt = match b with Some (Dir z) -> tree r z | _ -> [] in
          let es, cs = merge_trees r bt (tree r x) (tree r y) p in
          conflicts := !conflicts @ cs;
          if es = [] then None else Some (name, Dir (put r (Tree es)))
      | (Some (Dir _), _ | _, Some (Dir _)) ->
          (* a file against a directory: ours kept *)
          conflicts := !conflicts @ [ p ];
          Option.map (fun e -> name, e) o
      | _ ->
          let merged, conflict = merge3 (text (content b)) (text (content o)) (text (content t)) in
          let exec = (match o with Some (Exec _) -> true | _ -> false) || (match t with Some (Exec _) -> true | _ -> false) in
          let h = put r (Blob merged) in
          if conflict || o = None || t = None then begin
            conflicts := !conflicts @ [ p ];
            Some (name, Conflict { text = h; base = content b; ours = content o; theirs = content t })
          end
          else Some (name, if exec then Exec h else File h)) names in
  es, !conflicts

(*****************************************************************************)
(* Remotes: directories *)
(*****************************************************************************)

(* the objects a commit reaches that [dst] lacks, copied *)
let rec copy src dst h =
  if not (Hashtbl.mem dst.index h) then begin
    let z = Hashtbl.find src.index h in
    Hashtbl.replace dst.index h z;
    dst.fresh <- (h, z) :: dst.fresh;
    match get src h with
    | Commit c -> copy src dst c.tree; List.iter (copy src dst) c.parents
    | Tree es -> List.iter (fun (_, e) -> match e with
        | File h -> copy src dst h
        | Exec h -> copy src dst h
        | Dir h -> copy src dst h
        | Conflict c -> List.iter (Option.iter (copy src dst)) [ Some c.text; c.base; c.ours; c.theirs ]) es
    | Blob _ | Op _ -> ()
  end

(*****************************************************************************)
(* The commands *)
(*****************************************************************************)

let short h = String.sub h 0 10
let first_line s = match String.index_opt s '\n' with Some i -> String.sub s 0 i | None -> s

let find_root caps =
  let rec up d = if exists (Filename.concat d ".tvcs/head") then d else if Filename.dirname d = d then error "not a tiny-vcs repository" else up (Filename.dirname d) in
  up (TinyLibSystem.getcwd caps)

let author caps = getenv_opt caps "TINYVCS_AUTHOR" ||| (getenv_opt caps "USER" ||| "nobody")

let init (caps : caps) dir =
  if exists (Filename.concat dir ".tvcs") then error (dir ^ "/.tvcs exists");
  TinyLibSystem.mkdir caps (Filename.concat dir ".tvcs");
  let r = load caps dir in
  save r { prev = None; odate = now caps; what = "init"; current = "master"; branches = [] }

(* the work tree's snapshot must be the tip's, for a switch or a merge *)
let clean r =
  let snap = snapshot r in
  let tipt = match tip r with Some c -> (commit r c).tree | None -> put r (Tree []) in
  if snap <> tipt then error "uncommitted changes: commit first"

let run (caps : caps) (args : string list) =
  let print s = TinyLibSystem.print caps s in
  match args with
  | [ ("-h" | "--help") ] -> print help
  | [ "init" ] | [ "init"; _ ] -> init caps (match args with [ _; d ] -> d | _ -> ".")
  | "clone" :: [ src; dst ] ->
      let s = load caps src in
      let st = match get s (String.trim (read_file caps (Filename.concat src ".tvcs/head"))) with Op o -> o | _ -> error "bad head" in
      TinyLibSystem.mkdir caps dst;
      init caps dst;
      let r = load caps dst in
      List.iter (fun (_, h) -> copy s r h) st.branches;
      record_at r st.current ("clone " ^ src) st.branches;
      Option.iter (fun c -> checkout r None (commit r c).tree) (tip r)
  | cmd :: rest -> (
      let r = load caps (find_root caps) in
      let s = state r in
      match cmd, rest with
      | "status", [] ->
          let snap = snapshot r in
          List.iter (fun (p, a, b) ->
            print ((match a, b, b with
              | _, _, Some (Conflict _) -> "C" | None, _, _ -> "A" | _, None, _ -> "R" | _ -> "M") ^ " " ^ p ^ "\n"))
            (changes r "" (tree_of_commit r (tip r)) (tree r snap));
          (* conflicts committed and not yet resolved *)
          let rec conflicts prefix es = List.concat_map (fun (n, e) ->
            let p = if prefix = "" then n else prefix ^ "/" ^ n in
            match e with Conflict _ -> [ p ] | Dir h -> conflicts p (tree r h) | _ -> []) es in
          List.iter (fun p -> print ("C " ^ p ^ "\n")) (conflicts "" (tree r snap))
      | "diff", ([] | [ _ ] | [ _; _ ]) ->
          let tree_at h = tree r (commit r h).tree in
          let a, b = match rest with
            | [] -> tree_of_commit r (tip r), tree r (snapshot r)
            | [ c ] -> tree_at c, tree r (snapshot r)
            | c1 :: c2 :: _ -> tree_at c1, tree_at c2 in
          let text = function Some (File h) -> blob r h | Some (Exec h) -> blob r h | Some (Conflict c) -> blob r c.text | _ -> "" in
          List.iter (fun (p, x, y) ->
            print (unified (if x = None then "/dev/null" else "a/" ^ p) (if y = None then "/dev/null" else "b/" ^ p) (text x) (text y)))
            (changes r "" a b)
      | "commit", [ "-m"; msg ] ->
          let snap = snapshot r in
          let parents = Option.to_list (tip r) in
          (match tip r with Some c when (commit r c).tree = snap -> error "nothing to commit" | _ -> ());
          let c = put r (Commit { tree = snap; parents; date = now caps; author = author caps; msg = msg ^ "\n" }) in
          record r ("commit " ^ short c) ((s.current, c) :: List.remove_assoc s.current s.branches);
          print (s.current ^ ": " ^ c ^ "\n")
      | "log", [] ->
          (* newest first, each commit once; the same dates (tiny-kernel's
           * are all 0: no clock) in the order reached, breadth first
           * (old: a commit's parents before the commits waiting, so a
           * branch's first commit came before its second) *)
          let seen = Hashtbl.create 64 in
          let rec go = function
            | [] -> ()
            | hs ->
                let hs = List.sort (fun a b -> compare (commit r b).date (commit r a).date) hs in
                let h = List.hd hs in
                let c = commit r h in
                Hashtbl.add seen h ();
                print (short h ^ " " ^ c.author ^ " " ^ first_line c.msg ^ "\n");
                go (List.tl hs @ List.filter (fun p -> not (Hashtbl.mem seen p) && not (List.mem p (List.tl hs))) c.parents) in
          go (Option.to_list (tip r))
      | "branch", [] -> List.iter (fun (b, h) -> print ((if b = s.current then "*" else " ") ^ " " ^ b ^ " " ^ short h ^ "\n")) s.branches
      | "branch", [ b ] ->
          if List.mem_assoc b s.branches then error ("branch " ^ b ^ " exists");
          (match tip r with Some h -> record r ("branch " ^ b) ((b, h) :: s.branches) | None -> error "no commit yet")
      | "switch", [ b ] ->
          clean r;
          let h = match List.assoc_opt b s.branches with Some h -> h | None -> error ("no branch " ^ b) in
          checkout r (Option.map (fun c -> (commit r c).tree) (tip r)) (commit r h).tree;
          record_at r b ("switch " ^ b) s.branches
      | "merge", [ b ] -> (
          clean r;
          let theirs = match List.assoc_opt b s.branches with Some h -> h | None -> error ("no branch " ^ b) in
          let ours = match tip r with Some h -> h | None -> error "no commit yet" in
          match lca r ours theirs with
          | Some base when base = theirs -> print "already merged\n"
          | Some base when base = ours ->
              checkout r (Some (commit r ours).tree) (commit r theirs).tree;
              record r ("merge " ^ b ^ " (fast-forward)") ((s.current, theirs) :: List.remove_assoc s.current s.branches);
              print ("fast-forward to " ^ short theirs ^ "\n")
          | base ->
              let es, conflicts = merge_trees r (tree_of_commit r base) (tree_of_commit r (Some ours)) (tree_of_commit r (Some theirs)) "" in
              let t = put r (Tree es) in
              let c = put r (Commit { tree = t; parents = [ ours; theirs ]; date = now caps; author = author caps; msg = "merge " ^ b ^ "\n" }) in
              checkout r (Some (commit r ours).tree) t;
              record r ("merge " ^ b) ((s.current, c) :: List.remove_assoc s.current s.branches);
              List.iter (fun p -> print ("conflict: " ^ p ^ "\n")) conflicts;
              print (s.current ^ ": " ^ c ^ "\n"))
      | "ops", [] ->
          let rec go h = let o = match get r h with Op o -> o | _ -> error "bad op" in
            print (short h ^ " " ^ o.what ^ "\n");
            Option.iter go o.prev in
          go (head r)
      | "undo", [] ->
          (* back to the state before; the work tree follows when clean *)
          let prev = match s.prev with Some p -> p | None -> error "nothing to undo" in
          let before = match get r prev with Op o -> o | _ -> error "bad op" in
          let old_tree = Option.map (fun c -> (commit r c).tree) (tip r) in
          let back = match List.assoc_opt before.current before.branches with Some c -> Some (commit r c).tree | None -> None in
          if Some (snapshot r) = old_tree || old_tree = None then
            (match back with Some t -> checkout r old_tree t | None -> ());
          record_at r before.current ("undo " ^ s.what) before.branches;
          print ("undid: " ^ s.what ^ "\n")
      | "pull", [ src ] -> (
          clean r;
          let sr = load caps src in
          let st = match get sr (String.trim (read_file caps (Filename.concat src ".tvcs/head"))) with Op o -> o | _ -> error "bad head" in
          let theirs = match List.assoc_opt s.current st.branches with Some h -> h | None -> error (src ^ " has no branch " ^ s.current) in
          copy sr r theirs;
          let with_ours c = (s.current, c) :: List.remove_assoc s.current s.branches in
          match tip r with
          | None -> checkout r None (commit r theirs).tree; record r ("pull " ^ src) (with_ours theirs)
          | Some ours ->
              (match lca r ours theirs with
               | Some b when b = theirs -> print "up to date\n"; record r ("pull " ^ src) s.branches
               | Some b when b = ours ->
                   checkout r (Some (commit r ours).tree) (commit r theirs).tree;
                   record r ("pull " ^ src) (with_ours theirs);
                   print ("fast-forward to " ^ short theirs ^ "\n")
               | _ -> record r ("pull " ^ src) (("pulled/" ^ s.current, theirs) :: s.branches);
                   print ("diverged: merge pulled/" ^ s.current ^ "\n")))
      | "push", [ dst ] ->
          let dr = load caps dst in
          let dst_state = match get dr (String.trim (read_file caps (Filename.concat dst ".tvcs/head"))) with Op o -> o | _ -> error "bad head" in
          let ours = match tip r with Some h -> h | None -> error "no commit yet" in
          (match List.assoc_opt s.current dst_state.branches with
           | Some theirs when not (Hashtbl.mem (ancestors r ours) theirs) -> error "not a fast-forward: pull first"
           | _ -> ());
          copy r dr ours;
          save dr { prev = Some (String.trim (read_file caps (Filename.concat dst ".tvcs/head"))); odate = now caps; what = "push from " ^ r.root;
                    current = dst_state.current; branches = (s.current, ours) :: List.remove_assoc s.current dst_state.branches };
          print (s.current ^ ": " ^ short ours ^ "\n")
      | "show", [ path ] ->
          (* a file of the tip *)
          let rec find es = function
            | [ n ] -> (match List.assoc_opt n es with Some (File h) -> blob r h | Some (Exec h) -> blob r h | Some (Conflict c) -> blob r c.text | _ -> error ("no file " ^ path))
            | n :: rest -> (match List.assoc_opt n es with Some (Dir h) -> find (tree r h) rest | _ -> error ("no file " ^ path))
            | [] -> error "no file" in
          print (find (tree_of_commit r (tip r)) (String.split_on_char '/' path))
      | _ -> error "usage: tiny-vcs init|status|diff|commit -m msg|log|branch [b]|switch b|merge b|ops|undo|clone src dst|pull src|push dst|show path")
  | [] -> error "usage: tiny-vcs CMD   (-h: how)"

let () =
  TinyLibSystem.main "tiny-vcs" (fun caps ->
    try run (caps :> caps) (List.tl (TinyLibSystem.argv caps)); 0
    with Error m -> TinyLibSystem.eprint caps ("tiny-vcs: " ^ m ^ "\n"); 1)
