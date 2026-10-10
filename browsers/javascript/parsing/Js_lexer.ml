(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/javascript/parsing/Js_lexer.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_lexer.mli *)

type kind =
  | Keyword of string
  | Name of string
  | Number of float
  | String of string
  | Punct of string
  | Regex of string * string
  (* `a${x}b${y}c`: its strings ("a", "b", "c") and, between them, the
   * tokens of each ${ } *)
  | Template of string list * token list list
  | Eof

and token = { kind : kind; line : int; newline_before : bool; at : int }

exception Error of int * string

let keywords =
  (* not "of": a name everywhere but in for (x of xs), where the parser
   * looks for it *)
  [ "let"; "const"; "var"; "function"; "return"; "if"; "else"; "while"; "for"; "in"; "break"; "continue";
    "throw"; "try"; "catch"; "finally"; "new"; "typeof"; "true"; "false"; "null"; "this"; "class"; "delete";
    "do"; "switch"; "case"; "default"; "void"; "instanceof" ]

(* opti: the same in a table: a word of a script of 500 KB is asked
 * 200,000 times whether it is one (List.mem: 4% of its load) *)
let keyword : (string, unit) Hashtbl.t =
  let h = Hashtbl.create 64 in
  List.iter (fun w -> Hashtbl.replace h w ()) keywords;
  h

(* the operators, the longest first: the longest match *)
let puncts3 = [ ">>>="; "==="; "!=="; "..."; "**="; ">>>"; "<<="; ">>="; "&&="; "||="; "??=" ]

let puncts2 =
  [ "=="; "!="; "<="; ">="; "&&"; "||"; "=>"; "++"; "--"; "+="; "-="; "*="; "/="; "%="; "**"; "??"; "?."; "<<"; ">>"; "&="; "|="; "^=" ]

let puncts1 = "{}()[];,.<>+-*/%=!?:&|^~"

let puncts32 = puncts3 @ puncts2

(* every punctuation there is *)
let punctuators : string list = puncts32 @ List.init (String.length puncts1) (fun i -> String.make 1 puncts1.[i])

(* opti: those of three and two characters by their first: the few to
 * try where a punctuation starts, not all forty *)
let puncts_by_first : string list array =
  let a = Array.make 256 [] in
  List.iter (fun p -> a.(Char.code p.[0]) <- a.(Char.code p.[0]) @ [ p ]) puncts32;
  a

