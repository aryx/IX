(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's languages/ocaml/Highlight_ml.ml (docs/plans/plan_emacs.md), its pass over the tokens; without the pass over the tree (Parse_ml, 1,184 lines, and Ast_ml: a name's scope: here Names_ml, over mini-ml's parser) and analyze *)

(* See Highlight_ml.mli.
 *
 * After pfff's highlight_ml.ml (codemap's), its token pass: one walk
 * over the tokens, a few facts remembered on the way (the parameters
 * and locals of the definition we are in, whether we are in a type),
 * each token's category chosen from its neighbours:
 *
 *   let f x y = ...     the let's name, then its arguments: Def_function
 *   let v = ...         no arguments: Def_value (a fun after = too: a function)
 *   M.x                 M a Module, x a Global
 *   (x : t)             after a colon, until the parenthesis closes: a type
 *   type t = A | B      a type definition: Def_type, then types and constructors
 *
 * A let is at the top when the token before it can end an expression
 * (after "=", "in", "(", "->"... a let is inside one): no indentation
 * needed, and a let in a module's struct is at its top too.
 *)

open Highlight_code

(* a token after which an expression is over, so a let is a new item *)
let ends_expression (t : Token_ml.t) : bool =
  match t.kind with
  | Lident | Uident | Int | Float | Char | String | Type_var | Label -> true
  | Keyword -> List.mem t.text [ "struct"; "end"; "done"; "true"; "false"; "sig" ]
  | Punctuation -> List.mem t.text [ ")"; "]"; "}"; ";;"; "|]" ]
  | _ -> false

(* the keywords that start an item of a structure or a signature *)
let item_keywords = [ "let"; "type"; "module"; "val"; "external"; "exception"; "open"; "include"; "class"; "method"; "end" ]

let control_keywords =
  [ "if"; "then"; "else"; "match"; "with"; "when"; "try"; "for"; "while"; "do"; "done"; "to"; "downto"; "function"; "fun" ]

let module_keywords = [ "module"; "struct"; "sig"; "end"; "open"; "include"; "functor" ]

(* caps, caps_net: a capability's name, by the repository's habit *)
let is_caps (s : string) : bool = String.length s >= 4 && String.sub s 0 4 = "caps"

(* a banner comment: (*****...*) *)
let is_banner (t : Token_ml.t) : bool = t.kind = Comment && String.length t.text >= 6 && String.sub t.text 0 6 = "(*****"

(*****************************************************************************)
(* From the tokens: a guess *)
(*****************************************************************************)

