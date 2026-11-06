(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Caps_report.mli *)

module D = Datalog

let name = C_report.name
let prefix = C_report.prefix
let ml_function = Ml_report.ml_function

(* -caps: what capabilities.dl finds, a line a function: what it holds, what is
 * missing and by what, what it holds for nothing *)
let caps_report (caps : < Cap.stdout; .. >) (p : D.t) : unit =
  let tuples r n = List.map (fun (t : int array) -> Array.map (name p) t) (D.tuples (D.relation p r n)) in
  let file_of u = match Hashtbl.find_opt Ml_front.files u with Some f -> f | None -> u in
  let lines = Hashtbl.create 101 in
  List.iter (fun t -> Hashtbl.replace lines t.(0) (file_of t.(1), int_of_string t.(2))) (tuples "closure" 3);
  let at (o : string) : string * int =
    match Hashtbl.find_opt lines o with
    | Some w -> w
    | None -> (file_of (String.sub o 0 (String.index o ':')), 0) in
  let requires = tuples "requires" 2 in
  (* Cap.open_in|Cap.open_out: what allows S *)
  let need (s : string) : string =
    String.concat "|"
      (List.sort compare (List.filter_map (fun t -> if t.(0) = s then Some ("Cap." ^ t.(1)) else None) requires)) in
  let held (o : string) : string list =
    List.sort_uniq compare
      (List.filter_map (fun t -> if t.(0) = o then Some ("Cap." ^ t.(1)) else None) (tuples "declared_by" 2)) in
  (* one function's needs, each with the ways: Cap.stdout (Pervasives.print_string) *)
  let needs (r : string array list) (o : string) : string =
    let mine = List.filter (fun t -> t.(0) = o) r in
    let by_need =
      List.sort_uniq compare (List.map (fun t -> need t.(1)) mine)
      |> List.map (fun n ->
             let ways =
               List.sort_uniq compare
                 (List.filter_map
                    (fun t ->
                      if need t.(1) <> n then None
                      else if t.(2) <> "itself" then Some (ml_function t.(2))
                      else match prefix "prim:" t.(1) with Some x -> Some x | None -> Some t.(1))
                    mine) in
             Printf.sprintf "%s (%s)" n (String.concat ", " ways)) in
    String.concat ", " by_need in
  let functions r = List.sort_uniq compare (List.map (fun t -> t.(0)) r) in
  let none = tuples "no_cap" 3 and wrong = tuples "wrong_cap" 3 and unused = tuples "unused_cap" 2 in
  (* the system calls a function names itself (capabilities.dl's around) *)
  let around = tuples "around" 2 in
  let names_itself (o : string) : string list =
    List.sort_uniq compare
      (List.filter_map
         (fun t ->
           if t.(0) <> o then None
           else match prefix "prim:" t.(1) with Some x -> Some x | None -> Some t.(1))
         around) in
  (* a function a line *)
  let report =
    List.map
      (fun o ->
        let f, l = at o in
        let unneeded = List.sort compare (List.filter_map (fun t -> if t.(0) = o then Some ("Cap." ^ t.(1)) else None) unused) in
        let says =
          (if List.exists (fun t -> t.(0) = o) none then [ "no capability, needs " ^ needs none o ] else [])
          @ (if List.exists (fun t -> t.(0) = o) wrong then [ "needs " ^ needs wrong o ] else [])
          @ (if unneeded = [] then [] else [ "may not need " ^ String.concat ", " unneeded ])
          @ (match names_itself o with
             | [] -> []
             | l -> [ "names " ^ String.concat ", " l ^ " itself" ]) in
        let has = match held o with [] -> "" | h -> Printf.sprintf "has < %s >, " (String.concat "; " h) in
        (f, l, Printf.sprintf "%s: %s%s" (ml_function o) has (String.concat "; " says)))
      (functions
         (none @ wrong @ List.map (fun t -> [| t.(0) |]) unused
          @ List.map (fun t -> [| t.(0) |]) around)) in
  List.iter
    (fun (f, l, msg) -> Console.print caps (if l > 0 then Printf.sprintf "%s:%d: %s\n" f l msg else Printf.sprintf "%s: %s\n" f msg))
    (List.sort compare report);
  (* what is asked for most: where to start *)
  let counts = Hashtbl.create 17 in
  List.iter
    (fun t ->
      let n = need t.(1) in
      Hashtbl.replace counts n ((try Hashtbl.find counts n with Not_found -> []) @ [ t.(0) ]))
    (none @ wrong);
  let by_cap =
    Hashtbl.fold (fun n os acc -> (List.length (List.sort_uniq compare os), n) :: acc) counts []
    |> List.sort (fun a b -> compare b a)
    |> List.map (fun (k, n) -> Printf.sprintf "%s %d" n k) in
  Console.print caps
    (Printf.sprintf "%d functions with no capability, %d with the wrong one, %d with one they may not need, %d naming a system call themselves%s\n"
       (List.length (functions none)) (List.length (functions wrong)) (List.length (functions unused))
       (List.length (functions around))
       (if by_cap = [] then "" else "; missing: " ^ String.concat ", " by_cap))
