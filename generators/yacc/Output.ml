(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Output.mli *)

let packed (ns : int list) =
  let b = Buffer.create (8 * List.length ns) in
  List.iter (fun n -> Buffer.add_string b (Printf.sprintf "\\%03d\\%03d" (n land 255) ((n lsr 8) land 255))) ns;
  Buffer.contents b

let code_of (a : Lalr.action) = match a with Fail -> 0 | Accept -> 1 | Shift s -> 2 + (2 * s) | Reduce r -> 3 + (2 * r)

let token_type (g : Yacc.t) =
  "type token =\n" ^ String.concat "" (List.map (fun (x, ty) -> match ty with Some ty -> Printf.sprintf "  | %s of (%s)\n" x ty | None -> Printf.sprintf "  | %s\n" x) g.tokens)

let interface (g : Yacc.t) =
  token_type g ^ "\nexception Error\n\n"
  ^ String.concat "" (List.map (fun s -> Printf.sprintf "val %s : (Lexing.lexbuf -> token) -> Lexing.lexbuf -> %s\n" s (List.assoc s g.types)) g.starts)

(* $n in an action is _n; the n's it names. And menhir's two places,
 * each a pair of positions, a first and a last: $sloc, the rule's text
 * (from its first symbol that is not empty), is _sloc, and $loc($n),
 * the n-th symbol's, _loc__n_; those it names, each with what it is,
 * and their n's *)
let dollars text =
  let b = Buffer.create (String.length text) and used = ref [] and places = ref [] and named = ref [] in
  let n = String.length text in
  let at i s = i + String.length s <= n && String.sub text i (String.length s) = s in
  let digits i = let j = ref i in while !j < n && text.[!j] >= '0' && text.[!j] <= '9' do incr j done; !j in
  (* as long as what it stands for: the columns after it stay where they are *)
  let place name e = if not (List.mem_assoc name !places) then places := (name, e) :: !places; Buffer.add_string b name in
  let rec go i =
    if i < n then
      if text.[i] = '$' && digits (i + 1) > i + 1 then begin
        let j = digits (i + 1) in
        let k = int_of_string (String.sub text (i + 1) (j - i - 1)) in
        if not (List.mem k !used) then used := k :: !used;
        Buffer.add_string b ("_" ^ string_of_int k);
        go j
      end
      else if at i "$sloc" then (place "_sloc" "Parsing.symbol_start_pos (), Parsing.symbol_end_pos ()"; go (i + 5))
      else if at i "$loc($" && digits (i + 6) > i + 6 && at (digits (i + 6)) ")" then begin
        let j = digits (i + 6) in
        let k = int_of_string (String.sub text (i + 6) (j - i - 6)) in
        named := k :: !named;
        place (Printf.sprintf "_loc__%d_" k) (Printf.sprintf "Parsing.rhs_start_pos %d, Parsing.rhs_end_pos %d" k k);
        go (j + 1)
      end
      else (Buffer.add_char b text.[i]; go (i + 1))
  in
  go 0;
  Buffer.contents b, List.sort compare !used, List.rev !places, !named

let ocaml ~file ~out (g : Yacc.t) (a : Lalr.t) : string =
  let b = Buffer.create 65536 in
  let written = ref 1 in
  let add s = String.iter (fun c -> if c = '\n' then incr written) s; Buffer.add_string b s in
  let back () = add (Printf.sprintf "# %d %S\n" (!written + 1) out) in
  (* menhir's, which its parser raises at a syntax error; here an action's to raise *)
  add "exception Error\n\n";
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
    let text, used, places, named = dollars r.action.text in
    add "    (fun () ->\n";
    List.iter (fun k -> if k < 1 || k > Array.length rhs then raise (Yacc.Error (r.action.line, Printf.sprintf "$%d: the rule has %d symbols" k (Array.length rhs)))) (used @ named);
    List.iter (fun k -> add (Printf.sprintf "      let _%d = (Obj.obj (Parsing.value %d) : %s) in\n" k k (typ rhs.(k - 1)))) used;
    List.iter (fun (name, e) -> add (Printf.sprintf "      let %s = (%s) in\n" name e)) places;
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
