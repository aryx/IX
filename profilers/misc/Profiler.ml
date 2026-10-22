(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Profiler.mli *)

let usage = {|usage: mini-prof [-n count] [-diff base.prof] [-a name] profile file.map...
  profile    lines "pc count" (hexadecimal pc): mini-5i -prof, mini-qemu -prof
  file.map   the link's functions: mini-ld -map's "address name" lines, or
             mini-ld -v's listing ("address: word TEXT name+0(SB), $frame")
  -diff      a profile of a shorter run taken off first (the start)
  -n         the functions shown (default 30)
  -a         the function's instructions, each with its count, read from
             the program beside its map (doom for doom.map); name: mini-ml's
             in full (f1_to_rgba<>), or without its number and <> (to_rgba)
For example:
  mini-5i -prof start.prof doom -dump-frame 1 f.ppm
  mini-5i -prof walk.prof doom -dump-frame 31 f.ppm -script up:1-31
  mini-prof -diff start.prof walk.prof doom.map     30 frames, the start off
  mini-prof -diff start.prof -a to_rgba walk.prof doom.map|}

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

(* the functions of the maps, by address, each with its map *)
let functions (caps : < Cap.open_in ; .. >) (files : string list) : (int * string * string) array =
  let all =
    List.concat_map
      (fun (f : string) ->
        List.filter_map
          (fun (l : string) -> Option.map (fun ((a, name) : int * string) -> (a, name, f)) (symbol l))
          (String.split_on_char '\n' (FS.read caps (Fpath.v f))))
      files in
  let a = Array.of_list all in
  Array.sort (fun ((x, _, _) : int * string * string) ((y, _, _) : int * string * string) -> compare x y) a;
  a

(* the function [pc] is in: the last one that starts at or before it,
 * its index *)
let find (funcs : (int * string * string) array) (pc : int) : int option =
  let rec look (lo : int) (hi : int) : int =
    if lo >= hi then lo
    else
      let m = (lo + hi + 1) / 2 in
      let a, _, _ = funcs.(m) in
      if a <= pc then look m hi else look lo (m - 1) in
  let first, _, _ = if Array.length funcs = 0 then (0, "", "") else funcs.(0) in
  if Array.length funcs = 0 || pc < first then None else Some (look 0 (Array.length funcs - 1))

let name_at (funcs : (int * string * string) array) (pc : int) : string =
  match find funcs pc with Some i -> (let _, name, _ = funcs.(i) in name) | None -> "?"

(* a mini-ml name without its unit's number and its <> (a function
 * local to its file): f1_to_rgba<>, to_rgba *)
let short (name : string) : string =
  let n = if String.ends_with ~suffix:"<>" name then String.sub name 0 (String.length name - 2) else name in
  match String.index_opt n '_' with
  | Some i when i > 1 && n.[0] = 'f' && String.for_all (fun (c : char) -> c >= '0' && c <= '9') (String.sub n 1 (i - 1)) ->
      String.sub n (i + 1) (String.length n - i - 1)
  | _ -> n

