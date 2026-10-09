(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* Text.mli's examples, checked, and its laws: against a string changed
 * the plain way, a few thousand changes drawn at random. *)

let t name f = Testo.create name (fun () -> f (); Testo.Promise.return ())
let int = Alcotest.(check int)
let str = Alcotest.(check string)
let pos = Alcotest.(check (option int))
let span = Alcotest.(check (option (pair int int)))

(* the plain way *)
let insert (s : string) (at : int) (x : string) : string = String.sub s 0 at ^ x ^ String.sub s at (String.length s - at)
let delete (s : string) (at : int) (len : int) : string = String.sub s 0 at ^ String.sub s (at + len) (String.length s - at - len)

(* Lehmer's numbers: the same changes at each run *)
let seed = ref 1
let random (n : int) : int = seed := !seed * 48271 mod 0x7fffffff; !seed mod n

let whole m = Option.map (fun (a : (int * int) array) -> a.(0)) m

let tests = [
  t "text: the gap, mli's example" (fun () ->
    let tx = Text.create "hello world" in
    Text.insert tx 5 ",";
    str "insert" "hello, world" (Text.to_string tx);
    str "delete" "h" (Text.delete tx 0 1);
    str "left" "ello, world" (Text.to_string tx);
    int "length" 11 (Text.length tx);
    Alcotest.(check char) "get, before the gap's place" 'e' (Text.get tx 0);
    Alcotest.(check char) "get, after" 'd' (Text.get tx 10);
    str "sub over the gap" "ello" (Text.sub tx 0 4);
    str "sub, nothing" "" (Text.sub tx 11 0));
  t "text: out of the text" (fun () ->
    let tx = Text.create "abc" in
    List.iter (fun (what, f) ->
      match f () with
      | () -> Alcotest.fail ("no exception: " ^ what)
      | exception Invalid_argument _ -> ())
      [ "get 3", (fun () -> ignore (Text.get tx 3)); "get -1", (fun () -> ignore (Text.get tx (-1)));
        "sub 2 2", (fun () -> ignore (Text.sub tx 2 2)); "insert 4", (fun () -> Text.insert tx 4 "x");
        "delete 1 3", (fun () -> ignore (Text.delete tx 1 3)); "delete -1 1", (fun () -> ignore (Text.delete tx (-1) 1)) ];
    str "as it was" "abc" (Text.to_string tx));
  t "text: a text typed in grows" (fun () ->
    let tx = Text.create "" and b = Buffer.create 100 in
    for i = 0 to 9999 do
      let s = string_of_int i ^ "\n" in
      Text.insert tx (Text.length tx) s;
      Buffer.add_string b s
    done;
    str "10000 lines" (Buffer.contents b) (Text.to_string tx);
    int "its lines" 10000 (Text.line tx (Text.length tx)));
  t "text: points" (fun () ->
    let tx = Text.create "0123456789" in
    let p = List.map (Text.new_point tx) [ 0; 4; 5; 6; 10 ] in
    let at () = List.map Text.get_position p in
    Text.insert tx 5 "ab";
    Alcotest.(check (list int)) "after the insertion: moved; at it: not" [ 0; 4; 5; 8; 12 ] (at ());
    ignore (Text.delete tx 3 4);
    Alcotest.(check (list int)) "in the deletion: its start" [ 0; 3; 3; 4; 8 ] (at ());
    Text.remove_point tx (List.nth p 4);
    Text.insert tx 0 "x";
    Alcotest.(check (list int)) "removed: no longer moved" [ 0; 4; 4; 5; 8 ] (at ());
    let q = Text.new_point tx 99 in
    int "past the end: the end" (Text.length tx) (Text.get_position q);
    Text.set_position tx q (-3);
    int "before the start: the start" 0 (Text.get_position q));
  t "text: lines" (fun () ->
    (*                     0 12 3456 78 *)
    let tx = Text.create "a\n\nbcd\nef" in
    Alcotest.(check (list int)) "bol" [ 0; 0; 2; 3; 3; 3; 3; 7; 7; 7 ] (List.init 10 (Text.bol tx));
    Alcotest.(check (list int)) "eol" [ 1; 1; 2; 6; 6; 6; 6; 9; 9; 9 ] (List.init 10 (Text.eol tx));
    Alcotest.(check (list int)) "line" [ 0; 0; 1; 2; 2; 2; 2; 3; 3; 3 ] (List.init 10 (Text.line tx));
    Alcotest.(check (list int)) "forward_line from c" [ 0; 0; 2; 3; 7; 7 ] (List.map (Text.forward_line tx 4) [ -3; -2; -1; 0; 1; 2 ]);
    let empty = Text.create "" in
    int "no text: bol" 0 (Text.bol empty 0);
    int "no text: eol" 0 (Text.eol empty 0);
    int "no text: forward_line" 0 (Text.forward_line empty 0 1));
  t "text: undo, mli's example" (fun () ->
    let tx = Text.create "" in
    Text.insert tx 0 "ab";
    Text.boundary tx;
    Text.insert tx 2 "c";
    ignore (Text.delete tx 0 1);
    str "changed" "bc" (Text.to_string tx);
    pos "the second command" (Some 2) (Text.undo tx);
    str "ab again" "ab" (Text.to_string tx);
    pos "the first" (Some 0) (Text.undo tx);
    str "nothing" "" (Text.to_string tx);
    pos "nothing to undo" None (Text.undo tx));
  t "text: undo, boundaries" (fun () ->
    let tx = Text.create "abc" in
    Text.boundary tx;
    pos "a boundary and no change" None (Text.undo tx);
    Text.insert tx 3 "d";
    Text.boundary tx;
    Text.boundary tx;
    Text.insert tx 0 "";
    Text.boundary tx;
    pos "two boundaries are one, an empty change none" (Some 3) (Text.undo tx);
    str "abc" "abc" (Text.to_string tx);
    let v = Text.version tx in
    Text.insert tx 0 "x";
    Alcotest.(check bool) "the version changes" true (Text.version tx <> v);
    let p = Text.new_point tx 4 in
    pos "undone" (Some 0) (Text.undo tx);
    int "a point follows what is undone" 3 (Text.get_position p));
  t "text: search" (fun () ->
    (*                     0123 4567 89 *)
    let tx = Text.create "one\ntwo\none" in
    Text.insert tx 4 "";
    let re = Regex.compile "o(n|$)" in
    span "forward from 0" (Some (0, 2)) (whole (Text.search_forward tx re 0));
    span "forward from 1: two's o, at its line's end" (Some (6, 6 + 1)) (whole (Text.search_forward tx re 1));
    span "forward, none" None (whole (Text.search_forward tx re 9));
    span "backward from the end" (Some (8, 10)) (whole (Text.search_backward tx re 11));
    span "backward from a match's start: the one before" (Some (6, 7)) (whole (Text.search_backward tx re 8));
    span "backward, none" None (whole (Text.search_backward tx re 0));
    span "a group" (Some (1, 2)) (Option.map (fun (a : (int * int) array) -> a.(1)) (Text.search_forward tx re 0));
    span "^ at a line's start" (Some (4, 5)) (whole (Text.search_forward tx (Regex.compile "^t") 0)));
  t "law: as a string changed the plain way, and all undone is the first text" (fun () ->
    seed := 1;
    let first = "The quick brown fox\njumps over\n\nthe lazy dog.\n" in
    let tx = Text.create first and model = ref first in
    let p = Text.new_point tx 10 and at = ref 10 in
    for i = 1 to 3000 do
      let len = String.length !model in
      if random 3 > 0 then begin
        let where = random (len + 1) and x = String.make (random 200) (Char.chr (97 + random 26)) in
        Text.insert tx where x;
        model := insert !model where x;
        if !at > where then at := !at + String.length x
      end
      else begin
        let where = random (len + 1) in
        let n = random (min 250 (len - where) + 1) in
        str "deleted" (String.sub !model where n) (Text.delete tx where n);
        model := delete !model where n;
        if !at > where then at := max where (!at - n)
      end;
      if random 4 = 0 then Text.boundary tx;
      if i mod 100 = 0 then begin
        str "the text" !model (Text.to_string tx);
        int "the point" !at (Text.get_position p);
        let where = random (String.length !model + 1) in
        int "bol" (match String.rindex_from_opt !model (where - 1) '\n' with Some j -> j + 1 | None -> 0) (Text.bol tx where);
        int "eol" (match String.index_from_opt !model where '\n' with Some j -> j | None -> String.length !model) (Text.eol tx where)
      end
    done;
    let commands = ref 0 in
    while Text.undo tx <> None do incr commands done;
    str "all undone" first (Text.to_string tx);
    Alcotest.(check bool) "by commands, not by changes" true (!commands > 500 && !commands < 1000));
]
