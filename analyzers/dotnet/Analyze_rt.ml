(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Analyze_rt.mli *)

module D = Datalog

(* a fact as Facts finds it: a tuple of symbols (mini-analyze's given,
 * without bugs.dl's kinds of places) *)
let given (p : D.t) (relation : string) (args : Facts.arg list) : unit =
  let r = D.relation p relation (List.length args) in
  let value (a : Facts.arg) =
    match a with Facts.Sym s -> D.symbol p (Prolog.Atom s) | Facts.Num n -> D.symbol p (Prolog.Int n) in
  if D.add r (Array.of_list (List.map value args)) then r.given <- r.given + 1

let main (texts : string array) (queries : string array) (rules : D.t -> unit) : unit =
  Cap.main (fun (caps : Cap.all_caps) ->
      let argv = CapSys.argv caps in
      let args = Array.to_list (Array.sub argv 1 (Array.length argv - 1)) in
      let incs, files =
        List.partition (fun (a : string) -> String.length a > 2 && String.sub a 0 2 = "-I") args in
      let path (f : string) = match FS.path f with Ok p -> p | Error m -> failwith m in
      let incs = List.map (fun (a : string) -> path (String.sub a 2 (String.length a - 2))) incs in
      let p = D.create () in
      let failed = ref 0 in
      let complain (m : string) = Console.eprint caps (m ^ "\n"); incr failed in
      (try
         for i = 0 to (Array.length texts / 2) - 1 do
           D.load p ~from:texts.(2 * i) texts.((2 * i) + 1)
         done;
         Facts.added := given p;
         List.iter
           (fun (f : string) ->
             if Filename.check_suffix f ".c" then
               (match C_front.file caps ([], incs) (path f) with Ok () -> () | Error m -> complain m)
             else
               match FS.read_opt caps (path f) with
               | Some text -> D.load p ~from:f text
               | None -> complain (f ^ ": cannot be read"))
           files;
         rules p;
         Datalog_rt.answers caps p queries
       with
       | D.Error (msg, at) -> complain (at ^ ": " ^ msg)
       | Failure m -> complain m);
      flush (Console.stdout caps);
      if !failed > 0 then CapStdlib.exit caps 1)
