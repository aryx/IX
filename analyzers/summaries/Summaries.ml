(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Summaries.mli *)

type op = Models.op =
  | New of Models.v
  | Load of Models.v * Models.v * string
  | Store of Models.v * string * Models.v
  | Assign of Models.v * Models.v
  | Scalar of Models.v
  | Call of Models.v * Models.v * Models.v
  | Raise of string
  | Global of Models.v * string
type fact = string * string list

(* ---- the facts' text: rel('a', 'b\'', 3). *)

let parse_line (l : string) : fact option =
  match String.index_opt l '(' with
  | None -> None
  | Some p ->
      let rel = String.sub l 0 p in
      let n = String.length l in
      let args = ref [] and b = Buffer.create 32 in
      let i = ref (p + 1) in
      while !i < n && l.[!i] <> ')' do
        (match l.[!i] with
         | '\'' ->
             incr i;
             while !i < n && l.[!i] <> '\'' do
               if l.[!i] = '\\' && !i + 1 < n then incr i;
               Buffer.add_char b l.[!i]; incr i
             done;
             incr i
         | c when (c >= '0' && c <= '9') || c = '-' ->
             while !i < n && l.[!i] <> ',' && l.[!i] <> ')' do
               Buffer.add_char b l.[!i]; incr i
             done
         | _ -> incr i);
        if Buffer.length b > 0 || (!i > 0 && l.[!i - 1] = '\'') then begin
          args := Buffer.contents b :: !args; Buffer.clear b end;
        while !i < n && (l.[!i] = ',' || l.[!i] = ' ') do incr i done
      done;
      Some (rel, List.rev !args)

let parse (text : string) : fact list =
  List.filter_map parse_line (String.split_on_char '\n' text)

(* ---- the facts by relation, by their first atom *)

type index = (string, string list list) Hashtbl.t

let index (facts : fact list) : (string, index) Hashtbl.t =
  let t = Hashtbl.create 64 in
  List.iter
    (fun ((r, args) : fact) ->
      match args with
      | [] -> ()
      | a :: _ ->
          let ix =
            match Hashtbl.find_opt t r with
            | Some ix -> ix
            | None -> let ix = Hashtbl.create 1024 in Hashtbl.replace t r ix; ix in
          Hashtbl.replace ix a (args :: (try Hashtbl.find ix a with Not_found -> [])))
    facts;
  t

let rows (t : (string, index) Hashtbl.t) (r : string) (a : string) : string list list =
  match Hashtbl.find_opt t r with
  | Some ix -> (try Hashtbl.find ix a with Not_found -> [])
  | None -> []

let all (t : (string, index) Hashtbl.t) (r : string) : string list list =
  match Hashtbl.find_opt t r with
  | Some ix -> Hashtbl.fold (fun _ l acc -> l @ acc) ix []
  | None -> []

exception Not_summarized of string

