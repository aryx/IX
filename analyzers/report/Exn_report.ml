(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Exn_report.mli *)

module D = Datalog

let name = C_report.name
let prefix = C_report.prefix

(* an exception as written: Main.Empty, Not_found (caml_exn_Not_found) *)
let exn (e : string) : string =
  match prefix "caml_exn_" e with Some x -> x | None -> if e = "?" then "an exception not known" else e

(* Main:11:r6: Main.ml:11 *)
let site (r : string) : string =
  match String.split_on_char ':' r with
  | u :: l :: _ ->
      let file = match Hashtbl.find_opt Ml_front.files u with Some f -> Filename.basename f | None -> u ^ ".ml" in
      file ^ ":" ^ l
  | _ -> r

(* Main:init, Main.trap, Main:try2@67: Main *)
let unit_of (f : string) : string =
  let n = String.length f in
  let rec go i =
    if i >= n || f.[i] = ':' || f.[i] = '.' then String.sub f 0 i
    else go (i + 1) in
  go 0

(* Main:try2@67: 67 *)
let try_line (t : string) : string =
  match String.index_opt t '@' with
  | Some i -> String.sub t (i + 1) (String.length t - i - 1)
  | None -> "?"

let find (h : (string, string) Hashtbl.t) (k : string) (default : string) =
  match Hashtbl.find_opt h k with Some v -> v | None -> default

let exn_report (caps : < Cap.stdout; .. >) (p : D.t) : unit =
  let tuples r =
    List.map (fun (t : int array) -> Array.map (name p) t)
      (D.tuples (D.relation p r 2)) in
  let table (r : string) : (string, string) Hashtbl.t =
    let h = Hashtbl.create 101 in
    List.iter (fun t -> Hashtbl.replace h t.(0) t.(1)) (tuples r);
    h in
  let inside = table "raise_in" and fn = table "try_in_function" in
  let raised = tuples "raised" in
  (* where e may be raised: Main.ml:11 (Main.first) *)
  let sites (e : string) : string list =
    List.sort_uniq compare
      (List.filter_map
         (fun r ->
           if r.(0) <> e then None
           else
             let g = match Hashtbl.find_opt inside r.(1) with
               | Some g -> " (" ^ Ml_report.ml_function g ^ ")"
               | None -> "" in
             Some (site r.(1) ^ g))
         raised) in
  (* who: of a toplevel, a function C calls (trap), a try (Main:try2@67) *)
  let report (rel : string) (who : string -> string -> string -> string) =
    List.iter
      (fun t ->
        let f = t.(0) and e = t.(1) in
        let u = unit_of f in
        if Hashtbl.mem Ml_front.own u then begin
          let file = match Hashtbl.find_opt Ml_front.files u with
            | Some x -> Filename.basename x
            | None -> u in
          let at = match sites e with
            | [] -> ""
            | l -> ", raised at " ^ String.concat ", " l in
          Console.print caps (who file f (exn e) ^ at ^ "\n")
        end)
      (List.sort_uniq compare (tuples rel)) in
  report "uncaught" (fun file _ e ->
      file ^ ": the toplevel may let " ^ e ^ " escape");
  report "from_c" (fun file f e ->
      Printf.sprintf "%s: %s, called from C, may let %s escape" file
        (Ml_report.ml_function f) e);
  report "ends_in" (fun file t e ->
      Printf.sprintf "%s:%s: the try in %s, its handler raising, may be reached by %s"
        file (try_line t) (Ml_report.ml_function (find fn t "?")) e)
