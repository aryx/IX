(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Build.mli *)

open Common

type flags = [%mli]

type io = [%mli]

type status = Notmade | Beingmade | Made

type t = {
  mk : Mkfile.t;
  g : Graph.t;
  io : io;
  flags : flags;
  ood : Outofdate.ctx;
  times : (string, float) Hashtbl.t;     (* date stamps, once changed *)
  status : (string, status) Hashtbl.t;
  queue : Recipe.job Queue.t;
  mutable slots : (int * Recipe.job) option array;
  mutable running : int;
  mutable errors : int;
  mutable busy : float array;             (* -u: time with n jobs running *)
  mutable tick : float;
  (* -p: when each running job started (by its pid), the seconds the
   * job of each target took, when the first one started, and the
   * targets asked *)
  starts : (int, float) Hashtbl.t;
  spent : (string, float) Hashtbl.t;
  mutable first : float;
  mutable jobs : int;
  mutable total : float;
  mutable roots : Graph.node list;
  (* -p's: the walks of the graph from a root (make's loop), and the
   * arcs they looked at *)
  mutable walks : int;
  mutable arcs : int;
  (* the walk a node was last looked at in, not made (work) *)
  waiting : (string, int) Hashtbl.t;
}

exception Failed

let time_of (g : Graph.t) times name =
  match Hashtbl.find_opt times name with
  | Some x -> x
  | None -> (match Graph.find g name with Some n -> n.time | None -> 0.)

let create ~hashes mk g io flags =
  let times = Hashtbl.create 101 in
  { mk; g; io; flags; times;
    ood = Outofdate.create ~hashes ~time:(time_of g times) ~prog:io.prog ();
    status = Hashtbl.create 101; queue = Queue.create (); slots = [| None |];
    running = 0; errors = 0; busy = [| 0.; 0. |]; tick = 0.;
    starts = Hashtbl.create 17; spent = Hashtbl.create 101; first = 0.; jobs = 0; total = 0.; roots = []; walks = 0; arcs = 0; waiting = Hashtbl.create 101 }

let time t name = time_of t.g t.times name
let status t (n : Graph.node) = Hashtbl.find_opt t.status n.name ||| Notmade
let set_status t (n : Graph.node) s = Hashtbl.replace t.status n.name s
let out_of_date t n a p = Outofdate.arc ~eval:false t.ood n a p

