(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyProfiler.mli *)

module TSys = TinyLibSystem
module M = TinyLibMachine

let usage = {|usage: tiny-prof [-n count] [-diff base] [-base hex] profile
         [-k file.map...] [-u file.map...]|}

(*****************************************************************************)
(* The profile *)
(*****************************************************************************)

(* where an instruction ran: the kernel or a program, the base of the
 * window the machine ran in (a program's partition), the instruction's
 * address; the counts of a profile, by where *)
type space = Kernel | User
type spot = { space : space; base : M.address; pc : M.address }
type counts = (spot, int) Hashtbl.t

(* the letter of a space, as the profile and the report write it *)
let letter space = match space with Kernel -> "k" | User -> "u"

(* [add tbl k n]: n added to k's count, 0 when k has none (by hand:
 * OCaml's Option.value takes ~default, ix's does not) *)
let add tbl k n =
  Hashtbl.replace tbl k
    (n + (match Hashtbl.find_opt tbl k with Some m -> m | None -> 0))

(* A profile's lines "k|u base pc count" (TinyMachineCPU.profile_lines) *)
let read_profile caps (file : Fpath.t) : counts =
  let int_of_hex h = int_of_string ("0x" ^ h) in
  let counts = Hashtbl.create 4096 in
  List.iter (fun line ->
    match String.split_on_char ' ' line with
    | [ m; b; pc; n ] ->
        let space = if m = "k" then Kernel else User in
        add counts { space; base = int_of_hex b; pc = int_of_hex pc }
          (int_of_string n)
    | _ -> ()) (String.split_on_char '\n' (TSys.read_file caps file));
  counts

(* -diff: a shorter run's counts taken off, none below 0 *)
let subtract (counts : counts) (base : counts) =
  Hashtbl.iter (fun k n ->
      match Hashtbl.find_opt counts k with
      | Some m -> Hashtbl.replace counts k (max 0 (m - n))
      | None -> ())
    base

(* the functions of tiny-ld's maps (-map: "address label" lines),
 * by address (TinyLibMachine's, as the function an address is in) *)
let functions caps (files : Fpath.t list) : M.symbols =
  M.labels (String.concat "\n" (List.map (TSys.read_file caps) files))
let find funcs pc =
  match M.find funcs pc with Some (f, _) -> f | None -> "?"

(*****************************************************************************)
(* The report *)
(*****************************************************************************)

(* 1234567 as 1,234,567 *)
let commas n =
  let s = string_of_int n in
  let k = String.length s in
  String.concat "" (List.init k (fun i ->
    (if i > 0 && (k - i) mod 3 = 0 then "," else "") ^ String.make 1 s.[i]))

(* n of total in percent, a tenth's digit, rounded: integers, which
 * tiny-ml has (its 31 bits: both scaled down first when total is
 * large, so that n * 2000 fits) *)
let percent n total =
  if total = 0 then "0.0"
  else
    let g = max 1 (total / 100000) in
    let t = ((n / g * 2000 / (total / g)) + 1) / 2 in
    string_of_int (t / 10) ^ "." ^ string_of_int (t mod 10)

(* the most first; the same counts in their keys' order (a table's
 * order is its library's: OCaml's and tiny-ml's are others) *)
let most (a, n) (b, m) = if n <> m then compare m n else compare a b
let sorted tbl = List.sort most (Hashtbl.fold (fun k n acc -> (k, n) :: acc) tbl [])

(*****************************************************************************)
(* The main *)
(*****************************************************************************)

(* the command line: the rows shown, the profile taken off (-diff), the
 * program's base (-base), the profile, the kernel's maps (-k) and the
 * program's (-u) *)
type options = {
  top : int; diff : Fpath.t option; named : M.address option;
  profile : Fpath.t; kmaps : Fpath.t list; umaps : Fpath.t list;
}

let rec options (o : options) args : options option =
  match args with
  | "-n" :: n :: rest -> options { o with top = int_of_string n } rest
  | "-diff" :: f :: rest -> options { o with diff = Some (Fpath.v f) } rest
  | "-base" :: b :: rest ->
      options { o with named = Some (int_of_string ("0x" ^ b)) } rest
  | file :: rest when file.[0] <> '-' ->
      (* the files after -k are the kernel's, after -u the program's *)
      let rec files k u kernel l =
        match l with
        | "-k" :: rest -> files k u true rest
        | "-u" :: rest -> files k u false rest
        | f :: rest ->
            if kernel then files (f :: k) u kernel rest
            else files k (f :: u) kernel rest
        | [] -> Fpath_.of_strings (List.rev k), Fpath_.of_strings (List.rev u) in
      let kmaps, umaps = files [] [] false rest in
      Some { o with profile = Fpath.v file; kmaps = kmaps; umaps = umaps }
  | _ -> None

let main (caps : < Cap.stdout; Cap.stderr; Cap.open_in; .. >)
    (argv : string array) : Exit.t =
  let print = TSys.print caps in
  let defaults = { top = 20; diff = None; named = None; profile = Fpath.v ".";
               kmaps = []; umaps = [] } in
  match options defaults (List.tl (Array.to_list argv)) with
  | None -> TSys.eprint caps (usage ^ "\n"); Exit.Code 2
  | Some o ->
      let counts = read_profile caps o.profile in
      Option.iter (fun f -> subtract counts (read_profile caps f)) o.diff;
      (* the totals: the kernel's, and each program's by its window's base *)
      let kernel = ref 0 and programs = Hashtbl.create 8 in
      Hashtbl.iter (fun (k : spot) n ->
        match k.space with
        | Kernel -> kernel := !kernel + n
        | User -> add programs k.base n) counts;
      let user = Hashtbl.fold (fun _ n acc -> acc + n) programs 0 in
      let total = !kernel + user in
      (* the program -u names: -base's, else the one that ran most *)
      let named = match o.named with
        | Some b -> b
        | None ->
            fst (Hashtbl.fold (fun b n (bb, bn) ->
                if n > bn || (n = bn && b < bb) then (b, n) else (bb, bn))
              programs (0, -1)) in
      let kfuncs = functions caps o.kmaps and ufuncs = functions caps o.umaps in
      (* each count to its function *)
      let by = Hashtbl.create 256 in
      Hashtbl.iter (fun (k : spot) n ->
        let name =
          match k.space with
          | Kernel -> if o.kmaps = [] then "(the kernel)" else find kfuncs k.pc
          | User when k.base <> named -> "(another program)"
          | User -> if o.umaps = [] then "(the program)" else find ufuncs k.pc in
        add by (k.space, name) n) counts;
      print (Printf.sprintf "%s instructions: the kernel %s%%, programs %s%%\n"
        (commas total) (percent !kernel total) (percent user total));
      let ran = List.filter (fun (_, n) -> n > 0) (sorted programs) in
      if List.length ran > 1 then
        print (Printf.sprintf
          "programs, by their window's base: %s (-u is the one at %x)\n"
          (String.concat ", "
             (List.map (fun (b, n) -> Printf.sprintf "%x %s" b (commas n)) ran))
          named);
      print (Printf.sprintf "%12s %6s     function\n" "count" "%");
      List.iteri (fun i ((space, name), n) ->
        if i < o.top && n > 0 then
          print (Printf.sprintf "%12s %6s  %s  %s\n" (commas n)
            (percent n total) (letter space) name)) (sorted by);
      Exit.OK

let () = TSys.main "tiny-prof" main
