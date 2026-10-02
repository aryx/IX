(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Output.mli *)

let packed (ns : int list) =
  let b = Buffer.create (8 * List.length ns) in
  List.iter (fun n -> Buffer.add_string b (Printf.sprintf "\\%03d\\%03d" (n land 255) ((n lsr 8) land 255))) ns;
  Buffer.contents b

let code_of (a : Lalr.action) = match a with Fail -> 0 | Accept -> 1 | Shift s -> 2 + (2 * s) | Reduce r -> 3 + (2 * r)

let token_type (g : Yacc.t) =
  "type token =\n" ^ String.concat "" (List.map (fun (x, ty) -> match ty with Some ty -> Printf.sprintf "  | %s of (%s)\n" x ty | None -> Printf.sprintf "  | %s\n" x) g.tokens)

let interface (g : Yacc.t) =
  token_type g ^ "\n"
  ^ String.concat "" (List.map (fun s -> Printf.sprintf "val %s : (Lexing.lexbuf -> token) -> Lexing.lexbuf -> %s\n" s (List.assoc s g.types)) g.starts)

(* $n in an action is _n; the n's it names *)
let dollars text =
  let b = Buffer.create (String.length text) and used = ref [] in
  let n = String.length text in
  let rec go i =
    if i < n then
      if text.[i] = '$' && i + 1 < n && text.[i + 1] >= '0' && text.[i + 1] <= '9' then begin
        let j = ref (i + 1) in
        while !j < n && text.[!j] >= '0' && text.[!j] <= '9' do incr j done;
        let k = int_of_string (String.sub text (i + 1) (!j - i - 1)) in
        if not (List.mem k !used) then used := k :: !used;
        (* as long as $n: the columns after it stay where they are *)
        Buffer.add_string b ("_" ^ string_of_int k);
        go !j
      end
      else (Buffer.add_char b text.[i]; go (i + 1))
  in
  go 0;
  Buffer.contents b, List.sort compare !used

let ocaml ~file ~out (g : Yacc.t) (a : Lalr.t) : string =
  let b = Buffer.create 65536 in
  let written = ref 1 in
  let add s = String.iter (fun c -> if c = '\n' then incr written) s; Buffer.add_string b s in
  let back () = add (Printf.sprintf "# %d %S\n" (!written + 1) out) in
  Option.iter (fun (c : Yacc.code) -> add (Printf.sprintf "# %d %S\n%s%s\n" c.line file (String.make c.col ' ') c.text); back ()) g.header;
  add (token_type g);
  (* a token's terminal: 0 is the end's; its value *)
  add "\nlet __number (t : token) : int =\n  match t with\n";
  List.iteri (fun i (x, ty) -> add (Printf.sprintf "  | %s%s -> %d\n" x (if ty = None then "" else " _") (i + 1))) g.tokens;
  add "\nlet __semantic (t : token) : Obj.t =\n  match t with\n";
  List.iter (fun (x, ty) -> if ty <> None then add (Printf.sprintf "  | %s v -> Obj.repr v\n" x)) g.tokens;
  if List.exists (fun (_, ty) -> ty = None) g.tokens then add "  | _ -> Obj.repr ()\n";
  let nt = Array.length a.terms and nn = Array.length a.nonterms in
  add (Printf.sprintf "\nlet __tables : Parsing.tables = {\n  nterms = %d; nnonterms = %d;\n  actions = \"" nt nn);
  Array.iter (fun row -> add (packed (List.map code_of (Array.to_list row))); add "\\\n   ") a.actions;
  add (Printf.sprintf "\";\n  defaults = \"%s\";\n  gotos = \"" (packed (List.map code_of (Array.to_list a.defaults))));
  Array.iter (fun row -> add (packed (List.map (fun s -> s + 1) (Array.to_list row))); add "\\\n   ") a.gotos;
  let own = Array.to_list (Array.sub a.rules 0 a.nrules) in
  add (Printf.sprintf "\";\n  lhs = \"%s\";\n  len = \"%s\";\n  reduce = [|\n" (packed (List.map fst own)) (packed (List.map (fun (_, rhs) -> Array.length rhs) own)));
  (* a symbol's values' type *)
  let typ (s : Lalr.symbol) =
    match s with
    | T t -> (match List.assoc_opt a.terms.(t) g.tokens with Some (Some ty) -> ty | _ -> "unit")
    | N n -> (match List.assoc_opt a.nonterms.(n) g.types with Some ty -> ty | None -> "'" ^ a.nonterms.(n))
  in
  List.iteri (fun i (r : Yacc.rule) ->
    let lhs, rhs = a.rules.(i) in
    let text, used = dollars r.action.text in
    add "    (fun () ->\n";
    List.iter (fun k ->
      if k < 1 || k > Array.length rhs then raise (Yacc.Error (r.action.line, Printf.sprintf "$%d: the rule has %d symbols" k (Array.length rhs)));
      add (Printf.sprintf "      let _%d = (Obj.obj (Parsing.value %d) : %s) in\n" k k (typ rhs.(k - 1)))) used;
    add (Printf.sprintf "      Obj.repr ((\n# %d %S\n%s%s\n" r.action.line file (String.make r.action.col ' ') text);
    back ();
    add (Printf.sprintf "      ) : %s));\n" (typ (N lhs)))) g.rules;
  add "  |] }\n\n";
  List.iteri (fun k s ->
    add (Printf.sprintf "let %s (lexer : Lexing.lexbuf -> token) (lexbuf : Lexing.lexbuf) : %s =\n  Obj.obj (Parsing.run __tables %d ~number:__number ~semantic:__semantic lexer lexbuf)\n"
           s (match List.assoc_opt s g.types with Some ty -> ty | None -> raise (Yacc.Error (0, s ^ ": %start, without its %type"))) (List.nth a.starts k))) g.starts;
  Option.iter (fun (c : Yacc.code) -> add (Printf.sprintf "\n# %d %S\n%s\n" c.line file c.text)) g.trailer;
  Buffer.contents b

let listing (a : Lalr.t) : string =
  let b = Buffer.create 65536 in
  let add = Buffer.add_string b in
  let name (s : Lalr.symbol) = match s with T t -> a.terms.(t) | N n -> a.nonterms.(n) in
  let lhs n = if n < 0 then "$accept" else a.nonterms.(n) in
  let rule r dot =
    let l, rhs = a.rules.(r) in
    lhs l ^ " :" ^ String.concat "" (List.mapi (fun i s -> (if i = dot then " ." else "") ^ " " ^ name s) (Array.to_list rhs))
    ^ if dot = Array.length rhs then " ." else ""
  in
  Array.iteri (fun r _ -> add (Printf.sprintf "%4d  %s\n" r (rule r (-1)))) a.rules;
  Array.iteri (fun s kernel ->
    add (Printf.sprintf "\nstate %d\n" s);
    List.iter (fun (r, dot) -> add (Printf.sprintf "\t%s  (%d)\n" (rule r dot) r)) kernel;
    add "\n";
    let said (act : Lalr.action) = match act with Shift t -> Printf.sprintf "shift %d" t | Reduce r -> Printf.sprintf "reduce %d" r | Accept -> "accept" | Fail -> "error" in
    if a.defaults.(s) <> Fail then add (Printf.sprintf "\t.  %s\n" (said a.defaults.(s)))
    else Array.iteri (fun t act -> if act <> Lalr.Fail then add (Printf.sprintf "\t%s  %s\n" a.terms.(t) (said act))) a.actions.(s);
    Array.iteri (fun n t -> if t >= 0 then add (Printf.sprintf "\t%s  goto %d\n" a.nonterms.(n) t)) a.gotos.(s)) a.kernels;
  add (Printf.sprintf "\n%d terminals, %d nonterminals\n%d grammar rules, %d states\n%d shift/reduce conflicts, %d reduce/reduce conflicts\n"
         (Array.length a.terms) (Array.length a.nonterms) a.nrules (Array.length a.kernels) a.sr a.rr);
  Buffer.contents b