(* a program's text: its word at an address, and how one is printed.
 * An ELF (Linux's): its segments, arm32 or arm64 by its machine; else
 * Plan 9's a.out, arm32, its header at 0x1000 and the text after *)
let text (s : string) : (int -> int option) * (int -> int -> string) =
  let word (o : int) : int option =
    if o >= 0 && o + 4 <= String.length s then Some (Bits.of_int32 (String.get_int32_le s o)) else None in
  let arm32 (a : int) (w : int) : string = Show_arm32.print ~addr:a (Arm32.decode w) in
  let arm64 (a : int) (w : int) : string = Show_arm64.print ~addr:a (Arm64.decode w) in
  if String.length s >= 4 && String.sub s 0 4 = "\x7fELF" then
    let elf = Elf.parse s in
    let at (a : int) : int option =
      match List.find_opt (fun (g : Elf.segment) -> g.exec && a >= g.vaddr && a + 4 <= g.vaddr + g.filesz) elf.segments with
      | Some g -> word (g.offset + a - g.vaddr)
      | None -> None in
    (at, if elf.machine = Elf.Aarch64 then arm64 else arm32)
  else ((fun (a : int) -> word (a - 0x1000)), arm32)

(* 1234567 as 1,234,567 *)
let commas (n : int) : string =
  let s = string_of_int n in
  let k = String.length s in
  String.concat "" (List.init k (fun (i : int) -> (if i > 0 && (k - i) mod 3 = 0 then "," else "") ^ String.make 1 s.[i]))

(* -a: each function named, its instructions with their counts (none:
 * not run), from its address to the next function's *)
let annotate (caps : < Cap.open_in ; Cap.stdout ; Cap.stderr ; .. >) (funcs : (int * string * string) array) (counts : (int, int) Hashtbl.t) (total : int) (name : string) : int =
  let found = ref 0 in
  Array.iteri
    (fun (i : int) ((start, f, map) : int * string * string) ->
      if f = name || short f = name then begin
        incr found;
        let stop = if i + 1 < Array.length funcs then (let a, _, _ = funcs.(i + 1) in a) else start + 4 in
        let prog = if Filename.check_suffix map ".map" then Filename.chop_suffix map ".map" else map in
        let word, show = text (FS.read caps (Fpath.v prog)) in
        let sum = ref 0 in
        for k = 0 to ((stop - start) / 4) - 1 do
          sum := !sum + (match Hashtbl.find_opt counts (start + (4 * k)) with Some n -> n | None -> 0)
        done;
        Console.print caps
          (Printf.sprintf "%s (%s): %s instructions, %.1f%%\n%14s %8s  instruction\n" f prog (commas !sum)
             (100. *. float !sum /. float (max 1 total)) "count" "address");
        for k = 0 to ((stop - start) / 4) - 1 do
          let a = start + (4 * k) in
          let n = match Hashtbl.find_opt counts a with Some n when n > 0 -> commas n | _ -> "" in
          let ins = match word a with Some w -> show a w | None -> "?" in
          Console.print caps (Printf.sprintf "%14s %8x  %s\n" n a ins)
        done
      end)
    funcs;
  if !found = 0 then (Console.eprint caps (Printf.sprintf "mini-prof: no function %s in the maps\n" name); 1) else 0

let main (caps : < Cap.argv ; Cap.stdout ; Cap.stderr ; Cap.open_in ; .. >) : int =
  let rec options (top : int) (diff : string option) (fn : string option) (args : string list) =
    match args with
    | "-n" :: n :: rest -> options (int_of_string n) diff fn rest
    | "-diff" :: f :: rest -> options top (Some f) fn rest
    | "-a" :: f :: rest -> options top diff (Some f) rest
    | file :: maps when file <> "" && file.[0] <> '-' && maps <> [] -> Some (top, diff, fn, file, maps)
    | _ -> None in
  match options 30 None None (List.tl (Array.to_list (CapSys.argv caps))) with
  | None -> Console.eprint caps (usage ^ "\n"); 2
  | Some (top, diff, fn, file, maps) -> (
      let counts = read_profile caps file in
      Option.iter
        (fun (f : string) ->
          Hashtbl.iter
            (fun (pc : int) (n : int) ->
              match Hashtbl.find_opt counts pc with Some m -> Hashtbl.replace counts pc (max 0 (m - n)) | None -> ())
            (read_profile caps f))
        diff;
      let funcs = functions caps maps in
      let total = Hashtbl.fold (fun (_ : int) (n : int) (acc : int) -> acc + n) counts 0 in
      match fn with
      (* a word in an int: mini-ml's on 32-bit arm (mini-9pi) has 31
       * bits, an instruction's condition lost *)
      | Some _ when Sys.int_size < 32 -> Console.eprint caps "mini-prof: -a needs ints of 32 bits or more\n"; 1
      | Some name -> annotate caps funcs counts total name
      | None ->
          let by : (string, int) Hashtbl.t = Hashtbl.create 1024 in
          Hashtbl.iter (fun (pc : int) (n : int) -> add by (name_at funcs pc) n) counts;
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
          0)
