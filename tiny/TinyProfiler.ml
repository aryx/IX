(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyProfiler.mli *)

let usage = {|usage: tiny-prof [-n count] [-diff base] [-base hex] profile
         [-k file.map...] [-u file.map...]|}

(* [add tbl k n]: n added to k's count, 0 when k has none (by hand:
 * OCaml's Option.value takes ~default, ix's does not) *)
let add tbl k n =
  Hashtbl.replace tbl k
    (n + (match Hashtbl.find_opt tbl k with Some m -> m | None -> 0))

(* A profile's lines "k|u base pc count" (TinyMachineCPU.profile_lines):
 * the counts by (the kernel's?, base, pc). *)
let read_profile caps file =
  let int_of_hex h = int_of_string ("0x" ^ h) in
  let counts = Hashtbl.create 4096 in
  List.iter (fun line ->
    match String.split_on_char ' ' line with
    | [ m; b; pc; n ] ->
        let k = m = "k", int_of_hex b, int_of_hex pc in
        add counts k (int_of_string n)
    | _ -> ()) (String.split_on_char '\n' (TinyLibSystem.read_file caps file));
  counts

(* A label a compiler makes inside a function: a dot, an L, digits *)
let local name =
  match String.rindex_opt name '.' with
  | Some i when i + 2 < String.length name && name.[i + 1] = 'L' ->
      String.for_all (fun c -> c >= '0' && c <= '9')
        (String.sub name (i + 2) (String.length name - i - 2))
  | _ -> false

(* tiny-ml's functions are <unit>.f<number>_<name>: their name alone,
 * but for an anonymous one (Unit.f155_fun), whose number is all that
 * tells it from the others
 * (old: f<number>_<name><>, a program's functions in one file) *)
let clean name =
  let n = String.length name in
  let digit c = c >= '0' && c <= '9' in
  let rec find i =
    if i + 2 >= n then None
    else if name.[i] = '.' && name.[i + 1] = 'f' && digit name.[i + 2] then
      Some i
    else find (i + 1) in
  match find 0 with
  | Some i ->
      let rec skip j = if j < n && digit name.[j] then skip (j + 1) else j in
      let j = skip (i + 2) in
      if j < n && name.[j] = '_' then
        (let short = String.sub name (j + 1) (n - j - 1) in
         if short = "fun" then name else short)
      else name
  | None -> name

(* the functions of tiny-linker's maps (-map: "address label" lines,
 * by address), in their order *)
let functions caps files =
  let labels = List.concat_map (fun f ->
    List.filter_map (fun line ->
      match String.split_on_char ' ' line with
      | [ a; l ] when not (local l) -> Some (l, int_of_string ("0x" ^ a))
      | _ -> None)
      (String.split_on_char '\n' (TinyLibSystem.read_file caps f))) files in
  Array.of_list (List.sort (fun (_, a) (_, b) -> compare a b) labels)

(* the function an address is in: the last one at or before it *)
let find funcs pc =
  let rec go lo hi =
    if hi - lo <= 1 then lo
    else
      let mid = (lo + hi) / 2 in
      if snd funcs.(mid) <= pc then go mid hi else go lo mid in
  if Array.length funcs = 0 || pc < snd funcs.(0) then "?"
  else clean (fst funcs.(go 0 (Array.length funcs)))

(* 1234567 as 1,234,567 *)
let commas n =
  let s = string_of_int n in
  let k = String.length s in
  String.concat "" (List.init k (fun i ->
    (if i > 0 && (k - i) mod 3 = 0 then "," else "") ^ String.make 1 s.[i]))

(* n of total in percent, a tenth's digit, rounded: integers, which
 * tiny-ml has (its 31 bits: both scaled down first when total is
 * large, so that n * 2000 fits) (old: floats, %.1f) *)
let percent n total =
  if total = 0 then "0.0"
  else
    let g = max 1 (total / 100000) in
    let t = ((n / g * 2000 / (total / g)) + 1) / 2 in
    string_of_int (t / 10) ^ "." ^ string_of_int (t mod 10)


let main (caps : < Cap.stdout; Cap.stderr; Cap.argv; Cap.open_in; .. >) =
  let print = TinyLibSystem.print caps in
  let rec options top diff base = function
    | "-n" :: n :: rest -> options (int_of_string n) diff base rest
    | "-diff" :: f :: rest -> options top (Some f) base rest
    | "-base" :: b :: rest ->
        options top diff (Some (int_of_string ("0x" ^ b))) rest
    | file :: rest when file.[0] <> '-' ->
        (* the files after -k are the kernel's, after -u the program's *)
        let rec files k u kernel = function
          | "-k" :: rest -> files k u true rest
          | "-u" :: rest -> files k u false rest
          | f :: rest ->
              if kernel then files (f :: k) u kernel rest
              else files k (f :: u) kernel rest
          | [] -> List.rev k, List.rev u in
        Some (top, diff, base, file, files [] [] false rest)
    | _ -> None in
  match options 20 None None (List.tl (TinyLibSystem.argv caps)) with
  | None -> TinyLibSystem.eprint caps (usage ^ "\n"); 2
  | Some (top, diff, base, file, (kfiles, ufiles)) ->
      let counts = read_profile caps file in
      Option.iter (fun f ->
        Hashtbl.iter (fun k n ->
            match Hashtbl.find_opt counts k with
            | Some m -> Hashtbl.replace counts k (max 0 (m - n))
            | None -> ())
          (read_profile caps f)) diff;
      (* the totals: the kernel's, and each program's by its window's base *)
      let kernel = ref 0 and programs = Hashtbl.create 8 in
      Hashtbl.iter (fun (k, b, _) n ->
        if k then kernel := !kernel + n else add programs b n) counts;
      let user = Hashtbl.fold (fun _ n acc -> acc + n) programs 0 in
      let total = !kernel + user in
      let named = match base with
        | Some b -> b
        | None ->
            fst (Hashtbl.fold (fun b n (bb, bn) ->
                if n > bn || (n = bn && b < bb) then (b, n) else (bb, bn))
              programs (0, -1)) in
      let kfuncs = functions caps kfiles and ufuncs = functions caps ufiles in
      (* each count to its function *)
      let by = Hashtbl.create 256 in
      Hashtbl.iter (fun (k, b, pc) n ->
        let where =
          if k then
            "k", (if kfiles = [] then "(the kernel)" else find kfuncs pc)
          else if b <> named then "u", "(another program)"
          else "u", (if ufiles = [] then "(the program)" else find ufuncs pc) in
        add by where n) counts;
      (* the most first; the same counts in their names' order (a table's
       * order is its library's: OCaml's and tiny-ml's are others) *)
      let most (a, n) (b, m) = if n <> m then compare m n else compare a b in
      let rows =
        List.sort most (Hashtbl.fold (fun w n acc -> (w, n) :: acc) by []) in
      print (Printf.sprintf "%s instructions: the kernel %s%%, programs %s%%\n"
        (commas total) (percent !kernel total) (percent user total));
      if Hashtbl.fold (fun _ n k -> if n > 0 then k + 1 else k) programs 0 > 1
      then
        print (Printf.sprintf
          "programs, by their window's base: %s (-u is the one at %x)\n"
          (String.concat ", "
             (List.map (fun (b, n) -> Printf.sprintf "%x %s" b (commas n))
                (List.sort most
                   (Hashtbl.fold (fun b n acc ->
                      if n > 0 then (b, n) :: acc else acc) programs []))))
          named);
      print (Printf.sprintf "%12s %6s     function\n" "count" "%");
      List.iteri (fun i ((mode, name), n) ->
        if i < top && n > 0 then
          print (Printf.sprintf "%12s %6s  %s  %s\n" (commas n)
            (percent n total) mode name)) rows;
      0

let () = TinyLibSystem.main "tiny-prof" main
