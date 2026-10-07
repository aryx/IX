(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Description.mli *)

type carried =
  | Nothing
  | Block
  | End of string * bool

type message = {
  label : string;
  from_imp : bool;
  args : string list;
  value : int option;
  carried : carried;
  what : int option;
}

type t = {
  name : string;
  types : (string * int list * bool) list;
  messages : message array;
  states : (string * (int * int) list) array;
}

exception Error of int * string

let error (line : int) fmt = Printf.ksprintf (fun (m : string) -> raise (Error (line, m))) fmt

(* a type as written, where it is one a message may have *)
let rec ty_text (t : Ast.ty) : string =
  match t with
  | Tconstr (id, []) -> String.concat "." id
  | Ttuple l -> String.concat " * " (List.map ty_text l)
  | _ -> "?"

(* a message of a type's constructor: its arguments sorted out (who
 * sends it is known later, from the states) *)
let message (line : int) ((label, args) : string * Ast.ty list) : message =
  let value = ref None and carried = ref Nothing and what = ref None in
  List.iteri (fun (i : int) (t : Ast.ty) ->
    let carry (c : carried) : unit =
      if !what <> None then error line "%s carries a block or an endpoint, one at most" label;
      carried := c;
      what := Some i
    in
    match t with
    | Tconstr ([ "int" ], []) ->
        if !value <> None then error line "%s has one integer at most" label;
        value := Some i
    | Tconstr ([ "Sip"; "block" ], []) -> carry Block
    | Tconstr ([ contract; "imp" ], []) -> carry (End (contract, true))
    | Tconstr ([ contract; "exp" ], []) -> carry (End (contract, false))
    | _ -> error line "%s: an argument is an int, a Sip.block or a contract's end (Pong.imp), not %s" label (ty_text t)) args;
  { label; from_imp = false; args = List.map ty_text args; value = !value; carried = !carried; what = !what }

let read (name : string) (tree : Ast.structure) : t =
  (* the messages, in the order they are declared *)
  let messages = ref [] and types = ref [] and bindings = ref [] and last = ref 0 in
  List.iter (fun (item : Ast.item) ->
    last := item.iloc;
    match item.i with
    | Itype decls ->
        List.iter (fun (d : Ast.type_decl) ->
          match d.tkind with
          | Variant cases ->
              let first = List.length !messages in
              List.iter (fun (c : string * Ast.ty list) -> messages := message d.tloc c :: !messages) cases;
              types := (d.tname, d.tloc, List.init (List.length cases) (fun (i : int) -> first + i)) :: !types
          | _ -> error d.tloc "type %s: a contract's types are variants, a constructor a message" d.tname) decls
    | Ivalue (Rec, l, _) ->
        if !bindings <> [] then error item.iloc "a contract's states are one let rec";
        bindings := List.map (fun ((p, e) : Ast.binding) ->
          match p.p with
          | Pvar state -> (state, e)
          | _ -> error p.ploc "a state is a name") l
    | _ -> error item.iloc "a contract is its messages' types and its states' let rec") tree;
  let messages = Array.of_list (List.rev !messages) in
  if !bindings = [] then error !last "a contract has states: let rec start = ...";
  let tag (line : int) (label : string) : int =
    let rec find (i : int) : int =
      if i = Array.length messages then error line "%s is no message of this contract" label
      else if messages.(i).label = label then i
      else find (i + 1)
    in
    find 0
  in
  (* who sends a message: said once, and the same each time *)
  let sender : bool option array = Array.make (Array.length messages) None in
  let sent_by (line : int) (t : int) (from_imp : bool) : unit =
    match sender.(t) with
    | None -> sender.(t) <- Some from_imp
    | Some s -> if s <> from_imp then error line "%s is sent by one end here and by the other there" messages.(t).label
  in
  (* the states: the named ones first, in their order; then those in
   * between (after a message, before the next), named after both *)
  let states = ref (List.map (fun ((state, _) : string * Ast.expr) -> (state, ref [])) !bindings) in
  let number (state : string) : int option =
    let rec find (i : int) (l : (string * (int * int) list ref) list) : int option =
      match l with [] -> None | (s, _) :: rest -> if s = state then Some i else find (i + 1) rest in
    find 0 !states
  in
  let fresh (state : string) : int =
    states := !states @ [ (state, ref []) ];
    List.length !states - 1
  in
  let rec moves (state : string) (e : Ast.expr) : (int * int) list =
    match e.e with
    | Econstruct ([ "()" ], None) -> []
    | Efunction cases ->
        List.map (fun ((p, guard, body) : Ast.case) ->
          if guard <> None then error p.ploc "a message is received whatever it holds: no when";
          match p.p with
          | Pconstruct ([ label ], _) ->
              let t = tag p.ploc label in
              sent_by p.ploc t true;
              (t, target (state ^ "/" ^ label) body)
          | _ -> error p.ploc "a message received is said as M _ -> ...") cases
    | Eseq ({ e = Eapply ({ e = Eident [ "send" ]; _ }, [ { e = Econstruct ([ label ], None); _ } ]); _ }, rest) ->
        let t = tag e.eloc label in
        sent_by e.eloc t false;
        [ (t, target (state ^ "/" ^ label) rest) ]
    | Eapply ({ e = Eident [ "||" ]; _ }, [ a; b ]) -> moves state a @ moves state b
    | _ -> error e.eloc "a state is: function | M _ -> ..., send M; ..., ... || ..., or ()"
  (* the state an expression is: a named one, or one in between, made now *)
  and target (between : string) (e : Ast.expr) : int =
    match e.e with
    | Eident [ state ] -> (
        match number state with
        | Some n -> n
        | None -> error e.eloc "%s is no state of this contract" state)
    | _ ->
        let n = fresh between in
        let l = moves between e in
        (snd (List.nth !states n)) := l;
        n
  in
  List.iter (fun ((state, e) : string * Ast.expr) ->
    (match e.e with Eident _ -> error e.eloc "state %s is only another's name" state | _ -> ());
    let l = moves state e in
    match number state with
    | Some n -> (snd (List.nth !states n)) := l
    | None -> ()) !bindings;
  let messages = Array.mapi (fun (i : int) (m : message) ->
    match sender.(i) with
    | Some from_imp -> { m with from_imp }
    | None -> error !last "%s is in no state: who sends it?" m.label) messages in
  (* a state's messages are one end's; a type's too *)
  List.iter (fun ((state, l) : string * (int * int) list ref) ->
    match !l with
    | (t, _) :: rest ->
        if List.exists (fun ((t', _) : int * int) -> messages.(t').from_imp <> messages.(t).from_imp) rest then
          error !last "in state %s both ends may send: one at a time" state
    | [] -> ()) !states;
  let types = List.rev_map (fun ((tname, line, tags) : string * int * int list) ->
    let from_imp = messages.(List.hd tags).from_imp in
    if List.exists (fun (t : int) -> messages.(t).from_imp <> from_imp) tags then
      error line "type %s has messages of both ends: a type an end" tname;
    (tname, tags, from_imp)) !types in
  (* the names as Sing#'s: a state's first letter a capital (done_, which
   * is not OCaml's word, is Done) *)
  let shown (state : string) : string =
    String.concat "/" (List.map (fun (w : string) ->
      let n = String.length w in
      String.capitalize_ascii (if n > 1 && w.[n - 1] = '_' then String.sub w 0 (n - 1) else w)) (String.split_on_char '/' state)) in
  let states = Array.of_list (List.map (fun ((state, l) : string * (int * int) list ref) -> (shown state, !l)) !states) in
  { name; types; messages; states }
