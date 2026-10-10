(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's languages/javascript/library/Js_regexp.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_regexp.mli *)

type item = Range of int * int (* two code points *) | Class of char (* d w s D W S *)

type node =
  | Char of char
  | Any
  | Set of bool * item list (* negated, its items *)
  | Start
  | End
  | Boundary of bool (* \b, or \B *)
  | Group of int option * node list list (* captured as n, or not; its alternatives *)
  | Repeat of node * int * int option * bool (* at least, at most, greedy *)
  (* (?=x) (?!x) (?<=x) (?<!x): x matches here (or does not), ahead or
   * behind, and nothing is consumed *)
  | Look of { ahead : bool; wanted : bool; alts : node list list }
  | Backref of int (* \1: what group 1 matched, again *)
  | Named_ref of string (* \k<name>: resolved once the pattern is read *)

type t = {
  source : string;
  flags : string;
  alts : node list list;
  count : int;
  names : (string * int) list; (* (?<name>x): the groups that have one *)
  ignore_case : bool;
  multiline : bool;
  dot_all : bool; (* s: . matches a newline too *)
  unicode : bool; (* u: . is a whole character, not a byte of it *)
  sticky : bool; (* y: at the position asked, not after it *)
}

exception Bad of string

(*****************************************************************************)
(* Reading a pattern *)
(*****************************************************************************)


(* ix: types, where they were polymorphic variants: what an escape
 * reads as, and a part of a set (an item, a character, a code point) *)
type escape = E_class of char | E_char of char | E_chars of string | E_boundary of bool | E_node of node
type set_part = S_item of item | S_char of char | S_code of int

let parse (p : string) : node list list * int * (string * int) list =
  let n = String.length p in
  let pos = ref 0 and count = ref 0 and names = ref [] in
  let peek () = if !pos < n then Some p.[!pos] else None in
  let next () = let c = p.[!pos] in incr pos; c in
  let number () =
    let start = !pos in
    while !pos < n && p.[!pos] >= '0' && p.[!pos] <= '9' do incr pos done;
    if !pos = start then None else Some (int_of_string (String.sub p start (!pos - start)))
  in
  (* \x: a class, or the character it stands for *)
  (* the code point of a character's UTF-8 bytes (its first one or two; beyond: large) *)
  let code_point (s : string) : int = snd (Js_utf16.decode s 0) in
  let escape () : escape =
    if !pos >= n then raise (Bad "\\ at the end of the pattern");
    match next () with
    | ('d' | 'w' | 's' | 'D' | 'W' | 'S') as c -> E_class c
    | 'b' -> E_boundary true
    | 'B' -> E_boundary false
    | 'n' -> E_char '\n'
    | 't' -> E_char '\t'
    | 'r' -> E_char '\r'
    | 'f' -> E_char '\012'
    | 'v' -> E_char '\011'
    | '0' -> E_char '\000'
    (* \u{1F600}: any code point, as its UTF-8 bytes *)
    | 'u' when !pos < n && p.[!pos] = '{' -> (
        match String.index_from_opt p !pos '}' with
        | Some close -> (
            match int_of_string_opt ("0x" ^ String.sub p (!pos + 1) (close - !pos - 1)) with
            | Some cp ->
                pos := close + 1;
                E_chars (Js_lexer.utf_8 cp)
            | None -> E_char 'u')
        | None -> E_char 'u')
    | 'u' when !pos + 4 <= n -> (
        match int_of_string_opt ("0x" ^ String.sub p !pos 4) with
        | Some cp ->
            pos := !pos + 4;
            E_chars (Js_lexer.utf_8 cp)
        | None -> E_char 'u')
    | 'x' when !pos + 2 <= n -> (
        match int_of_string_opt ("0x" ^ String.sub p !pos 2) with Some c -> pos := !pos + 2; E_char (Char.chr c) | None -> E_char 'x')
    (* \1, \12: a group's match, again *)
    | c when c >= '1' && c <= '9' ->
        decr pos;
        E_node (Backref (Option.get (number ())))
    | 'k' when !pos < n && p.[!pos] = '<' -> (
        match String.index_from_opt p !pos '>' with
        | Some close ->
            let name = String.sub p (!pos + 1) (close - !pos - 1) in
            pos := close + 1;
            E_node (Named_ref name)
        | None -> E_char 'k')
    | c -> E_char c
  in
  let rec alternatives () : node list list =
    let first = sequence [] in
    if peek () = Some '|' then (incr pos; first :: alternatives ()) else [ first ]
  and sequence acc : node list =
    match peek () with
    | None | Some '|' | Some ')' -> List.rev acc
    | Some _ -> sequence (List.rev_append (quantified ()) acc)
  (* an atom and its quantifier; a \u escape may be several bytes *)
  and quantified () : node list =
    let atoms = atom () in
    let quantifier =
      match peek () with
      | Some '*' -> incr pos; Some (0, None)
      | Some '+' -> incr pos; Some (1, None)
      | Some '?' -> incr pos; Some (0, Some 1)
      | Some '{' -> (
          let save = !pos in
          incr pos;
          match number () with
          | Some lo -> (
              match next () with
              | '}' -> Some (lo, Some lo)
              | ',' -> (
                  let hi = number () in
                  match next () with '}' -> Some (lo, hi) | _ -> pos := save + 1; None)
              | _ -> pos := save + 1; None)
          | None -> pos := save; None)
      | _ -> None
    in
    match quantifier with
    | None -> atoms
    | Some (lo, hi) ->
        let greedy = if peek () = Some '?' then (incr pos; false) else true in
        let last, before = match List.rev atoms with l :: b -> (l, List.rev b) | [] -> raise (Bad "nothing to repeat") in
        before @ [ Repeat (last, lo, hi, greedy) ]
  and atom () : node list =
    match next () with
    | '.' -> [ Any ]
    | '^' -> [ Start ]
    | '$' -> [ End ]
    | '(' ->
        let starts s = !pos + String.length s <= n && String.sub p !pos (String.length s) = s in
        let skip s = pos := !pos + String.length s in
        (* what the "(" opens: a look around, or a group *)
        let look =
          if starts "?=" then (skip "?="; Some (true, true))
          else if starts "?!" then (skip "?!"; Some (true, false))
          else if starts "?<=" then (skip "?<="; Some (false, true))
          else if starts "?<!" then (skip "?<!"; Some (false, false))
          else None
        in
        let captured =
          if look <> None then None
          else if starts "?:" then (skip "?:"; None)
          else if starts "?<" then (
            match String.index_from_opt p !pos '>' with
            | Some close ->
                incr count;
                names := (String.sub p (!pos + 2) (close - !pos - 2), !count) :: !names;
                pos := close + 1;
                Some !count
            | None -> raise (Bad "a group's name never closed"))
          else if starts "?" then raise (Bad "an unknown group (?")
          else (incr count; Some !count)
        in
        let alts = alternatives () in
        if peek () <> Some ')' then raise (Bad "a ( never closed");
        incr pos;
        [ (match look with Some (ahead, wanted) -> Look { ahead; wanted; alts } | None -> Group (captured, alts)) ]
    | '[' -> [ set () ]
    | ('*' | '+' | '?') as c -> raise (Bad (Printf.sprintf "nothing to repeat before %c" c))
    | '\\' -> (
        match escape () with
        | E_class c -> [ Set (false, [ Class c ]) ]
        | E_char c -> [ Char c ]
        | E_chars s -> chars s
        | E_boundary b -> [ Boundary b ]
        | E_node nd -> [ nd ])
    (* a character beyond ASCII: all its bytes, one thing (é+ is é, é, é: not é's last byte again) *)
    | c when c >= '\x80' ->
        let bytes, _ = Js_utf16.decode p (!pos - 1) in
        pos := !pos + bytes - 1;
        chars (String.sub p (!pos - bytes) bytes)
    | c -> [ Char c ]
  and chars (s : string) : node list =
    if String.length s = 1 then [ Char s.[0] ] else [ Group (None, [ List.init (String.length s) (fun i -> Char s.[i]) ]) ]
  and set () : node =
    let negated = if peek () = Some '^' then (incr pos; true) else false in
    let rec items acc first =
      match peek () with
      | None -> raise (Bad "a [ never closed")
      (* [] matches nothing and [^] anything: a ] first closes the set
       * (in JavaScript; POSIX reads it as a character) *)
      | Some ']' -> ignore first; incr pos; List.rev acc
      | Some _ ->
          let lo =
            match next () with
            | '\\' -> (
                match escape () with
                | E_class c -> S_item (Class c)
                | E_char c -> S_char c
                | E_chars s -> S_code (code_point s)
                | E_boundary _ -> S_char '\b'
                (* in a set, \1 is the character of that code *)
                | E_node (Backref g) -> S_char (Char.chr (g land 255))
                | E_node _ -> S_char 'k')
            (* a character beyond ASCII written as itself: its code point, all its bytes read *)
            | c when c >= '\x80' ->
                let bytes, cp = Js_utf16.decode p (!pos - 1) in
                pos := !pos + bytes - 1;
                S_code cp
            | c -> S_char c
          in
          (* a bound is a code point: a set is of characters (a text is
           * UTF-8, read a character at a time: Js_utf16) *)
          let code (part : set_part) : int = match part with S_char c -> Char.code c | S_code cp -> cp | S_item _ -> 0 in
          let range lo hi = [ Range (code lo, code hi) ] in
          (match lo with
          | S_item it -> items (it :: acc) false
          | (S_char _ | S_code _) as lo ->
              if peek () = Some '-' && !pos + 1 < n && p.[!pos + 1] <> ']' then (
                incr pos;
                (* the upper bound: an escape too ("\u0020-\u007e" lost its, read as "-") *)
                let hi =
                  match next () with
                  | '\\' -> ( match escape () with E_char c -> S_char c | E_chars s -> S_code (code_point s) | _ -> S_char '-')
                  | c when c >= '\x80' ->
                      let bytes, cp = Js_utf16.decode p (!pos - 1) in
                      pos := !pos + bytes - 1;
                      S_code cp
                  | c -> S_char c
                in
                items (List.rev_append (range lo hi) acc) false)
              else items (List.rev_append (range lo lo) acc) false)
    in
    Set (negated, items [] true)
  in
  let alts = alternatives () in
  if !pos < n then raise (Bad "an unmatched )");
  (alts, !count, !names)

(* \k<name> made the number of its group, now that every name is known *)
let rec resolved (names : (string * int) list) (nd : node) : node =
  let each = List.map (List.map (resolved names)) in
  match nd with
  | Named_ref name -> ( match List.assoc_opt name names with Some g -> Backref g | None -> raise (Bad ("no group named " ^ name)))
  | Group (c, alts) -> Group (c, each alts)
  | Look l -> Look { l with alts = each l.alts }
  | Repeat (x, lo, hi, greedy) -> Repeat (resolved names x, lo, hi, greedy)
  | nd -> nd

let compile (source : string) (flags : string) : (t, string) result =
  match parse source with
  | alts, count, names ->
      let has = String.contains flags in
      Ok
        { source; flags; alts = List.map (List.map (resolved names)) alts; count; names; ignore_case = has 'i'; multiline = has 'm'; dot_all = has 's';
          unicode = has 'u'; sticky = has 'y' }
  | exception Bad why -> Error why

let source (re : t) = re.source
let flags (re : t) = re.flags
let global (re : t) = String.contains re.flags 'g'
let groups (re : t) = re.count
let names (re : t) = re.names
let sticky (re : t) = re.sticky

(*****************************************************************************)
(* Matching *)
(*****************************************************************************)

let is_word (c : char) : bool = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c = '_'
let is_space (c : char) : bool = c = ' ' || c = '\t' || c = '\n' || c = '\r' || c = '\012' || c = '\011'

(* a class and a code point: beyond ASCII no digit and no letter of a
 * word, and the spaces Unicode has (no-break, the en and em ones, the
 * line's and paragraph's separators, the byte-order mark) *)
let class_has (c : char) (cp : int) : bool =
  let ascii f = cp < 0x80 && f (Char.chr cp) in
  let space = ascii is_space || cp = 0xA0 || cp = 0x1680 || (cp >= 0x2000 && cp <= 0x200A) || cp = 0x2028 || cp = 0x2029 || cp = 0x202F || cp = 0x205F || cp = 0x3000 || cp = 0xFEFF in
  match c with
  | 'd' -> ascii (fun x -> x >= '0' && x <= '9')
  | 'D' -> not (ascii (fun x -> x >= '0' && x <= '9'))
  | 'w' -> ascii is_word
  | 'W' -> not (ascii is_word)
  | 's' -> space
  | _ -> not space

(* at most this many steps per exec: {|(a*)*b|} on a long string stops *)
let budget = 1_000_000

let exec (re : t) (s : string) (from : int) : (int * int) option array option =
  let len = String.length s in
  let caps = Array.make (re.count + 1) None in
  let steps = ref 0 in
  let lower = Char.lowercase_ascii in
  let same a b = if re.ignore_case then lower a = lower b else a = b in
  let in_set items x =
    List.exists
      (fun it ->
        match it with
        | Class c -> class_has c x
        | Range (lo, hi) ->
            (x >= lo && x <= hi)
            || (re.ignore_case && x < 0x80 && (let other = Char.code (if x >= 97 && x <= 122 then Char.uppercase_ascii (Char.chr x) else lower (Char.chr x)) in other >= lo && other <= hi)))
      items
  in
  let rec seq (nodes : node list) (i : int) (k : int -> bool) : bool =
    match nodes with [] -> k i | nd :: rest -> one nd i (fun j -> seq rest j k)
  and alts (l : node list list) (i : int) (k : int -> bool) : bool = List.exists (fun sq -> seq sq i k) l
  and one (nd : node) (i : int) (k : int -> bool) : bool =
    incr steps;
    if !steps > budget then false
    else
      match nd with
      | Char c -> i < len && same s.[i] c && k (i + 1)
      (* a whole character, all its bytes: a set is of characters, and
       * a dot takes one (a pair of halves as one, where the standard
       * without u has two: nobody means half an emoji) *)
      | Any -> i < len && (re.dot_all || s.[i] <> '\n') && k (i + fst (Js_utf16.decode s i))
      | Set (negated, items) ->
          i < len
          &&
          let bytes, cp = Js_utf16.decode s i in
          in_set items cp <> negated && k (i + bytes)
      | Start -> (i = 0 || (re.multiline && s.[i - 1] = '\n')) && k i
      | End -> (i = len || (re.multiline && s.[i] = '\n')) && k i
      | Boundary b ->
          let before = i > 0 && is_word s.[i - 1] and after = i < len && is_word s.[i] in
          (before <> after) = b && k i
      | Group (None, l) -> alts l i k
      | Group (Some g, l) ->
          let old = caps.(g) in
          alts l i (fun j ->
              let saved = caps.(g) in
              caps.(g) <- Some (i, j);
              k j || (caps.(g) <- saved; false))
          || (caps.(g) <- old; false)
      (* x here, ahead: tried, and whatever it took given back. Behind:
       * some start before from which it ends exactly here. Not wanted:
       * the groups it set are forgotten *)
      | Look { ahead; wanted; alts = l } ->
          let saved = Array.copy caps in
          let found =
            if ahead then alts l i (fun _ -> true)
            else
              let rec from j = j >= 0 && (alts l j (fun e -> e = i) || from (j - 1)) in
              from i
          in
          if found = wanted then (if not wanted then Array.blit saved 0 caps 0 (Array.length caps); k i || (Array.blit saved 0 caps 0 (Array.length caps); false))
          else (Array.blit saved 0 caps 0 (Array.length caps); false)
      (* what the group matched, again here; a group that took no part: nothing *)
      | Backref g -> (
          match if g < Array.length caps then caps.(g) else None with
          | None -> k i
          | Some (a, b) ->
              let n = b - a in
              i + n <= len
              && (let rec eq j = j >= n || (same s.[a + j] s.[i + j] && eq (j + 1)) in eq 0)
              && k (i + n))
      | Named_ref _ -> false
      | Repeat (x, lo, hi, greedy) ->
          (* one more of x, unless at the maximum; an empty one ends it
           * (x* on an empty x would never) *)
          let rec rep count i =
            let more () = match hi with Some h when count >= h -> false | _ -> one x i (fun j -> j <> i && rep (count + 1) j) in
            if count < lo then one x i (fun j -> rep (count + 1) j) else if greedy then more () || k i else k i || more ()
          in
          rep 0 i
  in
  let rec from_ start =
    if start > len then None
    else (
      Array.fill caps 0 (Array.length caps) None;
      let found = ref None in
      if alts re.alts start (fun j -> found := Some j; true) then (
        caps.(0) <- Some (start, Option.get !found);
        Some (Array.copy caps))
      else if !steps > budget || re.sticky then None
      else from_ (start + 1))
  in
  from_ (max 0 from)
