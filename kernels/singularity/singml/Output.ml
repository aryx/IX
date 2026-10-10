(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Output.mli *)

let sprintf = Printf.sprintf

(* OCaml's words: a message of that name has its operation's name followed by _ *)
let keywords = [ "and"; "as"; "assert"; "begin"; "class"; "constraint"; "do"; "done"; "downto"; "else"; "end";
  "exception"; "external"; "false"; "for"; "fun"; "function"; "functor"; "if"; "in"; "include"; "inherit";
  "initializer"; "lazy"; "let"; "match"; "method"; "module"; "mutable"; "new"; "nonrec"; "object"; "of"; "open";
  "or"; "private"; "rec"; "sig"; "struct"; "then"; "to"; "true"; "try"; "type"; "val"; "virtual"; "when";
  "while"; "with"; "mod"; "land"; "lor"; "lxor"; "lsl"; "lsr"; "asr";
  (* and an end's own operations *)
  "receive"; "close"; "endpoint"; "of_endpoint" ]

let operation (m : Description.message) : string =
  let s = String.uncapitalize_ascii m.label in
  if List.mem s keywords then s ^ "_" else s

let tag_name (m : Description.message) : string = "t_" ^ String.uncapitalize_ascii m.label
let side (imp : bool) : string = if imp then "Contract.Imp" else "Contract.Exp"
let end_type (imp : bool) : string = if imp then "imp" else "exp"
let end_module (imp : bool) : string = if imp then "Imp" else "Exp"

(* the types as declared: a constructor a message *)
let types (c : Description.t) : string =
  String.concat "" (List.map (fun ((tname, tags, _) : string * int list * bool) ->
    sprintf "type %s =\n%s" tname
      (String.concat "" (List.map (fun (t : int) ->
         let m = c.messages.(t) in
         sprintf "  | %s%s\n" m.label (if m.args = [] then "" else " of " ^ String.concat " * " m.args)) tags))) c.types)

(* the type an end receives: the one whose messages the other sends *)
let received (c : Description.t) (imp : bool) : (string * int list) list =
  List.filter_map (fun ((tname, tags, from_imp) : string * int list * bool) ->
    if from_imp <> imp then Some (tname, tags) else None) c.types

let header (source : string) : string = sprintf "(* made by mini-singml from %s: not to be changed here *)\n" source

let mli (source : string) (c : Description.t) : string =
  let an_end (imp : bool) : string =
    let t = end_type imp in
    let sends = List.filter (fun (m : Description.message) -> m.from_imp = imp) (Array.to_list c.messages) in
    sprintf "module %s : sig\n  (* an endpoint as this contract's %s end: Failure if it is not *)\n  val of_endpoint : Sip.endpoint -> %s\n  val endpoint : %s -> Sip.endpoint\n%s%s  val close : %s -> unit\nend\n"
      (end_module imp) (if imp then "importing" else "exporting") t t
      (String.concat "" (List.map (fun (m : Description.message) ->
         sprintf "  val %s : %s -> %sunit\n" (operation m) t (String.concat "" (List.map (fun (a : string) -> a ^ " -> ") m.args))) sends))
      (String.concat "" (List.map (fun ((tname, _) : string * int list) -> sprintf "  val receive : %s -> %s\n" t tname) (received c imp)))
      t
  in
  header source
  ^ sprintf "\nval contract : Contract.t\n\n(* the importing end (the client's) and the exporting (the server's) *)\ntype imp\ntype exp\n\n%s\nval channel : unit -> imp * exp\n\n%s\n%s"
      (types c) (an_end true) (an_end false)

let ml (source : string) (c : Description.t) : string =
  let b = Buffer.create 4096 in
  let add fmt = Printf.ksprintf (Buffer.add_string b) fmt in
  add "%s\n(* the messages' tags: their places below *)\n" (header source);
  Array.iteri (fun (i : int) (m : Description.message) -> add "let %s = %d\n" (tag_name m) i) c.messages;
  add "\nlet contract : Contract.t =\n  Contract.make %S\n    [|\n" c.name;
  Array.iter (fun (m : Description.message) ->
    add "      Contract.message %S %s %s;\n" m.label (side m.from_imp)
      (match m.carried with
       | Nothing -> "Contract.Nothing"
       | Block -> "Contract.Block"
       | End (contract, imp) -> sprintf "(Contract.Endpoint (%S, %s))" contract (side imp))) c.messages;
  add "    |]\n    [|\n";
  Array.iter (fun ((state, moves) : string * (int * int) list) ->
    add "      (%S, [%s]);\n" state
      (String.concat ";" (List.map (fun ((t, next) : int * int) -> sprintf " (%s, %d)" (tag_name c.messages.(t)) next) moves) ^ (if moves = [] then "" else " "))) c.states;
  add "    |]\n\ntype imp = Sip.endpoint\ntype exp = Sip.endpoint\n\n%s\nlet channel () : imp * exp = Sip.channel contract\n\n" (types c);
  add "(* (the kernel let the message through: it is one of the contract's,\n * carrying what the contract says) *)\nlet broken () = failwith %S\n" (c.name ^ ": a message that is not the contract's");
  let an_end (imp : bool) : unit =
    let t = end_type imp in
    add "\nmodule %s = struct\n" (end_module imp);
    add "  let of_endpoint (e : Sip.endpoint) : %s = if Sip.is e %S %s then e else failwith %S\n" t c.name (side imp)
      (sprintf "not %s %s's %s end" (if String.contains "AEIOU" c.name.[0] then "an" else "a") c.name (if imp then "importing" else "exporting"));
    add "  let endpoint (e : %s) : Sip.endpoint = e\n" t;
    (* an operation a message: its arguments x0, x1...; the integer, and what is carried *)
    Array.iter (fun (m : Description.message) ->
      if m.from_imp = imp then begin
        let params = String.concat "" (List.mapi (fun (i : int) (a : string) -> sprintf " (x%d : %s)" i a) m.args) in
        let value = match m.value with Some i -> sprintf "x%d" i | None -> "0" in
        let x = match m.what with Some i -> sprintf "x%d" i | None -> "" in
        let call =
          match m.carried with
          | Nothing -> sprintf "Sip.send e %s %s" (tag_name m) value
          | Block -> sprintf "Sip.send_block e %s %s %s" (tag_name m) value x
          | End (contract, its_imp) -> sprintf "Sip.send_endpoint e %s %s (%s.%s.endpoint %s)" (tag_name m) value contract (end_module its_imp) x
        in
        add "  let %s (e : %s)%s : unit = %s\n" (operation m) t params call
      end) c.messages;
    (* receive: the message by its tag and what it carries, as its type's constructor *)
    List.iter (fun ((tname, tags) : string * int list) ->
      add "  let receive (e : %s) : %s =\n    let m = Sip.receive e in\n    match m.carried with\n" t tname;
      List.iter (fun (tg : int) ->
        let m = c.messages.(tg) in
        let pattern, carried =
          match m.carried with
          | Nothing -> "Sip.Nothing", ""
          | Block -> "Sip.Block b", "b"
          | End (contract, its_imp) -> "Sip.Endpoint x", sprintf "%s.%s.of_endpoint x" contract (end_module its_imp)
        in
        let args = List.mapi (fun (i : int) (_ : string) -> if m.what = Some i then carried else "m.value") m.args in
        add "    | %s when m.tag = %s -> %s%s\n" pattern (tag_name m) m.label
          (match args with [] -> "" | [ a ] -> if String.contains a ' ' then " (" ^ a ^ ")" else " " ^ a | l -> " (" ^ String.concat ", " l ^ ")")) tags;
      add "    | _ -> broken ()\n") (received c imp);
    add "  let close (e : %s) : unit = Sip.close e\nend\n" t
  in
  an_end true;
  an_end false;
  Buffer.contents b
