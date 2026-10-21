(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyLibRegex.mli *)

type re = { id : int; kind : kind }

and kind =
  | Chr of char
  | Any
  | Set of bool * (char * char) list   (* negated, and its ranges *)
  | Bol
  | Eol
  | Cat of re * re
  | Alt of re * re
  | Star of re
  | Group of int * re
  | Empty

(* a pattern's character, as typed or after a backslash *)
type pchar = Plain of char | Quoted of char

let byte_of pc = match pc with Plain c -> c | Quoted c -> c

(* Plan 9's notation, as ed and sam have it; \n is a newline *)
let parse_re (p : string) : re * int =
  let pos = ref 0 and ids = ref 0 and groups = ref 0 and after = ref ' ' in
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
  and rep () =
    let rec go a =
      match peek () with
      | Some '*' -> incr pos; go (mk (Star a))
      | Some '+' -> incr pos; go (mk (Cat (a, mk (Star (copy a)))))
      | Some '?' -> incr pos; go (mk (Alt (a, mk Empty)))
      | _ -> a
    in
    go (atom ())
  (* sam's messages: the operator an operand is missing for *)
  and atom () =
    let missing c = failwith ("no operand for `" ^ String.make 1 c ^ "'") in
    if !pos >= String.length p then missing !after;
    match next () with
    | Quoted c -> mk (Chr c)
    | Plain '.' -> mk Any
    | Plain '^' -> mk Bol
    | Plain '$' -> mk Eol
    | Plain '(' ->
        incr groups;
        after := '(';
        let g = !groups in
        let e = alt () in
        if peek () <> Some ')' then failwith "unmatched `('";
        incr pos;
        mk (Group (g, e))
    | Plain '[' ->
        let neg = peek () = Some '^' in
        if neg then incr pos;
        (* sam's rules: a ] at once closes an empty class, and a - must
         * have a byte on each side *)
        (* old: the editor took that ] as a byte, and a - at either end
         * as a -, where sam and grep say "malformed" *)
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
        mk (Set (neg, ranges []))
    | Plain (('*' | '+' | '?') as c) -> missing c
    | Plain ('|' | ')') -> missing !after
    | Plain c -> mk (Chr c)
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
  r, !ids

(* [ends re text s lim k]: k end captures, for each way re matches
 * text from s, ending by lim, in priority order; a (node, position)
 * pair is tried once (a second visit could only find the same ends) *)
(* [memo size base lim]: a bit per pair of a node and a position from
 * base to lim, 30 in an int: tiny-ml has no Bytes, and a word per pair
 * would be four times the memory *)
let memo size base lim = Array.make (((size * (lim - base + 1)) / 30) + 1) 0

(* [ends_in seen base]: ends, with the pairs already tried marked in
 * seen, positions counted from base *)
let ends_in seen base re (text : string) (s : int) (lim : int)
    (k : int -> int array -> unit) =
  let caps = Array.make 20 (-1) in
  let rec m n i k =
    let key = (n.id * (lim - base + 1)) + (i - base) in
    if (seen.(key / 30) lsr (key mod 30)) land 1 = 0 then begin
      seen.(key / 30) <- seen.(key / 30) lor (1 lsl (key mod 30));
      match n.kind with
      | Chr c -> if i < lim && text.[i] = c then k (i + 1)
      | Any -> if i < lim && text.[i] <> '\n' then k (i + 1)
      | Set (neg, rs) ->
          if
            i < lim && text.[i] <> '\n'
            && List.exists (fun (a, b) -> a <= text.[i] && text.[i] <= b) rs
               <> neg
          then k (i + 1)
      | Bol -> if i = 0 || text.[i - 1] = '\n' then k i
      | Eol -> if i = String.length text || text.[i] = '\n' then k i
      | Empty -> k i
      | Cat (a, b) -> m a i (fun j -> m b j k)
      | Alt (a, b) -> m a i k; m b i k
      | Star a -> m a i (fun j -> m n j k); k i
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
  m re s (fun j -> caps.(0) <- s; caps.(1) <- j; k j caps)

let ends (re, size) text s lim k = ends_in (memo size s lim) s re text s lim k

(* a copy of the captures (tiny-ml has no Array.copy) *)
let copy a =
  let b = Array.make (Array.length a) 0 in
  for i = 0 to Array.length a - 1 do
    b.(i) <- a.(i)
  done;
  b

(* the longest match starting at s *)
let longest re text s lim =
  let best = ref None in
  ends re text s lim (fun j caps ->
      match !best with
      | Some (e, _) when e >= j -> ()
      | _ -> best := Some (j, copy caps));
  match !best with Some (_, c) -> Some c | None -> None

(* the leftmost-longest match starting in [p, lim] *)
let rec search re text p lim =
  if p > lim then None
  else
    match longest re text p lim with
    | Some c -> Some c
    | None -> search re text (p + 1) lim

(* backwards from p: the match ending nearest before p, then the
 * longest of those *)
let search_back re text p =
  let best = ref None in
  for s = 0 to p do
    ends re text s p (fun j caps ->
      match !best with
      | Some b when b.(1) > j || (b.(1) = j && b.(0) <= s) -> ()
      | _ -> best := Some (copy caps))
  done;
  !best

type regex = re * int

let compile p = parse_re p

(* One memo for all the starts. A node is always followed by the same
 * rest of the pattern, so a (node, position) pair that led to no match
 * from one start leads to none from another: each pair is tried once
 * for the whole line. *)
let matches (re, size) line =
  let n = String.length line in
  let seen = memo size 0 n in
  try
    for s = 0 to n do ends_in seen 0 re line s n (fun _ _ -> raise Exit) done;
    false
  with Exit -> true