let is_digit c = c >= '0' && c <= '9'
(* '#': a class's private name, #x (ES2022), read as a name like any *)
(* a byte above ASCII is of a letter of another alphabet, in UTF-8: a
 * name may be written in any (what is not a letter up there, a no-break
 * space, is set apart before) *)
let is_name_start c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c = '_' || c = '$' || c = '#' || c >= '\128'
(* '#' starts a name and is not inside one: async#n(e) is async, #n *)
let is_name_char c = (is_name_start c && c <> '#') || is_digit c

(* a code point as UTF-8's bytes: a string's \u escape *)
let utf_8 (cp : int) : string =
  let b = Buffer.create 4 in
  (* by hand, not Buffer.add_utf_8_uchar: half of a surrogate pair
   * (\uD800, in a library's regular expressions) is no character, and
   * is written as its three bytes all the same *)
  let add n = Buffer.add_char b (Char.chr n) in
  if cp < 0x80 then add cp
  else if cp < 0x800 then (add (0xC0 lor (cp lsr 6)); add (0x80 lor (cp land 0x3F)))
  else if cp < 0x10000 then (add (0xE0 lor (cp lsr 12)); add (0x80 lor ((cp lsr 6) land 0x3F)); add (0x80 lor (cp land 0x3F)))
  else (add (0xF0 lor ((cp lsr 18) land 7)); add (0x80 lor ((cp lsr 12) land 0x3F)); add (0x80 lor ((cp lsr 6) land 0x3F)); add (0x80 lor (cp land 0x3F)));
  Buffer.contents b

let tokenize (s : string) : token list =
  let n = String.length s in
  let line = ref 1 and newline = ref false and tokens = ref [] in
  (* where the token being read starts in the text (the loop's, below) *)
  let here = ref 0 in
  let emit kind at_line =
    tokens := { kind; line = at_line; newline_before = !newline; at = !here } :: !tokens;
    newline := false
  in
  let error msg = raise (Error (!line, msg)) in
  (* what each "(" and "{" still open is -- an if's or a loop's head, a
   * block -- and whether the last one closed was: after those a
   * statement starts, and a / there is a regular expression's
   * (if (x) /re/.test(y); a block's } and /^a/.test(z)) *)
  let opened : bool list ref = ref [] and after_statement = ref false in
  let bracket (c : char) : unit =
    let before = match !tokens with t :: _ -> Some t.kind | [] -> None in
    match c with
    | '(' -> opened := (match before with Some (Keyword ("if" | "while" | "for" | "with")) -> true | _ -> false) :: !opened
    | '{' ->
        opened :=
          (match before with
          | None | Some (Punct (")" | ";" | "{" | "}" | "=>") | Keyword ("else" | "try" | "finally" | "do") | Name _) -> true
          | _ -> false)
          :: !opened
    | ')' | '}' -> (
        match !opened with
        | v :: rest ->
            after_statement := v;
            opened := rest
        | [] -> after_statement := false)
    | _ -> ()
  in
  let sub i j = String.sub s i (j - i) in
  (* opti: a name written many times is one string, so that two of
   * them are told equal by their address (Js_scope.find) *)
  let names : (string, string) Hashtbl.t = Hashtbl.create 256 in
  let shared (w : string) : string = match Hashtbl.find_opt names w with Some w -> w | None -> Hashtbl.replace names w w; w in
  (* inside a template's ${ }: how many { are open in it (one count a
   * template, the innermost first); its } with none open ends it *)
  let depths : int list ref = ref [] in
  let brace (by : int) = match !depths with d :: rest -> depths := (d + by) :: rest | [] -> () in
  (* the tokens from [i]: to the end, or to the } that closes a
   * template's ${ }; where it stopped *)
  let rec go i =
    here := i;
    if i >= n then n
    else
      match s.[i] with
      | '}' when (match !depths with 0 :: _ -> true | _ -> false) -> i
      | '\n' ->
          incr line;
          newline := true;
          go (i + 1)
      | ' ' | '\t' | '\r' | '\012' -> go (i + 1)
      (* the spaces that are not ASCII's: a no-break space (U+00A0), a
       * byte order mark (U+FEFF), the line and paragraph separators
       * (U+2028, U+2029), in UTF-8 *)
      | '\xC2' when i + 1 < n && s.[i + 1] = '\xA0' -> go (i + 2)
      | '\xEF' when i + 2 < n && s.[i + 1] = '\xBB' && s.[i + 2] = '\xBF' -> go (i + 3)
      | '\xE2' when i + 2 < n && s.[i + 1] = '\x80' && (s.[i + 2] = '\xA8' || s.[i + 2] = '\xA9') ->
          newline := true;
          go (i + 3)
      | '/' when i + 1 < n && s.[i + 1] = '/' ->
          let rec eol j = if j >= n || s.[j] = '\n' then j else eol (j + 1) in
          go (eol i)
      | '/' when i + 1 < n && s.[i + 1] = '*' ->
          let start = !line in
          let rec close j =
            if j + 1 >= n then raise (Error (start, "a comment /* never closed"))
            else if s.[j] = '*' && s.[j + 1] = '/' then j + 2
            else (
              if s.[j] = '\n' then (
                incr line;
                newline := true);
              close (j + 1))
          in
          go (close (i + 2))
      (* a / where an expression starts is a regular expression's: after
       * an operator, a "(" or a keyword, not after a value (a name, a
       * number, ")"), which it would divide *)
      | '/' when regex_allowed () -> go (regex i)
      | c when is_digit c || (c = '.' && i + 1 < n && is_digit s.[i + 1]) -> go (number i)
      | c when is_name_start c ->
          let j = ref (i + 1) in
          while !j < n && is_name_char s.[!j] do incr j done;
          if !j + 1 < n && s.[!j] = '\\' && s.[!j + 1] = 'u' then go (escaped_name i)
          else (
            let w = sub i !j in
            emit (if Hashtbl.mem keyword w then Keyword w else Name (shared w)) !line;
            go !j)
      (* a name with a letter written as its number, \uFB01: a
       * minifier's way with letters beyond ASCII *)
      | '\\' when i + 1 < n && s.[i + 1] = 'u' -> go (escaped_name i)
      | ('"' | '\'') as q -> go (string i q)
      | '`' -> go (template i)
      | _ -> (
          (* opti: compared in place (it was a substring made for each
           * of the forty candidates, at each punctuation: a fifth of
           * the reading of a bundle of megabytes) *)
          let starts p =
            let l = String.length p in
            i + l <= n && (let rec same k = k = l || (String.unsafe_get s (i + k) = String.unsafe_get p k && same (k + 1)) in same 0)
          in
          (* "?." before a digit is "?" and ".5": c ?.5 : 1 *)
          let starts p = starts p && not (p = "?." && i + 2 < n && is_digit s.[i + 2]) in
          match List.find_opt starts puncts_by_first.(Char.code s.[i]) with
          | Some p ->
              emit (Punct p) !line;
              go (i + String.length p)
          | None ->
              if String.contains puncts1 s.[i] then (
                if s.[i] = '{' then brace 1 else if s.[i] = '}' then brace (-1);
                bracket s.[i];
                emit (Punct (String.make 1 s.[i])) !line;
                go (i + 1))
              else error (Printf.sprintf "unexpected character %C" s.[i]))
  and regex_allowed () =
    match !tokens with
    | [] -> true
    | t :: _ -> (
        match t.kind with
        | Number _ | String _ | Name _ | Regex _ | Template _ -> false
        | Keyword ("this" | "true" | "false" | "null") -> false
        | Punct (")" | "}") -> !after_statement
        | Punct "]" -> false
        | Keyword _ | Punct _ | Eof -> true)
  (* /pattern/flags: to the / not escaped nor in a [set] *)
  and regex i =
    let rec go j in_set =
      if j >= n || s.[j] = '\n' then error "a regular expression never closed on its line"
      else
        match s.[j] with
        | '\\' -> go (j + 2) in_set
        | '[' -> go (j + 1) true
        | ']' -> go (j + 1) false
        | '/' when not in_set -> j
        | _ -> go (j + 1) in_set
    in
    let close = go (i + 1) false in
    let k = ref (close + 1) in
    while !k < n && is_name_char s.[!k] do incr k done;
    emit (Regex (sub (i + 1) close, sub (close + 1) !k)) !line;
    !k
  (* digits, a fraction, an exponent; or 0x and hexadecimal digits (0o
   * and octal ones, 0b and binary ones: OCaml reads the three alike) *)
  and number i =
    if i + 1 < n && s.[i] = '0' && String.contains "xXoObB" s.[i + 1] then (
      let j = ref (i + 2) in
      while !j < n && (is_digit s.[!j] || (Char.lowercase_ascii s.[!j] >= 'a' && Char.lowercase_ascii s.[!j] <= 'f')) do
        incr j
      done;
      (* digit by digit, as a float: 0x7fffffffffffffff (the largest
       * of a 64-bit integer, in Closure's Long) is past OCaml's int,
       * which would read it as -1 *)
      let base = match Char.lowercase_ascii s.[i + 1] with 'x' -> 16. | 'o' -> 8. | _ -> 2. in
      let digit c = float_of_int (if is_digit c then Char.code c - 48 else Char.code (Char.lowercase_ascii c) - 87) in
      let value = ref 0. in
      String.iter (fun c -> value := (!value *. base) +. digit c) (sub (i + 2) !j);
      emit (Number !value) !line;
      if !j < n && s.[!j] = 'n' then incr j;
      !j)
    else
      let j = ref i in
      let digits () = while !j < n && is_digit s.[!j] do incr j done in
      digits ();
      if !j < n && s.[!j] = '.' then (
        incr j;
        digits ());
      if !j < n && (s.[!j] = 'e' || s.[!j] = 'E') then (
        incr j;
        if !j < n && (s.[!j] = '+' || s.[!j] = '-') then incr j;
        digits ());
      (* 10n, a BigInt's literal: read as the number (no integers of
       * any size here; BigInt(x) is x's whole part) *)
      let stop = !j in
      if !j < n && s.[!j] = 'n' && not (!j + 1 < n && is_name_char s.[!j + 1]) then incr j;
      if !j < n && is_name_start s.[!j] then error (Printf.sprintf "a number followed by %C" s.[!j]);
      emit (Number (float_of_string (sub i stop))) !line;
      !j
  (* a name some of whose letters are \u escapes: never a keyword *)
  and escaped_name i =
    let b = Buffer.create 16 in
    let rec name j =
      if j < n && is_name_char s.[j] then (Buffer.add_char b s.[j]; name (j + 1))
      else if j + 1 < n && s.[j] = '\\' && s.[j + 1] = 'u' then name (escape b j)
      else j
    in
    let j = name i in
    emit (Name (Buffer.contents b)) !line;
    j
  (* an escape's character, and where the text goes on: \n, \t, \u00e9,
   * \x41; any other character is itself *)
  and escape (b : Buffer.t) (j : int) : int =
    match s.[j + 1] with
    | 'n' -> Buffer.add_char b '\n'; j + 2
    | 't' -> Buffer.add_char b '\t'; j + 2
    | 'r' -> Buffer.add_char b '\r'; j + 2
    | 'b' -> Buffer.add_char b '\b'; j + 2
    | 'f' -> Buffer.add_char b '\012'; j + 2
    | 'v' -> Buffer.add_char b '\011'; j + 2
    | '0' when not (j + 2 < n && is_digit s.[j + 2]) -> Buffer.add_char b '\000'; j + 2
    | 'x' when j + 3 < n -> (
        match int_of_string_opt ("0x" ^ sub (j + 2) (j + 4)) with
        | Some cp -> Buffer.add_string b (utf_8 cp); j + 4
        | None -> error "a \\x escape needs two hexadecimal digits")
    (* \u{1F600}, any code point *)
    | 'u' when j + 2 < n && s.[j + 2] = '{' -> (
        match String.index_from_opt s j '}' with
        | Some close -> (
            match int_of_string_opt ("0x" ^ sub (j + 3) close) with
            | Some cp -> Buffer.add_string b (utf_8 cp); close + 1
            | None -> error "a \\u{ } escape needs hexadecimal digits")
        | None -> error "a \\u{ escape never closed")
    | 'u' when j + 5 < n -> (
        match int_of_string_opt ("0x" ^ sub (j + 2) (j + 6)) with
        | Some cp -> Buffer.add_string b (utf_8 cp); j + 6
        | None -> error "a \\u escape needs four hexadecimal digits")
    (* a backslash before a line's end: the string goes on, nothing added *)
    | '\n' -> incr line; j + 2
    (* a backslash, a quote, and any other character: itself *)
    | c -> Buffer.add_char b c; j + 2
  (* `text ${expression} text`: the strings, their escapes decoded and
   * their newlines kept, and each expression's tokens -- read by [go]
   * itself, to the } that closes it: what is inside is any expression
   * (a string, a regular expression with a quote in it, braces,
   * another template), and only the lexer knows where it ends *)
  and template i =
    let at = !line in
    let strings = ref [] and expressions = ref [] in
    let b = Buffer.create 16 in
    let rec text j =
      if j >= n then error "a template never closed"
      else
        match s.[j] with
        | '`' ->
            strings := Js_utf16.joined (Buffer.contents b) :: !strings;
            j + 1
        | '\\' when j + 1 < n -> text (escape b j)
        | '$' when j + 1 < n && s.[j + 1] = '{' ->
            strings := Js_utf16.joined (Buffer.contents b) :: !strings;
            Buffer.clear b;
            (* the tokens so far set aside, the expression's gathered *)
            let outer = !tokens and outer_newline = !newline in
            tokens := [];
            newline := false;
            depths := 0 :: !depths;
            let close = go (j + 2) in
            if close >= n then error "a template's ${ never closed";
            depths := List.tl !depths;
            expressions := List.rev !tokens :: !expressions;
            tokens := outer;
            newline := outer_newline;
            text (close + 1)
        | c ->
            if c = '\n' then incr line;
            Buffer.add_char b c;
            text (j + 1)
    in
    let j = text (i + 1) in
    emit (Template (List.rev !strings, List.rev !expressions)) at;
    j
  (* a string between [q]s, its escapes decoded; no newline inside *)
  and string i q =
    let b = Buffer.create 16 in
    let rec go j =
      if j >= n || s.[j] = '\n' then error "a string never closed on its line"
      else if s.[j] = q then j + 1
      else if s.[j] = '\\' && j + 1 < n then go (escape b j)
      else (
        Buffer.add_char b s.[j];
        go (j + 1))
    in
    let at = !line in
    let j = go (i + 1) in
    (* "\\uD83D\\uDE00", two escapes: one character (Js_utf16) *)
    emit (String (Js_utf16.joined (Buffer.contents b))) at;
    j
  in
  ignore (go 0);
  emit Eof !line;
  List.rev !tokens

let rec to_string (k : kind) : string =
  match k with
  | Keyword w -> "Keyword " ^ w
  | Name w -> "Name " ^ w
  | Number f -> "Number " ^ if Float.is_integer f && Float.abs f < 1e15 then Printf.sprintf "%.0f" f else Printf.sprintf "%g" f
  | String s -> "String " ^ Printf.sprintf "%S" s
  | Punct p -> "Punct " ^ p
  | Regex (r, f) -> Printf.sprintf "Regex /%s/%s" r f
  | Template (strings, expressions) ->
      Printf.sprintf "Template [%s] [%s]"
        (String.concat "; " (List.map (Printf.sprintf "%S") strings))
        (String.concat "; " (List.map (fun tokens -> String.concat " " (List.map (fun t -> to_string t.kind) tokens)) expressions))
  | Eof -> "Eof"
