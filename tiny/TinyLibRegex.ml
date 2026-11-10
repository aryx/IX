(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyLibRegex.mli *)

(*****************************************************************************)
(* The pattern *)
(*****************************************************************************)

(* A node of a pattern's tree. Its id numbers it among the pattern's
 * nodes, from 0, for the matcher's memo. (old: re, the type's name,
 * beside regex, the compiled pattern's) *)
type node = { id : int; kind : kind }

and kind =
  | Chr of char
  | Any
  | In_set of (char * char) list       (* [a-z...]: its ranges *)
  | Not_in_set of (char * char) list   (* [^a-z...] (old: Set of a bool,
                                        * negated, and the ranges) *)
  | Bol
  | Eol
  | Cat of node * node
  | Alt of node * node
  | Star of node
  | Group of int * node                (* (e), \1 to \9 *)
  | Empty

(* a pattern compiled: its tree, and its number of nodes (a match's
 * memo has a bit per node and position). (old: a pair) *)
type regex = { rx_root : node; rx_nodes : int }

(* the groups a pattern may have, \1 to \9, as sam's NSUBEXP, 10 with
 * the whole match. A match's captures are two positions for each, the
 * whole match's first *)
let max_groups = 9
let ncaptures = 2 * (max_groups + 1)

(*****************************************************************************)
(* Parsing *)
(*****************************************************************************)

(* a pattern's character, as typed or after a backslash *)
type pchar = Plain of char | Quoted of char

let byte_of pc = match pc with Plain c -> c | Quoted c -> c

(* Plan 9's notation, as ed and sam have it; \n is a newline. By
 * recursive descent, the loosest first: alternatives, then sequences,
 * then repeats, then an atom. (old: parse_re, which compile called) *)
let compile (p : string) : regex =
  let pos = ref 0 and ids = ref 0 and groups = ref 0 in
  (* the operator read last, which an error names when an operand is
   * missing after it, as sam's messages do *)
  let after = ref ' ' in
  let mk kind = incr ids; { id = !ids - 1; kind } in
  let peek () = if !pos < String.length p then Some p.[!pos] else None in
  let next () =
    let c = p.[!pos] in
    incr pos;
    if c = '\\' && !pos < String.length p then (
      incr pos;
      Quoted (match p.[!pos - 1] with 'n' -> '\n' | c -> c))
    else Plain c
  in
  let rec alt () =
    let a = cat () in
    if peek () = Some '|' then (
      incr pos;
      after := '|';
      mk (Alt (a, alt ())))
    else a
  and cat () =
    let a = rep () in
    match peek () with None | Some ('|' | ')') -> a | _ -> mk (Cat (a, cat ()))
  (* e+ is e then e*, the second a copy: a node has one place in the
   * tree, which the memo relies on (below); e? is e or nothing *)
  and rep () =
    let rec go a =
      match peek () with
      | Some '*' -> incr pos; go (mk (Star a))
      | Some '+' -> incr pos; go (mk (Cat (a, mk (Star (copy a)))))
      | Some '?' -> incr pos; go (mk (Alt (a, mk Empty)))
      | _ -> a
    in
    go (atom ())
  and atom () =
    let missing c = failwith ("no operand for `" ^ String.make 1 c ^ "'") in
    if !pos >= String.length p then missing !after;
    match next () with
    | Quoted c -> mk (Chr c)
    | Plain '.' -> mk Any
    | Plain '^' -> mk Bol
    | Plain '$' -> mk Eol
    | Plain '(' ->
        (* (old: no limit, and a tenth group's captures past the end
         * of their array) *)
        if !groups = max_groups then failwith "too many subexpressions";
        incr groups;
        after := '(';
        let g = !groups in
        let e = alt () in
        if peek () <> Some ')' then failwith "unmatched `('";
        incr pos;
        mk (Group (g, e))
    | Plain '[' -> mk (set ())
    | Plain (('*' | '+' | '?') as c) -> missing c
    | Plain ('|' | ')') -> missing !after
    | Plain c -> mk (Chr c)
  (* a class, after its [: sam's rules, a ] at once closes an empty
   * class, and a - must have a byte on each side (old: the editor took
   * that ] as a byte, and a - at either end as a -, where sam and grep
   * say "malformed") *)
  and set () =
    let neg = peek () = Some '^' in
    if neg then incr pos;
    let malformed () = failwith "malformed `[]'" in
    let rec ranges acc =
      if !pos >= String.length p then malformed ();
      match next () with
      | Plain ']' -> List.rev acc
      | Plain '-' -> malformed ()
      | pc ->
          let c = byte_of pc in
          if peek () = Some '-' then begin
            incr pos;
            if !pos >= String.length p then malformed ();
            match next () with
            | Plain ']' -> malformed ()
            | pc -> ranges ((c, byte_of pc) :: acc)
          end
          else ranges ((c, c) :: acc)
    in
    let rs = ranges [] in
    if neg then Not_in_set rs else In_set rs
  (* a subtree again, its nodes new *)
  and copy n =
    mk (match n.kind with
      | Cat (a, b) -> Cat (copy a, copy b)
      | Alt (a, b) -> Alt (copy a, copy b)
      | Star a -> Star (copy a)
      | Group (g, a) -> Group (g, copy a)
      | k -> k)
  in
  (* the empty pattern matches everywhere (the editor never gives it:
   * its empty pattern is the last one) *)
  let r = if p = "" then mk Empty else alt () in
  if !pos < String.length p then failwith "unmatched `)'";
  { rx_root = r; rx_nodes = !ids }

(*****************************************************************************)
(* Matching *)
(*****************************************************************************)

(* a character in one of a set's ranges *)
let in_ranges (rs : (char * char) list) c =
  List.exists (fun (a, b) -> a <= c && c <= b) rs

(* [memo nodes base lim]: a bit per pair of a node and a position from
 * base to lim, 30 bits in an int (a byte per pair, by Bytes, would be
 * eight times the memory; old: tiny-ml had no Bytes) *)
let memo nodes base lim = Array.make (((nodes * (lim - base + 1)) / 30) + 1) 0

(* [ends_in seen base root text s lim k]: k j caps for each way root
 * matches text from s, ending at j by lim, in the order the pattern
 * prefers them, with caps the captures; a (node, position) pair is
 * tried once, and marked in seen, positions counted from base (a
 * second try could only find the same ends again) *)
let ends_in seen base root (text : string) (s : int) (lim : int)
    (k : int -> int array -> unit) =
  let caps = Array.make ncaptures (-1) in
  let rec m n i k =
    let key = (n.id * (lim - base + 1)) + (i - base) in
    if (seen.(key / 30) lsr (key mod 30)) land 1 = 0 then begin
      seen.(key / 30) <- seen.(key / 30) lor (1 lsl (key mod 30));
      match n.kind with
      | Chr c -> if i < lim && text.[i] = c then k (i + 1)
      | Any -> if i < lim && text.[i] <> '\n' then k (i + 1)
      | In_set rs ->
          if i < lim && text.[i] <> '\n' && in_ranges rs text.[i] then k (i + 1)
      | Not_in_set rs ->
          if i < lim && text.[i] <> '\n' && not (in_ranges rs text.[i]) then
            k (i + 1)
      | Bol -> if i = 0 || text.[i - 1] = '\n' then k i
      | Eol -> if i = String.length text || text.[i] = '\n' then k i
      | Empty -> k i
      | Cat (a, b) -> m a i (fun j -> m b j k)
      | Alt (a, b) -> m a i k; m b i k
      | Star a -> m a i (fun j -> m n j k); k i
      (* the group's start and end set while the rest is tried, then
       * put back, for the other ways *)
      | Group (g, a) ->
          let o = caps.(2 * g) in
          caps.(2 * g) <- i;
          m a i (fun j ->
              let e = caps.((2 * g) + 1) in
              caps.((2 * g) + 1) <- j;
              k j;
              caps.((2 * g) + 1) <- e);
          caps.(2 * g) <- o
    end
  in
  m root s (fun j -> caps.(0) <- s; caps.(1) <- j; k j caps)

(* the same, with a memo of its own: search_back's, whose starts are
 * all tried, a match from one not making a later one fail *)
let ends (rx : regex) text s lim k =
  ends_in (memo rx.rx_nodes s lim) s rx.rx_root text s lim k

(*****************************************************************************)
(* Searching *)
(*****************************************************************************)

(* the longest match starting at s, with seen, the memo of the search
 * (positions from base); caps copied, the matcher changing them as it
 * goes on (old: a copy of our own, when tiny-ml had no Array.copy) *)
let longest seen base rx text s lim =
  let best = ref None in
  ends_in seen base rx.rx_root text s lim (fun j caps ->
      match !best with
      | Some (e, _) when e >= j -> ()
      | _ -> best := Some (j, Array.copy caps));
  match !best with Some (_, c) -> Some c | None -> None

(* The leftmost-longest match starting in [p, lim], with one memo for
 * all the starts. A node is always followed by the same rest of the
 * pattern, so a (node, position) pair that led to no match from one
 * start leads to none from another; and every start before the one
 * that matches failed whole. So each pair is tried once for the whole
 * search, and a search that fails reads the text about once. (old: a
 * memo per start, a failing search quadratic: 1.25 s, bytecode, for
 * the test's starred group on 3,000 letters a, where matches took no
 * time) *)
let search rx text p lim =
  let seen = memo rx.rx_nodes p lim in
  let rec from s =
    if s > lim then None
    else
      match longest seen p rx text s lim with
      | Some c -> Some c
      | None -> from (s + 1) in
  from p

(* (old: a loop of its own over the starts, with the memo search has
 * now) *)
let matches (rx : regex) line =
  search rx line 0 (String.length line) <> None

(* backwards from p: the match ending nearest before p, then the
 * longest of those *)
let search_back rx text p =
  let best = ref None in
  for s = 0 to p do
    ends rx text s p (fun j caps ->
      match !best with
      | Some b when b.(1) > j || (b.(1) = j && b.(0) <= s) -> ()
      | _ -> best := Some (Array.copy caps))
  done;
  !best
