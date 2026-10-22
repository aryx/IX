(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Profiler.mli *)

let usage = {|usage: mini-prof [-n count] [-diff base.prof] profile file.map...
  profile    lines "pc count" (hexadecimal pc): mini-5i -prof, mini-qemu -prof
  file.map   the link's functions: mini-ld -map's "address name" lines, or
             mini-ld -v's listing ("address: word TEXT name+0(SB), $frame")
  -diff      a profile of a shorter run taken off first (the start)
  -n         the functions shown (default 30)
For example:
  mini-5i -prof start.prof doom -dump-frame 1 f.ppm
  mini-5i -prof walk.prof doom -dump-frame 31 f.ppm -script up:1-31
  mini-prof -diff start.prof walk.prof doom.map     30 frames, the start off|}

(* n added to k's count, 0 when it has none *)
let add (tbl : ('k, int) Hashtbl.t) (k : 'k) (n : int) : unit =
  Hashtbl.replace tbl k (n + match Hashtbl.find_opt tbl k with Some m -> m | None -> 0)

(* the counts of a profile, by pc *)
let read_profile (caps : < Cap.open_in ; .. >) (file : string) : (int, int) Hashtbl.t =
  let counts : (int, int) Hashtbl.t = Hashtbl.create 65536 in
  List.iter
    (fun (line : string) ->
      match String.split_on_char ' ' line with
      | [ pc; n ] -> (
          match (int_of_string_opt ("0x" ^ pc), int_of_string_opt n) with
          | Some pc, Some n -> add counts pc n
          | _ -> ())
      | _ -> ())
    (String.split_on_char '\n' (FS.read caps (Fpath.v file)));
  counts

(* a map's or a listing's line: the function that starts there *)
let symbol (line : string) : (int * string) option =
  match List.filter (fun (w : string) -> w <> "") (String.split_on_char ' ' (String.map (fun c -> if c = '\t' then ' ' else c) line)) with
  | [ a; name ] -> Option.map (fun (a : int) -> (a, name)) (int_of_string_opt ("0x" ^ a))
  | a :: _ :: "TEXT" :: name :: _ -> (
      let a = String.sub a 0 (max 0 (String.length a - 1)) in
      let name = match String.index_opt name '+' with Some i -> String.sub name 0 i | None -> name in
      match int_of_string_opt ("0x" ^ a) with Some a -> Some (a, name) | None -> None)
  | _ -> None

(* the functions of the maps, by address *)
let functions (caps : < Cap.open_in ; .. >) (files : string list) : (int * string) array =
  let all = List.concat_map (fun (f : string) -> List.filter_map symbol (String.split_on_char '\n' (FS.read caps (Fpath.v f)))) files in
  let a = Array.of_list all in
  Array.sort (fun ((x, _) : int * string) ((y, _) : int * string) -> compare x y) a;
  a

(* the function [pc] is in: the last one that starts at or before it *)
let find (funcs : (int * string) array) (pc : int) : string =
  let rec look (lo : int) (hi : int) : int = if lo >= hi then lo else let m = (lo + hi + 1) / 2 in if fst funcs.(m) <= pc then look m hi else look lo (m - 1) in
  if Array.length funcs = 0 || pc < fst funcs.(0) then "?" else snd funcs.(look 0 (Array.length funcs - 1))

(* 1234567 as 1,234,567 *)
let commas (n : int) : string =
  let s = string_of_int n in
  let k = String.length s in
  String.concat "" (List.init k (fun (i : int) -> (if i > 0 && (k - i) mod 3 = 0 then "," else "") ^ String.make 1 s.[i]))

let main (caps : < Cap.argv ; Cap.stdout ; Cap.stderr ; Cap.open_in ; .. >) : int =
  let rec options (top : int) (diff : string option) (args : string list) =
    match args with
    | "-n" :: n :: rest -> options (int_of_string n) diff rest
    | "-diff" :: f :: rest -> options top (Some f) rest
    | file :: maps when file <> "" && file.[0] <> '-' && maps <> [] -> Some (top, diff, file, maps)
    | _ -> None in
  match options 30 None (List.tl (Array.to_list (CapSys.argv caps))) with
  | None -> Console.eprint caps (usage ^ "\n"); 2
  | Some (top, diff, file, maps) ->
      let counts = read_profile caps file in
      Option.iter
        (fun (f : string) ->
          Hashtbl.iter
            (fun (pc : int) (n : int) ->
              match Hashtbl.find_opt counts pc with Some m -> Hashtbl.replace counts pc (max 0 (m - n)) | None -> ())
            (read_profile caps f))
        diff;
      let funcs = functions caps maps in
      let by : (string, int) Hashtbl.t = Hashtbl.create 1024 in
      Hashtbl.iter
        (fun (pc : int) (n : int) ->
          add by (find funcs pc) n)
        counts;
      let total = Hashtbl.fold (fun (_ : int) (n : int) (acc : int) -> acc + n) counts 0 in
      (* the most first; equal counts by name (a table's order is its
       * library's) *)
      let rows = List.sort (fun ((a, n) : string * int) ((b, m) : string * int) -> if n <> m then compare m n else compare a b)
          (Hashtbl.fold (fun (f : string) (n : int) (acc : (string * int) list) -> (f, n) :: acc) by []) in
      Console.print caps (Printf.sprintf "%s instructions\n%14s %6s  function\n" (commas total) "count" "%");
      List.iteri
        (fun (i : int) ((name, n) : string * int) ->
          if i < top && n > 0 then
            Console.print caps (Printf.sprintf "%14s %6.1f  %s\n" (commas n) (100. *. float n /. float (max 1 total)) name))
        rows;
      0
