(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyLibRegex's cases, each with its answer written by hand; then the
 * same patterns against m-ix's Regex; then a pattern that a
 * backtracker without a memo takes exponential time on. A line "ok"
 * or "FAIL" each, for TinyLibRegex_test.sh. *)

let failures = ref 0

let check name got want =
  if got = want then print_endline ("ok " ^ name)
  else begin
    incr failures;
    Printf.printf "FAIL %s: got %s, want %s\n" name got want
  end

(* a match as its spans: "1-3" the whole, then "(2-3)" a group each,
 * "()" one that did not match; "none" *)
let spans = function
  | None -> "none"
  | Some a ->
      let n = Array.length a / 2 in
      let rec groups g =
        if g >= n then ""
        else if a.(2 * g) < 0 then "()" ^ groups (g + 1)
        else Printf.sprintf "(%d-%d)" a.(2 * g) a.((2 * g) + 1) ^ groups (g + 1)
      in
      (* the groups up to the last one that matched *)
      let rec trim s =
        let k = String.length s in
        if k >= 2 && String.sub s (k - 2) 2 = "()" then trim (String.sub s 0 (k - 2))
        else s in
      Printf.sprintf "%d-%d" a.(0) a.(1) ^ trim (groups 1)

let re p = TinyLibRegex.compile p

(* whether p matches somewhere in s *)
let yes p s = check (Printf.sprintf "matches %S %S" p s)
    (string_of_bool (TinyLibRegex.matches (re p) s)) "true"
let no p s = check (Printf.sprintf "matches %S %S: no" p s)
    (string_of_bool (TinyLibRegex.matches (re p) s)) "false"

(* the leftmost-longest match in the whole of s *)
let search p s want =
  check (Printf.sprintf "search %S %S" p s)
    (spans (TinyLibRegex.search (re p) s 0 (String.length s))) want

let error p want =
  check (Printf.sprintf "error %S" p)
    (match TinyLibRegex.compile p with
     | _ -> "compiled"
     | exception Failure m -> m) want

let () =
  (* bytes, quoted bytes, any byte, a newline *)
  yes "abc" "xxabcxx"; no "abc" "abxc";
  yes "a.c" "abc"; no "a.c" "a\nc"; no "a.c" "ac";
  yes "a\\.c" "a.c"; no "a\\.c" "abc";
  yes "a\\*" "a*"; yes "a\\nb" "a\nb";
  (* classes *)
  yes "[a-c]x" "bx"; no "[a-c]x" "dx";
  yes "[^a-c]x" "dx"; no "[^a-c]x" "ax";
  yes "[a-cx-z0]" "0";
  (* a ] in a class is quoted: a first ] ends it, as in libregexp (not
   * POSIX's rule), [] a class of nothing, which nothing matches *)
  yes "[\\]a]" "]"; no "[]a]" "]"; no "[]a]" "a]";
  (* the line's start and end *)
  yes "^ab" "abc"; no "^b" "abc"; yes "c$" "abc"; no "b$" "abc";
  yes "^$" ""; no "^$" "a";
  (* repeats, either, groups *)
  yes "ab*c" "ac"; yes "ab*c" "abbbc"; no "ab+c" "ac"; yes "ab?c" "abc";
  no "ab?c" "abbc"; yes "a(b|cd)e" "acde"; no "a(b|cd)e" "ace";
  yes "" "anything"; yes "x*" "";

  (* leftmost, then longest *)
  search "b+" "abbbcbb" "1-4";
  search "a|ab|abc" "xabcd" "1-4";
  search "x*" "abc" "0-0";
  search "q" "abc" "none";
  search "(a|ab)(c|bcd)" "abcd" "0-4(0-1)(1-4)";
  search "(a*)(b*)" "aabbb" "0-5(0-2)(2-5)";
  search "(a)|(b)" "b" "0-1()(0-1)";
  search "((a)b)+" "ababx" "0-4(2-4)(2-3)";
  search "^a" "ba" "none";
  search "a$" "aba" "2-3";

  (* from p to lim: the match starts in [p, lim] and ends by lim *)
  check "search from 2" (spans (TinyLibRegex.search (re "a+") "aaxaa" 2 5)) "3-5";
  check "search to 4" (spans (TinyLibRegex.search (re "a+") "aaxaa" 2 4)) "3-4";
  (* backwards: the match ending nearest before p, the longest of those *)
  check "search_back"
    (spans (TinyLibRegex.search_back (re "a+") "aaxaay" 6)) "3-5";
  check "search_back before p"
    (spans (TinyLibRegex.search_back (re "a+") "aaxaay" 2)) "0-2";
  check "search_back none"
    (spans (TinyLibRegex.search_back (re "z") "aaxaay" 6)) "none";

  (* sam's errors *)
  error "*a" "no operand for `*'";
  error "a|+" "no operand for `+'";
  error "(ab" "unmatched `('";
  error "ab)" "unmatched `)'";
  error "[ab" "malformed `[]'";
  error "a(b|c)*d" "compiled"

(* The same patterns, and more, against m-ix's Regex (libregexp's
 * algorithm): the whole match and the groups, on lines with no newline
 * and no UTF-8 (Regex takes é whole, TinyLibRegex a byte at a time).
 * Left out: the corner cases where the order of Regex's list of threads
 * shows, ((x?)?)* (Regex.mli), and (ab|a)(bc|c)? on abc, the same match
 * whose groups Regex splits a and bc, TinyLibRegex ab and c (the first
 * alternative tried first, a backtracker's order). *)
let twin_patterns =
  [ "abc"; "a.c"; "[a-c]+"; "[^ ]+"; "^a"; "c$"; "ab*c"; "ab+"; "ab?";
    "a|ab|abc"; "(a|ab)(c|bcd)"; "(a*)(b*)"; "(a)|(b)"; "((a)b)+";
    "x*"; "[0-9]+\\.[0-9]*"; "(a+)(a+)"; "a(b|c)*d" ]

let twin_texts =
  [ ""; "abc"; "xabcd"; "aabbb"; "abcd"; "ababx"; "b"; "ab ab"; "acbcd";
    "3.14"; "aaaa"; "zz"; "abbbcbb" ]

let regex_spans p s =
  match Regex.exec (Regex.compile p) s 0 with
  | None -> None
  | Some a ->
      Some (Array.init (2 * Array.length a) (fun k ->
        let x, y = a.(k / 2) in if k mod 2 = 0 then x else y))

let () =
  List.iter (fun p ->
    List.iter (fun s ->
      let n = String.length s in
      let ours = TinyLibRegex.search (re p) s 0 n in
      (* the groups Regex has, 1-8, beyond the pattern's: compared up to
       * the last one either matched *)
      check (Printf.sprintf "as Regex: %S %S" p s)
        (spans ours) (spans (regex_spans p s)))
      twin_texts) twin_patterns

(* "(a*)*b" on a line of n letters a and no b: a backtracker without a
 * memo tries every way of cutting the line, 2^n; with it, the pattern's
 * size times the line's length. 3,000: under a second here, never
 * ending without the memo. *)
let () =
  let line = String.make 3000 'a' in
  let t = Sys.time () in
  let m = TinyLibRegex.matches (re "(a*)*b") line in
  check "(a*)*b on 3,000 a's" (string_of_bool m) "false";
  check "(a*)*b on 3,000 a's, under a second"
    (string_of_bool (Sys.time () -. t < 1.)) "true";
  exit (if !failures = 0 then 0 else 1)
