(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Braun.mli *)

type 'var t = {
  current : ('var * int, int) Hashtbl.t;
  sealed : bool array;
  filled : bool array;
  incomplete : (int, 'var * int) Hashtbl.t;
  preds : int -> int list;
  new_phi : 'var -> int -> int;
  set_operands : 'var -> int -> (int * int) list -> unit;
  missing : 'var -> int -> int;
}

let create ~preds ~new_phi ~set_operands ~missing n =
  { current = Hashtbl.create 64; sealed = Array.make n false;
    filled = Array.make n false; incomplete = Hashtbl.create 16;
    preds; new_phi; set_operands; missing }

let write t var b v = Hashtbl.replace t.current (var, b) v

let rec read t var b =
  match Hashtbl.find_opt t.current (var, b) with
  | Some v -> v
  | None -> read_rec t var b

and read_rec t var b =
  let v =
    if not t.sealed.(b) then begin
      let v = t.new_phi var b in
      Hashtbl.add t.incomplete b (var, v);
      v
    end else
      match t.preds b with
      | [ p ] -> read t var p
      | [] -> t.missing var b
      | _ ->
          let v = t.new_phi var b in
          write t var b v; add_operands t var v b; v
  in
  write t var b v;
  v

and add_operands t var phi b =
  t.set_operands var phi (List.map (fun p -> p, read t var p) (t.preds b))

let seal t b =
  List.iter (fun (var, phi) -> add_operands t var phi b)
    (Hashtbl.find_all t.incomplete b);
  Hashtbl.remove t.incomplete b;
  t.sealed.(b) <- true

let fill t b = t.filled.(b) <- true

let seal_ready t =
  Array.iteri (fun b s ->
    if (not s) && List.for_all (fun p -> t.filled.(p)) (t.preds b) then
      seal t b) t.sealed

let seal_rest t = Array.iteri (fun b s -> if not s then seal t b) t.sealed

(* a phi whose operands are one value (and itself) is that value; until
 * none is (Braun et al.'s tryRemoveTrivialPhi, as a fixpoint) *)
let trivial ~phis ~set_phis ~operands n =
  let subst = Hashtbl.create 16 in
  let rec find v =
    match Hashtbl.find_opt subst v with
    | Some w -> let r = find w in Hashtbl.replace subst v r; r
    | None -> v
  in
  let changed = ref true in
  while !changed do
    changed := false;
    for b = 0 to n - 1 do
      set_phis b (List.filter (fun phi ->
        match operands phi with
        | Some ops -> (
            let others = List.filter (fun v -> v <> phi) (List.map find ops) in
            match List.sort_uniq compare others with
            | [ v ] -> Hashtbl.replace subst phi v; changed := true; false
            | _ -> true)
        | None -> true) (phis b))
    done
  done;
  find