(* ix: what the last let or type was, for the and that follows it
 * (polymorphic variants in the playground's, which mini-ml has not) *)
type binder = No_binder | Let_top | Let_inside | Type_binder

(* claude: what the neighbours say; (the playground's:) the tree then says better where it
 * can ("From the tree" below) *)
let guess (toks : Token_ml.t list) : (Token_ml.t * category) list =
  (* the code, without the comments, for looking at neighbours *)
  let code = Array.of_list (List.filter (fun (t : Token_ml.t) -> t.kind <> Comment) toks) in
  let m = Array.length code in
  let cat = Array.make m Normal in
  let decided = Array.make m false in
  let text i = if i >= 0 && i < m then code.(i).text else "" in
  let kind i : Token_ml.kind option = if i >= 0 && i < m then Some code.(i).kind else None in
  let decide i c = if i >= 0 && i < m then (cat.(i) <- c; decided.(i) <- true) in
  (* what we know, walking *)
  let params = Hashtbl.create 16 and locals = Hashtbl.create 16 in
  let depth = ref 0 in
  let type_depth = ref None (* in a type since a colon, opened at this depth *) in
  let type_def = ref false (* in a type definition, until the next item *) in
  let last_binder = ref No_binder in
  (* the names bound by a pattern from [from] to one of [stop] *)
  let bind_names (from : int) (stop : string list) (c : category) (into : (string, unit) Hashtbl.t) : unit =
    let d = ref 0 and in_type = ref false and j = ref from in
    while !j < m && (not (!d = 0 && List.mem (text !j) stop)) && not (kind !j = Some Keyword && List.mem (text !j) item_keywords) do
      (match (kind !j, text !j) with
      | Some Punctuation, ("(" | "[" | "{") -> incr d
      | Some Punctuation, (")" | "]" | "}") ->
          decr d;
          in_type := false
      | Some Operator, ":" -> in_type := true
      | Some Lident, name when (not !in_type) && text (!j - 1) <> "." && name <> "_" ->
          Hashtbl.replace into name ();
          decide !j (if is_caps name then Capability else c)
      | Some Label, l ->
          (* ~x punned: x is bound too *)
          let name = String.sub l 1 (String.length l - 1) in
          if name <> "" && name.[String.length name - 1] <> ':' then Hashtbl.replace into name ()
      | _ -> ());
      incr j
    done
  in
  (* a let's (or an and's) name at [i], and its arguments *)
  let binding (i : int) (top : bool) : unit =
    let i = if text i = "rec" then i + 1 else i in
    if kind i = Some Lident then begin
      let fn = match text (i + 1) with "=" -> List.mem (text (i + 2)) [ "fun"; "function" ] | ":" -> false | _ -> true in
      decide i (if not top then Local else if fn then Def_function else Def_value);
      if not top then Hashtbl.replace locals (text i) ();
      bind_names (i + 1) [ "=" ] Parameter (if top then params else locals)
    end
    else if text i = "(" && kind (i + 1) = Some Operator && text (i + 2) = ")" then
      decide (i + 1) (if top then Def_function else Local)
    else bind_names i [ "=" ] (if top then Def_value else Local) (if top then params else locals)
  in
  (* the type's name after "type" (or "and"), past its parameters *)
  let type_name (i : int) : unit =
    let j = ref i in
    while !j < m && (List.mem (text !j) [ "nonrec"; "("; ")"; ","; "+"; "-" ] || kind !j = Some Type_var) do
      incr j
    done;
    if kind !j = Some Lident then decide !j Def_type
  in
  for i = 0 to m - 1 do
    let t = code.(i) in
    (* a new item: the type we were in is over *)
    if t.kind = Keyword && List.mem t.text item_keywords then type_depth := None;
    (match (t.kind, t.text) with
    | Punctuation, ("(" | "[" | "{" | "[|") -> incr depth
    | Punctuation, (")" | "]" | "}" | "|]") -> (
        decr depth;
        match !type_depth with Some d when !depth < d -> type_depth := None | _ -> ())
    | Operator, "=" | Punctuation, ";" -> ( match !type_depth with Some d when !depth <= d -> type_depth := None | _ -> ())
    | Keyword, "in" -> type_depth := None
    | _ -> ());
    if not decided.(i) then begin
      let in_type = !type_depth <> None || !type_def in
      let c : category =
        match t.kind with
        | Keyword -> (
            match t.text with
            | "let" ->
                let top = t.col = 0 || i = 0 || ends_expression code.(i - 1) in
                if top then (
                  Hashtbl.reset params;
                  Hashtbl.reset locals;
                  type_def := false);
                last_binder := if top then Let_top else Let_inside;
                if not (List.mem (text (i + 1)) [ "open"; "module"; "exception" ]) then binding (i + 1) top;
                Keyword
            | "and" ->
                (match !last_binder with
                | Type_binder -> type_name (i + 1)
                | Let_top -> binding (i + 1) true
                | Let_inside -> binding (i + 1) false
                | No_binder -> ());
                Keyword
            | "type" ->
                if text (i - 1) <> "module" && text (i - 1) <> ":" then begin
                  last_binder := Type_binder;
                  type_def := true;
                  type_name (i + 1)
                end;
                Keyword
            | "exception" ->
                if kind (i + 1) = Some Uident then decide (i + 1) Def_type;
                type_def := true;
                Keyword_control
            | ("val" | "external" | "method") as k ->
                type_def := false;
                let j = if List.mem (text (i + 1)) [ "mutable"; "virtual"; "private" ] then i + 2 else i + 1 in
                if kind j = Some Lident then begin
                  (* a function if its type has an arrow, before the next item *)
                  let rec arrow l =
                    l < m && (not (kind l = Some Keyword && List.mem (text l) item_keywords)) && (text l = "->" || arrow (l + 1))
                  in
                  decide j (if k = "external" || arrow (j + 1) then Def_function else Def_value)
                end;
                Keyword
            | "module" ->
                type_def := false;
                let j = if List.mem (text (i + 1)) [ "type"; "rec" ] then i + 2 else i + 1 in
                if kind j = Some Uident then decide j Def_module;
                Keyword_module
            | "fun" ->
                bind_names (i + 1) [ "->" ] Parameter params;
                Keyword_control
            | "true" | "false" -> Constructor
            | k when List.mem k module_keywords -> Keyword_module
            | k when List.mem k control_keywords -> Keyword_control
            | _ -> Keyword)
        | Uident ->
            if t.text = "Cap" && text (i + 1) = "." then Capability
            else if text (i + 1) = "." || List.mem (text (i - 1)) [ "open"; "include" ] then Module
            else Constructor
        | Lident ->
            if is_caps t.text then Capability
            else if text (i - 1) = "." && kind (i - 2) = Some Uident then if text (i - 2) = "Cap" then Capability else Global
            else if text (i - 1) = "." then Normal (* a field *)
            else if in_type then
              (* a field's name in a record type; a label in a type *)
              if text (i + 1) = ":" then if !type_def then Normal else Label else Type
            else if Hashtbl.mem params t.text then Parameter
            else if Hashtbl.mem locals t.text then Local
            else Normal
        | Label -> Label
        | Type_var -> Type_var
        | Int | Float -> Number
        | Char | String -> String
        | Operator -> Operator
        | Punctuation -> if String.length t.text >= 2 && (t.text.[1] = '@' || t.text.[1] = '%') then Attribute else Punctuation
        | Directive -> Attribute
        | Error -> Error
        | Comment -> Comment
      in
      cat.(i) <- c
    end;
    (* after a colon, a type *)
    if t.kind = Operator && t.text = ":" && !type_depth = None then type_depth := Some !depth
  done;
  (* the comments back in their places: banners, and the title between two *)
  let all = Array.of_list toks in
  let n = Array.length all in
  let k = ref 0 and out = ref [] in
  for i = 0 to n - 1 do
    let t = all.(i) in
    let c =
      if t.kind <> Comment then (
        incr k;
        cat.(!k - 1))
      else if is_banner t || (i > 0 && is_banner all.(i - 1) && i + 1 < n && is_banner all.(i + 1)) then Comment_section
      else Comment
    in
    out := (t, c) :: !out
  done;
  List.rev !out

let categorize (toks : Token_ml.t list) : (Token_ml.t * category) list = guess toks

(* ix: the guess, and over it what mini-ml's parser says of a name
 * (Names_ml: a parameter, a local, a field), where the text parses; not
 * of a capability, which the repository's habits say better (caps).
 * (The playground's second pass is over a tree of its own parser's.)
 * claude: rev_map and rev, not List.map: OCaml 4.14's map recurses once
 * a token *)
let lines (src : string) : span list array =
  let names = Names_ml.names src in
  Highlight_code.lines src
    (List.rev (List.rev_map (fun ((t : Token_ml.t), (c : category)) ->
       let c = (match Hashtbl.find_opt names t.offset with
         | Some c' when t.kind = Lident && c <> Capability -> c'
         | _ -> c) in
       (t.line, t.col, t.text, c)) (guess (Lexer_ml.tokens src))))