let rec derive ~(units : string list) (facts : fact list) :
    (string * (int * op list, string) result) list =
  let t = index facts in
  let globals = Hashtbl.create 1024 in
  List.iter (function [ g ] -> Hashtbl.replace globals g () | _ -> ()) (all t "global_var");
  let is_global g = Hashtbl.mem globals g in
  (* who is inside whom; every variable's functions; every call's *)
  let children = Hashtbl.create 1024 in
  List.iter (function [ g; x ] -> Hashtbl.add children x g | _ -> ()) (all t "inner");
  let next_stage = Hashtbl.create 1024 in
  List.iter (function [ g; x ] -> Hashtbl.replace next_stage x g | _ -> ()) (all t "curried");
  let vars_of = Hashtbl.create 4096 and funs_of_var = Hashtbl.create 65536 in
  List.iter
    (function
      | [ v; x ] -> Hashtbl.add vars_of x v; Hashtbl.add funs_of_var v x
      | _ -> ())
    (all t "var_in");
  let calls_of = Hashtbl.create 4096 in
  List.iter (function [ i; x ] -> Hashtbl.add calls_of x i | _ -> ()) (all t "in_function");
  let raises_of = Hashtbl.create 1024 in
  List.iter (function [ i; x ] -> Hashtbl.add raises_of x i | _ -> ()) (all t "raise_in");
  let tries = Hashtbl.create 64 in
  List.iter (function x :: _ -> Hashtbl.replace tries x () | _ -> ()) (all t "try_in_function");
  let one r a = match rows t r a with x :: _ -> Some x | [] -> None in
  let param x = match one "parameter" x with Some [ _; _; p ] -> Some p | _ -> None in
  let result x = match one "return" x with Some [ _; r ] -> Some r | _ -> None in
  (* a root: a unit's toplevel function, its global of the same name *)
  let roots =
    List.filter_map
      (function
        | [ f; u; _ ] when List.mem u units && is_global f -> Some f
        | _ -> None)
      (all t "closure") in
  let summarize (f : string) : int * op list =
    (* the tree: f, its stages, every function inside *)
    let tree = Hashtbl.create 16 in
    (* (and a closure one of its variables is given that is no unit's
     * toplevel: a local let rec, a lambda, inner does not say them all) *)
    let rec add x =
      if not (Hashtbl.mem tree x) then begin
        Hashtbl.replace tree x ();
        List.iter add (Hashtbl.find_all children x);
        List.iter
          (fun v ->
            List.iter
              (function
                | [ _; g ] when rows t "closure" g <> [] && not (is_global g) -> add g
                | _ -> ())
              (rows t "assign_address" v))
          (Hashtbl.find_all vars_of x)
      end in
    add f;
    let in_tree x = Hashtbl.mem tree x in
    Hashtbl.iter (fun x () -> if Hashtbl.mem tries x then raise (Not_summarized "a try")) tree;
    let rec chain x = x :: (match Hashtbl.find_opt next_stage x with Some y -> chain y | None -> []) in
    let stages = chain f in
    let n = List.length stages in
    (* its variables, each a Tmp; a global read, a Tmp its Global holds *)
    let tmps = Hashtbl.create 64 and count = ref 0 in
    let ops = ref [] in
    let emit o = ops := o :: !ops in
    let tmp (v : string) : Models.v =
      match Hashtbl.find_opt tmps v with
      | Some k -> Models.Tmp k
      | None ->
          incr count; Hashtbl.replace tmps v !count;
          if is_global v then emit (Global (Models.Tmp !count, v));
          Models.Tmp !count in
    let vars = Hashtbl.create 64 in
    Hashtbl.iter
      (fun x () -> List.iter (fun v -> Hashtbl.replace vars v ()) (Hashtbl.find_all vars_of x))
      tree;
    let mine v = Hashtbl.mem vars v && not (is_global v) in
    (* (a variable of the tree alone: one of the toplevel's too is the
     * closure's place, init's, not the tree's) *)
    let only_mine v =
      mine v && List.for_all in_tree (Hashtbl.find_all funs_of_var v) in
    (* the parameters, copied; the result *)
    List.iteri
      (fun i x -> match param x with
        | Some p -> emit (Assign (tmp p, Arg (i + 1)))
        | None -> ())
      stages;
    (match result (List.nth stages (n - 1)) with
     | Some r -> emit (Assign (Ret, tmp r))
     | None -> ());
    (* the closures of the tree a variable may hold *)
    let holds : (string, string list) Hashtbl.t = Hashtbl.create 64 in
    let get v = try Hashtbl.find holds v with Not_found -> [] in
    let changed = ref true in
    let flow d s =
      let hs = get s in
      if hs <> [] then begin
        let hd = get d in
        let nw = List.filter (fun g -> not (List.mem g hd)) hs in
        if nw <> [] then begin Hashtbl.replace holds d (nw @ hd); changed := true end
      end in
    let calls = Hashtbl.fold (fun x () acc -> Hashtbl.find_all calls_of x @ acc) tree [] in
    let target i = match one "call_indirect" i with Some [ _; v ] -> Some v | _ -> None in
    let arg i = List.find_map (function [ _; "1"; a ] -> Some a | _ -> None) (rows t "argument" i) in
    let ret i = match one "call_ret" i with Some [ _; r ] -> Some r | _ -> None in
    Hashtbl.iter
      (fun v () ->
        List.iter
          (function [ _; g ] when in_tree g -> Hashtbl.replace holds v (g :: get v) | _ -> ())
          (rows t "assign_address" v))
      vars;
    while !changed do
      changed := false;
      Hashtbl.iter
        (fun d () -> List.iter (function [ _; s ] -> flow d s | _ -> ()) (rows t "assign" d))
        vars;
      List.iter
        (fun i ->
          match target i with
          | Some v ->
              List.iter
                (fun g ->
                  (match param g, arg i with Some p, Some a -> flow p a | _ -> ());
                  match result g, ret i with Some r', Some r -> flow r r' | _ -> ())
                (get v)
          | None -> ())
        calls
    done;
    (* each fact of a variable of the tree, an op *)
    Hashtbl.iter
      (fun v () ->
        if mine v then begin
          List.iter
            (function
              | [ _; s ] -> emit (Assign (tmp v, tmp s))
              | _ -> ())
            (rows t "assign" v);
          List.iter
            (function
              | [ _; g ] when in_tree g -> ()
              | [ _; g ] when String.length g > 5 && String.sub g 0 5 = "prim:" -> ()
              | [ _; g ] when is_global g -> emit (Global (tmp v, g))
              | [ _; g ] -> raise (Not_summarized ("a closure of another tree: " ^ g))
              | _ -> ())
            (rows t "assign_address" v);
          List.iter
            (function [ _; s; fld ] -> emit (Load (tmp v, tmp s, fld)) | _ -> ())
            (rows t "assign_load_field" v);
          List.iter
            (function [ _; fld; s ] -> emit (Store (tmp v, fld, tmp s)) | _ -> ())
            (rows t "assign_store_field" v);
          if rows t "new_block" v <> [] then emit (New (tmp v));
          if rows t "scalar" v <> [] then emit (Scalar (tmp v))
        end
        else if v = "exn" then ()
          (* (the exception a raise puts there: raise_of's Raise says it) *)
        else if is_global v then begin
          (* a global written in the tree: its body kept *)
          List.iter
            (function [ _; s ] when only_mine s -> raise (Not_summarized ("a global written: " ^ v)) | _ -> ())
            (rows t "assign" v);
          if rows t "assign_store_field" v <> [] then
            raise (Not_summarized ("a global's field written: " ^ v))
        end)
      vars;
    (* the calls: inside the tree its parameters and result, else a Call *)
    List.iter
      (fun i ->
        match target i with
        | None -> ()
        | Some v ->
            if List.exists (function [ _; g ] -> String.length g > 5 && String.sub g 0 5 = "prim:" | _ -> false)
                 (rows t "assign_address" v)
            then raise (Not_summarized "a primitive called through a variable");
            let gs = get v in
            List.iter
              (fun g ->
                (match param g, arg i with
                 | Some p, Some a -> emit (Assign (tmp p, tmp a))
                 | _ -> ());
                match result g, ret i with
                | Some r', Some r -> emit (Assign (tmp r, tmp r'))
                | _ -> ())
              gs;
            (* (a call through what is not only the tree's closures) *)
            let only_tree =
              gs <> []
              && rows t "assign_load_field" v = []
              && List.for_all (function [ _; g ] -> in_tree g | _ -> false) (rows t "assign_address" v)
              && not (List.exists (fun x -> param x = Some v) stages)
              && not (is_global v) in
            if not only_tree then begin
              let a = match arg i with Some a -> tmp a | None -> (incr count; Models.Tmp !count) in
              let r = match ret i with Some r -> tmp r | None -> (incr count; Models.Tmp !count) in
              emit (Call (r, tmp v, a))
            end)
      calls;
    Hashtbl.iter
      (fun x () ->
        List.iter
          (fun i ->
            List.iter (function [ _; e ] -> emit (Raise e) | _ -> ()) (rows t "raise_of" i))
          (Hashtbl.find_all raises_of x))
      tree;
    (n, List.rev !ops) in
  let raw =
    List.map (fun f -> (f, try Ok (summarize f) with Not_summarized why -> Error why)) roots in
  let table = Hashtbl.create 256 in
  List.iter (function f, Ok s -> Hashtbl.replace table f s | _ -> ()) raw;
  List.map
    (function
      | f, Ok (n, ops) -> (f, Ok (n, simplify (inline table [ f ] ops)))
      | r -> r)
    raw

(* ---- a summary simplified, what it says the same (the analysis is
 * flow-insensitive: a variable is the set of what it may point to)
 *
 * 1. copies merged: Tmps in a cycle of Assigns have one set, one
 *    variable; a Tmp defined only by a copy is its source;
 * 2. a definition no op reads dropped (Load, Assign, Scalar, New,
 *    Global into a Tmp read by none), until none is left; a Load kept,
 *    a field read, what dead.dl asks.
 * A Store is kept: two variables may point to one object, a value
 * stored through one loaded through the other, which this does not
 * see. *)
and simplify (ops : op list) : op list =
  let subst (f : Models.v -> Models.v) (ops : op list) : op list =
    List.sort_uniq compare (List.map (map_op f) ops)
    |> List.filter (function Assign (a, b) -> a <> b | _ -> true) in
  (* the Tmps a definition writes *)
  let dst (o : op) : Models.v option =
    match o with
    | Assign (d, _) | Load (d, _, _) | New d | Scalar d | Call (d, _, _) | Global (d, _) -> Some d
    | Store _ | Raise _ -> None in
  let defs (ops : op list) (v : Models.v) : op list =
    List.filter (fun o -> dst o = Some v) ops in
  (* 1. a cycle of copies one variable: the Tmps reached both ways *)
  let rec merge_cycles (ops : op list) : op list =
    let edges = List.filter_map (function Assign ((Tmp _ as d), (Tmp _ as s)) -> Some (s, d) | _ -> None) ops in
    let rec reach (seen : Models.v list) (x : Models.v) : Models.v list =
      if List.mem x seen then seen
      else List.fold_left (fun acc (s, d) -> if s = x then reach acc d else acc) (x :: seen) edges in
    let tmps = List.sort_uniq compare (List.concat_map (fun (s, d) -> [ s; d ]) edges) in
    match
      List.find_map
        (fun x ->
          let fwd = reach [] x in
          match List.filter (fun y -> y <> x && List.mem x (reach [] y) && List.mem y fwd) tmps with
          | [] -> None
          | ys -> Some (x, ys))
        tmps
    with
    | Some (x, ys) -> merge_cycles (subst (fun v -> if List.mem v ys then x else v) ops)
    | None -> ops in
  (* 1. a Tmp whose one definition is a copy: its source *)
  let rec copies (ops : op list) : op list =
    match
      List.find_map
        (fun o ->
          match o with
          | Assign ((Tmp _ as a), b) when defs ops a = [ o ] && b <> a -> Some (a, b)
          | _ -> None)
        ops
    with
    | Some (a, b) -> copies (subst (fun v -> if v = a then b else v) (List.filter (( <> ) (Assign (a, b))) ops))
    | None -> ops in
  (* 2. a definition of a Tmp no op reads *)
  let reads (o : op) : Models.v list =
    match o with
    | Assign (_, s) | Load (_, s, _) -> [ s ]
    | Store (a, _, b) -> [ a; b ]
    | Call (_, f, a) -> [ f; a ]
    | New _ | Scalar _ | Global _ | Raise _ -> [] in
  let rec unused (ops : op list) : op list =
    let read = List.concat_map reads ops in
    let dead (o : op) =
      match o, dst o with
      (* (a Load is a field read, what dead.dl's dead fields ask: kept,
       * its value unread or not; old: dropped, Hashtbl's size dead) *)
      | (Call _ | Load _), _ -> false
      | _, Some (Tmp _ as d) -> not (List.mem d read)
      | _ -> false in
    if List.exists dead ops then unused (List.filter (fun o -> not (dead o)) ops) else ops in
  let rec fix (ops : op list) : op list =
    let ops' = unused (copies (merge_cycles ops)) in
    if ops' = ops then ops else fix ops' in
  fix (List.sort_uniq compare ops)

(* a call of a summarized function given all its arguments, its summary
 * in its place, renumbered (List.rev's List.rev_append: rev's cells its
 * call's own, as Models writes them); not one being written already *)
and inline table (stack : string list) (ops : op list) : op list =
  let top = List.fold_left (fun m o -> max m (top_tmp o)) 0 ops in
  let next = ref top in
  let uses (x : Models.v) : int =
    List.length (List.filter (fun o -> List.mem x (vars_of_op o)) ops) in
  let calls = List.filter_map (function Call (d, f, a) -> Some (d, f, a) | _ -> None) ops in
  let removed = ref [] and added = ref [] in
  (* each chain on its own: a global's variable may serve several calls
   * (stable_sort's four of rev_append); old: one call through it only *)
  let globals = List.filter_map (function Global (v, g) -> Some (v, g) | _ -> None) ops in
  List.iter
    (fun ((d0, f0, a0) : Models.v * Models.v * Models.v) ->
      match List.assoc_opt f0 globals with
      | Some g when Hashtbl.mem table g && not (List.mem g stack) ->
          let n, body = Hashtbl.find table g in
          (* the chain: f a1, then what it returned applied to a2, ... *)
          let rec chain (d : Models.v) (k : int) (acc : (Models.v * Models.v * Models.v) list) =
            if k > n then Some (List.rev acc)
            else
              match List.filter (fun (_, f', _) -> f' = d) calls with
              | [ ((d', _, _) as c) ] when uses d = 2 -> chain d' (k + 1) (c :: acc)
              | _ -> None in
          let first = (d0, f0, a0) in
          (match if n = 1 then Some [ first ] else chain d0 2 [ first ] with
           | Some cs when List.length cs = n ->
               let args = List.map (fun (_, _, a) -> a) cs in
               let ret = (match List.rev cs with (d, _, _) :: _ -> d | [] -> Models.Ret) in
               let base = !next in
               let body = inline table (g :: stack) body in
               next := base + List.fold_left (fun m o -> max m (top_tmp o)) 0 body;
               let sub (x : Models.v) : Models.v =
                 match x with
                 | Arg i -> List.nth args (i - 1)
                 | Ret -> ret
                 | Tmp k -> Tmp (base + k) in
               removed := List.map (fun (d, f, a) -> Call (d, f, a)) cs @ !removed;
               added := !added @ List.map (map_op sub) body
           | _ -> ())
      | _ -> ())
    calls;
  List.filter (fun o -> not (List.mem o !removed)) ops @ !added

and vars_of_op (o : op) : Models.v list =
  match o with
  | Global (v, _) -> [ v ]
  | New v | Scalar v -> [ v ]
  | Load (a, b, _) | Store (a, _, b) | Assign (a, b) -> [ a; b ]
  | Call (a, b, c) -> [ a; b; c ]
  | Raise _ -> []

and top_tmp (o : op) : int =
  List.fold_left (fun m x -> match x with Models.Tmp k -> max m k | _ -> m) 0 (vars_of_op o)

and map_op (f : Models.v -> Models.v) (o : op) : op =
  match o with
  | Global (v, g) -> Global (f v, g)
  | New v -> New (f v)
  | Scalar v -> Scalar (f v)
  | Load (a, b, s) -> Load (f a, f b, s)
  | Store (a, s, b) -> Store (f a, s, f b)
  | Assign (a, b) -> Assign (f a, f b)
  | Call (a, b, c) -> Call (f a, f b, f c)
  | Raise e -> Raise e

let v (x : Models.v) : string =
  match x with
  | Arg k -> Printf.sprintf "Arg %d" k
  | Ret -> "Ret"
  | Tmp k -> Printf.sprintf "Tmp %d" k

let show (o : op) : string =
  match o with
  | Global (x, g) -> Printf.sprintf "Global (%s, %S)" (v x) g
  | New x -> Printf.sprintf "New (%s)" (v x)
  | Load (d, s, f) -> Printf.sprintf "Load (%s, %s, %S)" (v d) (v s) f
  | Store (d, f, s) -> Printf.sprintf "Store (%s, %S, %s)" (v d) f (v s)
  | Assign (d, s) -> Printf.sprintf "Assign (%s, %s)" (v d) (v s)
  | Scalar x -> Printf.sprintf "Scalar (%s)" (v x)
  | Call (d, f, a) -> Printf.sprintf "Call (%s, %s, %s)" (v d) (v f) (v a)
  | Raise e -> Printf.sprintf "Raise %S" e

(* ---- the summaries' file: List.rev 1, then  Load T3 A2 con:::.0 *)

let token (x : Models.v) : string =
  match x with Arg k -> "A" ^ string_of_int k | Ret -> "R" | Tmp k -> "T" ^ string_of_int k

let line (o : op) : string =
  match o with
  | New x -> "New " ^ token x
  | Load (d, s, f) -> String.concat " " [ "Load"; token d; token s; f ]
  | Store (d, f, s) -> String.concat " " [ "Store"; token d; f; token s ]
  | Assign (d, s) -> String.concat " " [ "Assign"; token d; token s ]
  | Scalar x -> "Scalar " ^ token x
  | Call (d, f, a) -> String.concat " " [ "Call"; token d; token f; token a ]
  | Raise e -> "Raise " ^ e
  | Global (x, g) -> String.concat " " [ "Global"; token x; g ]

let to_text (l : (string * (int * op list)) list) : string =
  String.concat ""
    (List.map
       (fun ((f, (n, ops)) : string * (int * op list)) ->
         Printf.sprintf "%s %d\n%s" f n
           (String.concat "" (List.map (fun o -> "  " ^ line o ^ "\n") ops)))
       l)

let untoken (s : string) : Models.v =
  match s.[0] with
  | 'A' -> Arg (int_of_string (String.sub s 1 (String.length s - 1)))
  | 'T' -> Tmp (int_of_string (String.sub s 1 (String.length s - 1)))
  | _ -> Ret

let of_text (text : string) : (string * (int * op list)) list =
  let acc = ref [] and cur = ref None in
  let close () =
    match !cur with
    | Some (f, n, ops) -> acc := (f, (n, List.rev ops)) :: !acc; cur := None
    | None -> () in
  List.iter
    (fun (l : string) ->
      if l = "" then ()
      else if l.[0] = ' ' then begin
        let o =
          match String.split_on_char ' ' (String.trim l) with
          | [ "New"; x ] -> New (untoken x)
          | [ "Load"; d; s; f ] -> Load (untoken d, untoken s, f)
          | [ "Store"; d; f; s ] -> Store (untoken d, f, untoken s)
          | [ "Assign"; d; s ] -> Assign (untoken d, untoken s)
          | [ "Scalar"; x ] -> Scalar (untoken x)
          | [ "Call"; d; f; a ] -> Call (untoken d, untoken f, untoken a)
          | [ "Raise"; e ] -> Raise e
          | [ "Global"; x; g ] -> Global (untoken x, g)
          | _ -> failwith ("a summary's op: " ^ l) in
        match !cur with
        | Some (f, n, ops) -> cur := Some (f, n, o :: ops)
        | None -> failwith ("an op before its function: " ^ l)
      end
      else begin
        close ();
        match String.rindex_opt l ' ' with
        | Some i ->
            cur := Some (String.sub l 0 i, int_of_string (String.sub l (i + 1) (String.length l - i - 1)), [])
        | None -> failwith ("a summary's head: " ^ l)
      end)
    (String.split_on_char '\n' text);
  close ();
  List.rev !acc
