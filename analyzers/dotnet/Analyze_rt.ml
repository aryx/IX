(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Analyze_rt.mli *)

module D = Datalog

(* a fact as Facts finds it: a tuple of symbols, bugs.dl's kinds of its
 * places (C_report's, the native mini-analyze's) *)
let given = C_report.given

(* an option of one word: -Idir, -Ldir *)
let flag (pre : string) (a : string) : string option =
  if String.length a > 2 && String.sub a 0 2 = pre then Some (String.sub a 2 (String.length a - 2)) else None

let main (texts : string array) (queries : string array) (rules : D.t -> unit) : unit =
  Cap.main (fun (caps : Cap.all_caps) ->
      let argv = CapSys.argv caps in
      (* (-I dir and -L dir as mini-analyze's, two words: made one) *)
      let rec joined (l : string list) =
        match l with
        | (("-I" | "-L") as o) :: d :: rest -> (o ^ d) :: joined rest
        | a :: rest -> a :: joined rest
        | [] -> [] in
      let args = joined (Array.to_list (Array.sub argv 1 (Array.length argv - 1))) in
      let path (f : string) = match FS.path f with Ok p -> p | Error m -> failwith m in
      let incs = List.map path (List.filter_map (flag "-I") args) in
      let lib = match List.filter_map (flag "-L") args with l :: _ -> l | [] -> "lib_core" in
      let dead = List.mem "-dead" args and ambient = List.mem "-caps" args in
      let fingerprint = List.mem "-fingerprint" args in
      let files =
        List.filter
          (fun (a : string) -> flag "-I" a = None && flag "-L" a = None && not (List.mem a [ "-dead"; "-caps"; "-fingerprint" ]))
          args in
      let p = D.create () in
      let failed = ref 0 in
      let complain (m : string) = Console.eprint caps (m ^ "\n"); incr failed in
      (try
         for i = 0 to (Array.length texts / 2) - 1 do
           D.load p ~from:texts.(2 * i) texts.((2 * i) + 1)
         done;
         Facts.added := given p;
         (* (ML's facts the same: mini-analyze's Closure_facts.added) *)
         Closure_facts.added :=
           (fun (r : string) (args : Closure_facts.arg list) ->
             given p r
               (List.map
                  (fun (a : Closure_facts.arg) ->
                    match a with Closure_facts.Sym s -> Facts.Sym s | Closure_facts.Num n -> Facts.Num n)
                  args));
         let ml = List.filter (fun (f : string) -> Filename.check_suffix f ".ml") files in
         List.iter
           (fun (f : string) ->
             if Filename.check_suffix f ".c" then
               (match C_front.file caps ([], incs) (path f) with Ok () -> () | Error m -> complain m)
             else if Filename.check_suffix f ".ml" then ()
             else
               match FS.read_opt caps (path f) with
               | Some text -> D.load p ~from:f text
               | None -> complain (f ^ ": cannot be read"))
           files;
         (* an ML program: its units and the library's they name *)
         if ml <> [] then
           List.iter complain (Ml_front.program caps (incs @ Ml_front.library caps lib) (List.map path ml));
         (* (-caps: the program's own units and their toplevels, as
          * mini-analyze gives them) *)
         if ambient then
           Hashtbl.iter
             (fun (u : string) () -> given p "own_unit" [ Facts.Sym u ]; given p "own_init" [ Facts.Sym (u ^ ":init") ])
             Ml_front.own;
         rules p;
         (* (no query: mini-analyze's reports, C's then ML's) *)
         if queries <> [||] then Datalog_rt.answers caps p queries
         else if ambient then Caps_report.caps_report caps p
         else if dead then Dead_report.dead_report caps p (ml <> [])
         else begin
           if List.exists (fun (f : string) -> Filename.check_suffix f ".c") files then C_report.report caps p;
           if ml <> [] then Ml_report.ml_report caps p
         end;
         if fingerprint then Console.print caps ("fingerprint of the answers: " ^ Answers.hex (Answers.fingerprint p) ^ "\n")
       with
       | D.Error (msg, at) -> complain (at ^ ": " ^ msg)
       | Failure m -> complain m);
      flush (Console.stdout caps);
      if !failed > 0 then CapStdlib.exit caps 1)