(* run.c's usage(): account for the time since the last change *)
let account t =
  let now = t.io.now () in
  if t.tick > 0. then t.busy.(t.running) <- t.busy.(t.running) +. (now -. t.tick);
  t.tick <- now

(*****************************************************************************)
(* Jobs *)
(*****************************************************************************)

(* mk.c's update(): a job's target is made (or, if it failed, stays
 * being made forever), with its new date stamp *)
let update t (n : Graph.node) ~failed =
  set_status t n (if failed then Beingmade else Made);
  Hashtbl.replace t.times n.name
    (Outofdate.after_recipe t.ood ~exists:t.io.exists ~stat:t.io.stat n)

let touch t (n : Graph.node) =
  if not n.virtual_ then begin
    t.io.print (Printf.sprintf "touch(%s)\n" n.name);
    if not t.flags.dry then t.io.touch n.name
  end
  else if t.flags.explain then t.io.print (Printf.sprintf "no touch of virtual '%s'\n" n.name)

let printed t (j : Recipe.job) ~slot =
  let env = Recipe.env t.mk ~job:(Some j) ~slot ~pid:t.io.pid () in
  env, Recipe.shprint t.mk env ~quoting:(Word.quoting_of_shell j.rule.shell) j.rule.recipe

(* run.c's sched(): start the next queued job in a free slot *)
let sched t =
  match Queue.take_opt t.queue with
  | None -> ()
  | Some j ->
      let rec free i = if t.slots.(i) = None then i else free (i + 1) in
      let slot = free 0 in
      let env, text = printed t j ~slot in
      if (not t.flags.touch) && (t.flags.dry || not j.rule.attrs.quiet) then t.io.print text;
      if t.flags.dry || t.flags.touch then
        j.nodes |> List.iter (fun n ->
          if t.flags.touch then touch t n;
          Hashtbl.replace t.times n.name (t.io.now ());
          set_status t n Made)
      else begin
        account t;
        let pid = t.io.run j ~slot ~env in
        t.slots.(slot) <- Some (pid, j);
        Hashtbl.replace t.starts pid t.tick;
        if t.first = 0. then t.first <- t.tick;
        t.running <- t.running + 1
      end

let run t (j : Recipe.job) =
  Queue.push j t.queue;
  if t.running < Array.length t.slots then sched t

(* run.c's waitup(): a job ended; false if there was none to wait for *)
let rec waitup t : bool =
  match t.io.wait () with
  | None -> false
  | Some (pid, ended) -> (
      let rec find i =
        if i >= Array.length t.slots then None
        else match t.slots.(i) with
          | Some (p, j) when p = pid -> Some (i, j)
          | _ -> find (i + 1)
      in
      match find 0 with
      | None -> waitup t   (* not one of ours *)
      | Some (slot, j) ->
          account t;
          t.slots.(slot) <- None;
          t.running <- t.running - 1;
          (match Hashtbl.find_opt t.starts pid with
           | Some at ->
               t.jobs <- t.jobs + 1;
               t.total <- t.total +. (t.tick -. at);
               j.nodes |> List.iter (fun (n : Graph.node) -> Hashtbl.replace t.spent n.name (t.tick -. at))
           | None -> ());
          (match ended with
          | Succeeded -> ()
          | Exit_status why ->
              let _, text = printed t j ~slot in
              let b = Buffer.create 80 in
              Printf.bprintf b "mk: %s: exit status=%s" (Recipe.front text) why;
              let deleted = List.filter (fun (n : Graph.node) -> n.delete) j.nodes in
              if deleted <> [] then Buffer.add_string b ", deleting";
              deleted |> List.iter (fun (n : Graph.node) ->
                Printf.bprintf b " '%s'" n.name;
                t.io.delete n.name);
              t.io.eprint (Buffer.contents b ^ "\n");
              if t.flags.keep_going then t.errors <- t.errors + 1
              else (Queue.clear t.queue; raise Failed));
          j.targets |> List.iter (fun name ->
            Option.iter (fun n -> update t n ~failed:(ended <> Succeeded)) (Graph.find t.g name));
          if t.running < Array.length t.slots then sched t;
          true)

(*****************************************************************************)
(* Main algorithm *)
(*****************************************************************************)

(* recipe.c's dorecipe(): queue the job that makes [node] *)
let dorecipe t did (node : Graph.node) =
  let master =
    List.fold_left (fun m (a : Graph.arc) -> if a.rule.recipe <> "" then Some a else m)
      None node.arcs
  in
  match master with
  | None ->
      if node.virtual_ || node.norecipe then begin
        if String.contains node.name '(' && time t node.name = 0. then set_status t node Made
        else update t node ~failed:false;
        if t.flags.touch then touch t node
      end else begin
        t.io.eprint (Printf.sprintf "mk: no recipe to make '%s'\n" node.name);
        raise Failed
      end
  | Some ma ->
      let r = ma.rule in
      (* the rule's other targets that are in the graph and out of date
       * are made by the same job *)
      let nodes, targets, alltargets =
        match ma.stems with
        | Groups _ -> [ node ], [ node.name ], [ node.name ]
        | Exact | Stem _ ->
            let all = List.map (Pattern.subst ma.stems) r.alltargets in
            let others = ref [] and olds = ref [] in
            all |> List.iter (fun tg ->
              match Graph.find t.g tg with
              | None -> ()
              | Some n ->
                  let up_to_date =
                    (not t.flags.always) && time t n.name <> 0.
                    && not (List.exists (fun (a : Graph.arc) ->
                      match a.prereq with Some p -> out_of_date t n a p | None -> false) n.arcs)
                  in
                  if not up_to_date then begin
                    olds := tg :: !olds;
                    if n.name <> node.name then others := n :: !others
                  end);
            node :: !others, List.rev !olds, all
      in
      let prereqs = ref [] and newprereqs = ref [] in
      let add l x = if not (List.mem x !l) then l := x :: !l in
      nodes |> List.iter (fun (n : Graph.node) ->
        n.arcs |> List.iter (fun (a : Graph.arc) ->
          match a.prereq with
          | Some p ->
              add prereqs p.name;
              if out_of_date t n a p then begin
                add newprereqs p.name;
                if t.flags.explain then
                  t.io.print (Printf.sprintf "%s(%.4f) < %s(%.4f)\n"
                                n.name (time t n.name) p.name (time t p.name))
              end
          | None ->
              if t.flags.explain then
                t.io.print (Printf.sprintf "%s has no prerequisites\n" n.name));
        set_status t n Beingmade);
      run t { Recipe.rule = r; stems = ma.stems; targets; alltargets;
              prereqs = List.rev !prereqs; newprereqs = List.rev !newprereqs; nodes };
      did := true

(* mk.c's work(), without the pretending of missing intermediates
 * (principia's default, as -i) *)
(* opti: a node looked at in this walk and left not made is not looked
 * at again in it, by another of its targets: nothing ends between two
 * walks' ends, so it would be found as it was (and when the walk did
 * something, a job queued, or a node made by -n, make's loop walks
 * again). A directory's units name each other (.depend) and all wait
 * for the generated ones: each was walked again through every path to
 * it, as a tree. editors/emacs/draw on mini-9pi: 108 walks, 46 million
 * arcs, 2.6 s of mk's own after each job, on the core the job runs on;
 * its 74 recipes took 268 s for 104 s of compiles and a link
 * (2026-11-20). The same here with recipes that do nothing: 8,177 arcs,
 * the units made as soon as asked.
 * old: if status t node = Notmade then, alone *)
let rec work t did (node : Graph.node) =
  if status t node = Notmade && Hashtbl.find_opt t.waiting node.name <> Some t.walks then begin
    Hashtbl.replace t.waiting node.name t.walks;
    if node.arcs = [] then begin
      if time t node.name = 0. then begin
        t.io.eprint (Printf.sprintf "mk: don't know how to make '%s' in %s\n" node.name t.io.cwd);
        if t.flags.keep_going then (set_status t node Beingmade; t.errors <- t.errors + 1)
        else raise Failed
      end
      else set_status t node Made
    end
    else begin
      let outofdate = ref t.flags.always and ready = ref true in
      node.arcs |> List.iter (fun (a : Graph.arc) ->
        t.arcs <- t.arcs + 1;
        match a.prereq with
        | Some p ->
            work t did p;
            if status t p <> Made then ready := false;
            if out_of_date t node a p then outofdate := true
        | None -> if time t node.name = 0. then outofdate := true);
      if !ready then
        if !outofdate then dorecipe t did node
        else (Outofdate.up_to_date t.ood node; set_status t node Made)
    end
  end

let make t ~nproc ~nrep target =
  let nproc = max 1 nproc in
  if nproc > Array.length t.slots then begin
    t.slots <- Array.init nproc (fun i -> if i < Array.length t.slots then t.slots.(i) else None);
    t.busy <- Array.init (nproc + 1) (fun i -> if i < Array.length t.busy then t.busy.(i) else 0.)
  end;
  let root = Graph.node t.g ~nrep target in
  t.roots <- root :: t.roots;
  (* mk.c's clrmade(): everything under the target is to be made again;
   * and graph.c's attribute(), which runs for every target, puts a
   * virtual node's time back to 0 *)
  let seen = Hashtbl.create 101 in
  let rec clear (n : Graph.node) =
    if not (Hashtbl.mem seen n.name) then begin
      Hashtbl.replace seen n.name ();
      set_status t n Notmade;
      if n.virtual_ then Hashtbl.replace t.times n.name 0.;
      n.arcs |> List.iter (fun (a : Graph.arc) -> Option.iter clear a.prereq)
    end
  in
  clear root;
  let everdid = ref false in
  let rec loop () =
    if status t root = Notmade then begin
      let did = ref false in
      t.walks <- t.walks + 1;
      work t did root;
      if !did then (everdid := true; loop ())
      else if waitup t || status t root = Made then loop ()
    end
  in
  loop ();
  if status t root = Beingmade then ignore (waitup t);
  while not (Queue.is_empty t.queue) do ignore (waitup t) done;
  if not !everdid then t.io.print (Printf.sprintf "mk: '%s' is up to date\n" root.name)

let wait_all t =
  while t.running > 0 && waitup t do () done

let errors t = t.errors

let usage t =
  account t;
  String.concat "" (Array.to_list (Array.mapi (fun i s -> Printf.sprintf "%d: %.0f\n" i s) t.busy))

(* -p. The critical path is the chain of recipes, each waiting for the
 * one before it (a prerequisite's), whose times add up to the most: no
 * $NPROC makes the build shorter than that chain plus what mk did
 * before its first recipe, and the recipes' sum over the time they
 * ran in says how many ran at once. A target's end is its own
 * recipe's time after the latest end among its prerequisites. *)
let profile t ~start =
  account t;
  let ends : (string, float * Graph.node option) Hashtbl.t = Hashtbl.create 101 in
  let rec end_of (n : Graph.node) =
    match Hashtbl.find_opt ends n.name with
    | Some e -> e
    | None ->
        (* (a cycle's node, met again: nothing more) *)
        Hashtbl.replace ends n.name (0., None);
        let before = List.fold_left (fun (best, by) (a : Graph.arc) ->
          match a.prereq with
          | Some p -> let e, _ = end_of p in if e > best then e, Some p else best, by
          | None -> best, by) (0., None) n.arcs in
        let e = (Hashtbl.find_opt t.spent n.name ||| 0.) +. fst before, snd before in
        Hashtbl.replace ends n.name e;
        e in
  let root = List.fold_left (fun best n -> match best with
    | Some b when fst (end_of b) >= fst (end_of n) -> best
    | _ -> Some n) None t.roots in
  (* (a target met again, an archive and its member: the chain ends) *)
  let rec chain (n : Graph.node) acc =
    if List.mem_assoc n.name acc then acc
    else
      let acc = match Hashtbl.find_opt t.spent n.name with Some s -> (n.name, s) :: acc | None -> acc in
      match snd (end_of n) with Some p -> chain p acc | None -> acc in
  let path = match root with Some r -> chain r [] | None -> [] in
  let all = t.tick -. start in
  let before = if t.first = 0. then all else t.first -. start in
  let ran = if t.first = 0. then 0. else t.tick -. t.first in
  let b = Buffer.create 256 in
  Printf.bprintf b "mk: %.1f s: %.1f s before the first recipe, then %d recipes of %.1f s in all in %.1f s, %.1f at once\n"
    all before t.jobs t.total ran (if ran > 0. then t.total /. ran else 0.);
  Printf.bprintf b "mk: %d walks of the graph, %d arcs looked at\n" t.walks t.arcs;
  Printf.bprintf b "mk: the critical path, %.1f s of them:\n" (List.fold_left (fun acc (_, s) -> acc +. s) 0. path);
  List.iter (fun (name, s) -> Printf.bprintf b "%8.1f  %s\n" s name) path;
  (* (and the longest recipes, whatever path they are on: a recipe far
   * longer than the tool it runs is seen here, where the tools' own
   * times, TIMES=time, add up to less: editors/emacs/draw's 280 s for
   * 104 of its compiles and its link, 2026-11-20) *)
  let longest = List.sort (fun (_, x) (_, y) -> compare y x) (Hashtbl.fold (fun name s acc -> (name, s) :: acc) t.spent []) in
  Printf.bprintf b "mk: the longest recipes:\n";
  List.iteri (fun i (name, s) -> if i < 8 then Printf.bprintf b "%8.1f  %s\n" s name) longest;
  Buffer.contents b
